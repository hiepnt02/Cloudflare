//
//  GsxStream.swift
//  Quick3D
//

import Foundation
import Metal
import QuartzCore
import simd

/// Streams a .gsx over HTTP Range requests (as the web client does against S3), keeps the
/// selected LOD blocks in one GPU buffer and depth-sorts them on a background thread. Blocks
/// already downloaded are kept in a `GsxDiskCache`.
///
/// Threads: the renderer's render thread calls `updateCamera`, `setProjection`, `drawState` and
/// reads `bounds`; loading, decoding and sorting run on their own queues. All shared state is
/// behind `lock`.
final class GsxStream: @unchecked Sendable {
    struct Stats {
        var state = "loading header"
        var wanted = 0
        var resident = 0
        var inFlight = 0
        var splats = 0
        var drawn = 0
        var bytes = 0
        var sortMs: Double = 0
        var decodeMs: Double = 0
        var decoded = 0
        var errors = 0
        var lastError: String?
        var totalSplats = 0
        var nodes = 0
        var fromCache = 0
        var fromNetwork = 0
    }

    struct DrawState {
        let splats: MTLBuffer
        let order: MTLBuffer
        let count: Int
    }

    private struct Resident {
        var pages: [Int]
        var count: Int
    }

    private enum LoadError: Error { case http(Int), short(Int, Int), noSpace }

    /// Splat buffer allocation unit. Blocks hold up to 1024 splats but ~500 on average, so pages
    /// much smaller than a block keep the buffer from filling up half empty.
    static let pageSize = 256
    private static let orderBufferCount = 4
    private static let baseLevelMax = 2
    private static let maxResident = 100_000
    /// Blocks are loaded out to |ndc| ≤ this, so those just off screen are ready when the camera
    /// turns (2 ≈ another half view on each side).
    private static let loadMargin: Float = 2
    private static let minSortInterval: CFTimeInterval = 0.033
    /// Splats with |ndc| beyond this are left out of the sorted draw list.
    private static let sortCullMargin: Float = 1.3
    /// Range requests in flight; each can carry many neighbouring blocks.
    private static let maxRequests = 8
    /// Blocks considered per scheduling round.
    private static let batchNodes = 512
    /// Neighbouring blocks are merged into one request while the gap stays below this...
    private static let maxGapBytes = 64 * 1024
    /// ...and the request below this.
    private static let maxRequestBytes = 4 * 1024 * 1024
    private static let evictionDelay: CFTimeInterval = 2
    private static let residentBonus = 1.25
    private static let pageCooldown: CFTimeInterval = 0.6
    /// Cached blocks queued for decoding at most, so the queue keeps following the camera.
    private static let maxQueuedDecodes = 256

    let url: URL
    private let device: MTLDevice
    private let budget: Int
    private let session: URLSession
    private let cache: GsxDiskCache
    private let loaderQueue = DispatchQueue(label: "gsx.loader")
    private let decodeQueue: OperationQueue = {
        let q = OperationQueue()
        // Leave two cores to the render and sort threads.
        q.maxConcurrentOperationCount = max(2, ProcessInfo.processInfo.activeProcessorCount - 2)
        q.qualityOfService = .userInitiated
        return q
    }()
    private var timer: DispatchSourceTimer?
    private let sortSignal = DispatchSemaphore(value: 0)

    private let lock = NSLock()
    private var meta: GsxMeta?
    private var splatBuffer: MTLBuffer?
    private var positions: UnsafeMutablePointer<Float>?
    private var freePages: [Int] = []
    private var pageCount = 0
    private var coolingPages: [(pages: [Int], until: CFTimeInterval)] = []
    private var resident: [Int: Resident] = [:]
    private var inFlight: Set<Int> = []
    private var inFlightRequests = 0
    private var retryAt: [Int: CFTimeInterval] = [:]
    private var evictAt: [Int: CFTimeInterval] = [:]
    private var splatsByNode: [Int: Int] = [:]
    private var splatsPerByte: Double = 0
    private var residentVersion = 0
    private var viewModel: simd_float4x4?
    private var projection: simd_float4x4?
    private var orderBuffers: [MTLBuffer] = []
    private var published: (buffer: Int, count: Int)?
    private var robustBounds: (center: SIMD3<Float>, extent: SIMD3<Float>)?
    private var stopped = false
    private var tickQueued = false
    private var currentStats = Stats()

    init(url: URL, device: MTLDevice, budget: Int) {
        self.url = url
        self.device = device
        self.budget = budget
        cache = GsxDiskCache.shared(for: url)
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = Self.maxRequests
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    deinit {
        positions?.deallocate()
    }

    // MARK: - Public API

    func start() {
        // A file seen before starts from its cached tables at once, without waiting for the
        // network. The header is still fetched, to notice a file converted again since: its
        // cache is then dropped, so the next open downloads it anew.
        loaderQueue.async { [weak self] in
            guard let self else { return }
            if let stored = self.cache.storedMeta() {
                self.startCached(stored)
            } else {
                self.startFromNetwork()
            }
        }
    }

    private func startCached(_ stored: (header: Data, tables: Data, etag: String?)) {
        do {
            let header = try GsxHeader(stored.header)
            cache.open(header: stored.header, tables: stored.tables, etag: stored.etag, blockCount: header.blockCount)
            try prepare(GsxMeta(header: header, tables: stored.tables))
        } catch {
            fail("cached meta: \(error)")
        }
        fetchRange(offset: 0, length: GsxHeader.size) { [weak self] result in
            guard let self, case .success(let (headerData, etag)) = result else { return }
            if headerData != stored.header || etag != stored.etag { self.cache.discardMeta() }
        }
    }

    private func startFromNetwork() {
        fetchRange(offset: 0, length: GsxHeader.size) { [weak self] result in
            guard let self else { return }
            do {
                let (headerData, etag) = try result.get()
                let header = try GsxHeader(headerData)
                if let tables = self.cache.cachedMeta(header: headerData, etag: etag) {
                    self.cache.open(header: headerData, tables: tables, etag: etag, blockCount: header.blockCount)
                    try self.prepare(GsxMeta(header: header, tables: tables))
                    return
                }
                self.setState("loading tables (\(header.blockCount) blocks)")
                self.fetchRange(offset: GsxHeader.size, length: header.tablesSize) { result in
                    do {
                        let (tables, _) = try result.get()
                        let meta = try GsxMeta(header: header, tables: tables)
                        self.cache.open(header: headerData, tables: tables, etag: etag, blockCount: header.blockCount)
                        try self.prepare(meta)
                    } catch {
                        self.fail("meta: \(error)")
                    }
                }
            } catch {
                self.fail("header: \(error)")
            }
        }
    }

    func stop() {
        // Under the lock, so fetchRange cannot start a task on the invalidated session (which
        // raises an Objective-C exception).
        lock.withLock {
            stopped = true
            session.invalidateAndCancel()
        }
        timer?.cancel()
        sortSignal.signal()
        decodeQueue.cancelAllOperations()
        cache.flush(force: true)
    }

    /// Data-space → view-space matrix (view × model) of the frame being drawn.
    func updateCamera(viewModel: simd_float4x4) {
        lock.withLock { self.viewModel = viewModel }
        sortSignal.signal()
    }

    /// Render thread: the scene projection, for frustum culling.
    func setProjection(_ projection: simd_float4x4) {
        lock.withLock { self.projection = projection }
    }

    /// Render thread: the latest sorted draw list.
    func drawState() -> DrawState? {
        lock.withLock {
            guard let published, let splatBuffer, published.count > 0 else { return nil }
            return DrawState(splats: splatBuffer, order: orderBuffers[published.buffer], count: published.count)
        }
    }

    var stats: Stats { lock.withLock { currentStats } }

    /// Centre and size of the bulk of the data (2–98th percentile of the root block),
    /// falling back to the header AABB.
    var bounds: (center: SIMD3<Float>, extent: SIMD3<Float>)? {
        lock.withLock {
            if let robustBounds { return robustBounds }
            guard let h = meta?.header else { return nil }
            return ((h.aabbMin + h.aabbMax) / 2, h.aabbMax - h.aabbMin)
        }
    }

    // MARK: - Setup

    private func prepare(_ meta: GsxMeta) throws {
        // Stopped while the tables were loading: start no timer or sort thread.
        if lock.withLock({ stopped }) { return }
        let pages = Int((Double(budget) * 1.15 / Double(Self.pageSize)).rounded(.up))
        let capacity = pages * Self.pageSize
        guard let splats = device.makeBuffer(length: capacity * GsxDecoder.splatStride, options: .storageModeShared) else {
            throw LoadError.noSpace
        }
        var orders: [MTLBuffer] = []
        for _ in 0..<Self.orderBufferCount {
            guard let b = device.makeBuffer(length: capacity * 4, options: .storageModeShared) else { throw LoadError.noSpace }
            orders.append(b)
        }
        let uncompressed = meta.blocks.reduce(0) { $0 + $1.sizeUncompressed }
        lock.withLock {
            self.meta = meta
            splatBuffer = splats
            positions = .allocate(capacity: capacity * 3)
            freePages = Array((0..<pages).reversed())
            pageCount = pages
            orderBuffers = orders
            splatsPerByte = uncompressed > 0 ? Double(meta.header.splatCount) / Double(uncompressed) : 0
            currentStats.state = "streaming"
            currentStats.totalSplats = meta.header.splatCount
            currentStats.nodes = meta.nodes.count
        }

        let timer = DispatchSource.makeTimerSource(queue: loaderQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(200))
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.timer = timer

        let sorter = Thread { [weak self] in self?.sortLoop() }
        sorter.name = "gsx.sort"
        // Low enough to leave the performance cores to ARKit and the renderer: sorting a few
        // million splats takes tens of milliseconds and otherwise costs frames.
        sorter.qualityOfService = .utility
        sorter.start()
    }

    // MARK: - LOD selection (port of engine/loader/spatialLoader.ts)

    private func tick() {
        let now = CACurrentMediaTime()
        var toFetch: [FetchItem] = []
        var fromCache: [FetchItem] = []
        // The render thread waits on `lock` every frame, so the selection below works on a copy
        // and the lock is only held to read and to apply.
        lock.lock()
        tickQueued = false
        guard !stopped, let meta, let viewModel, let projection else {
            lock.unlock()
            return
        }
        coolingPages.removeAll { item in
            guard item.until <= now else { return false }
            freePages.append(contentsOf: item.pages)
            return true
        }
        let loaded = Set(resident.keys)
        let splatsByNode = self.splatsByNode
        let pageCount = self.pageCount, splatsPerByte = self.splatsPerByte
        lock.unlock()

        let viewProj = projection * viewModel
        let planes = Self.frustumPlanes(viewProj, margin: Self.loadMargin)
        // The whole file fits: load everything instead of culling to the view.
        let loadAll = meta.header.splatCount <= budget
        let eye4 = viewModel.inverse.columns.3
        let eye = SIMD3<Float>(eye4.x, eye4.y, eye4.z)
        var candidates: [(node: Int, priority: Double)] = []
        for (i, node) in meta.nodes.enumerated() where node.blockId != GsxNode.noBlock {
            let isBase = node.level <= Self.baseLevelMax
            if !isBase, !loadAll, !Self.aabbVisible(node.aabbMin, node.aabbMax, planes) { continue }
            let center = (node.aabbMin + node.aabbMax) * 0.5
            let distSq = Double(simd_length_squared(center - eye))
            // 1 at the centre of the screen, 0 at the corners and off screen.
            var centrality = 0.0
            let clip = viewProj * SIMD4<Float>(center, 1)
            if clip.w > 1e-6 {
                let r = min(1, simd_length(SIMD2<Float>(clip.x, clip.y) / clip.w) / Float(2).squareRoot())
                centrality = Double(1 - r)
            }
            // Unlike the web client (level by level across the whole view, which spreads a phone-
            // sized budget evenly and keeps everything coarse), blocks go by how big they look:
            // near and central ones get their fine levels first. A child lies inside its parent
            // and is smaller, so it still comes after it; a near child beats a far parent.
            let size = Double(simd_length(node.aabbMax - node.aabbMin))
            // Loaded blocks get a head start, so small camera moves do not swap the blocks at the
            // edge of the budget in and out (decoding and re-sorting all the time).
            let keep = loaded.contains(i) ? Self.residentBonus : 1
            let priority = (isBase ? 1e12 : 0) + size / max(distSq.squareRoot(), 0.05) * (1 + 0.5 * centrality) * keep
            candidates.append((i, priority))
        }
        candidates.sort { $0.priority > $1.priority }

        var want = Set<Int>()
        var wantSplats = 0, wantPages = 0
        // Keep some pages free for those still cooling down after an eviction.
        let pageRoom = pageCount * 9 / 10
        for c in candidates.prefix(Self.maxResident) {
            let node = meta.nodes[c.node]
            let estimate = splatsByNode[c.node]
                ?? Int((Double(meta.blocks[Int(node.blockId)].sizeUncompressed) * splatsPerByte * 1.2).rounded(.up))
            let pages = (estimate + Self.pageSize - 1) / Self.pageSize
            if !want.isEmpty, wantSplats + estimate > budget || wantPages + pages > pageRoom { break }
            want.insert(c.node)
            wantSplats += estimate
            wantPages += pages
        }
        let wanted = candidates.compactMap { want.contains($0.node) ? $0.node : nil }

        lock.lock()
        guard !stopped else {
            lock.unlock()
            return
        }
        // Hysteretic eviction.
        for nodeId in Array(resident.keys) {
            if want.contains(nodeId) {
                evictAt[nodeId] = nil
                continue
            }
            let deadline = evictAt[nodeId] ?? now + Self.evictionDelay
            evictAt[nodeId] = deadline
            if deadline <= now, let r = resident.removeValue(forKey: nodeId) {
                evictAt[nodeId] = nil
                coolingPages.append((r.pages, now + Self.pageCooldown))
                residentVersion += 1
            }
        }

        // Load wanted blocks in priority order, a batch per round: from the disk cache when it
        // has them, else from the network. Newer converter output has thousands of ~8 KB
        // blocks, so neighbouring blocks go out as one Range request.
        let cacheRoom = Self.maxQueuedDecodes - decodeQueue.operationCount
        let networkRoom = inFlightRequests < Self.maxRequests ? Self.batchNodes : 0
        for node in wanted {
            if fromCache.count >= cacheRoom, toFetch.count >= networkRoom { break }
            if resident[node] != nil || inFlight.contains(node) { continue }
            if let t = retryAt[node], t > now { continue }
            let block = Int(meta.nodes[node].blockId)
            let item = FetchItem(node: node, block: block, entry: meta.blocks[block])
            if cache.has(block) {
                if fromCache.count < cacheRoom { fromCache.append(item) }
            } else if toFetch.count < networkRoom {
                toFetch.append(item)
            }
        }
        let groups = Array(Self.coalesce(toFetch).prefix(Self.maxRequests - inFlightRequests))
        for group in groups {
            for item in group { inFlight.insert(item.node) }
        }
        for item in fromCache { inFlight.insert(item.node) }
        inFlightRequests += groups.count

        currentStats.wanted = want.count
        currentStats.resident = resident.count
        currentStats.inFlight = inFlight.count
        currentStats.splats = resident.values.reduce(0) { $0 + $1.count }
        let flags = meta.header.flags, blockSize = meta.header.blockSize
        let rootNode = meta.nodes.firstIndex { $0.level == 0 && $0.blockId != GsxNode.noBlock }
        lock.unlock()

        cache.flush()

        for item in fromCache {
            decodeQueue.addOperation { [weak self] in
                guard let self else { return }
                guard let data = self.cache.read(item.block, entry: item.entry) else {
                    return self.blockFailed(item.node, error: "cache read", retryIn: 2)
                }
                self.decode(node: item.node, data: data, entry: item.entry, flags: flags,
                            blockSize: blockSize, isRoot: item.node == rootNode, fromCache: true)
                // Disk is fast: refill the queue as it drains rather than once per timer tick.
                if self.decodeQueue.operationCount <= Self.maxQueuedDecodes / 2 { self.scheduleTick() }
            }
        }

        for group in groups {
            guard let first = group.first, let last = group.last else { continue }
            let start = first.entry.offset
            let end = last.entry.offset + last.entry.sizeCompressed
            fetchRange(offset: start, length: end - start) { [weak self] result in
                guard let self else { return }
                self.lock.withLock { self.inFlightRequests -= 1 }
                switch result {
                case .success(let (data, _)):
                    for item in group {
                        let from = item.entry.offset - start
                        let bytes = data.subdata(in: from..<(from + item.entry.sizeCompressed))
                        self.decodeQueue.addOperation {
                            self.cache.store(bytes, block: item.block, entry: item.entry)
                            self.decode(node: item.node, data: bytes, entry: item.entry, flags: flags,
                                        blockSize: blockSize, isRoot: item.node == rootNode, fromCache: false)
                        }
                    }
                case .failure(let error):
                    for item in group {
                        self.blockFailed(item.node, error: "fetch: \(error)", retryIn: 2)
                    }
                }
                // Keep the pipe full instead of waiting for the next timer tick.
                self.scheduleTick()
            }
        }
    }

    /// Runs `tick` again as soon as the loader queue is free, once however many callers ask.
    private func scheduleTick() {
        let schedule = lock.withLock { () -> Bool in
            guard !tickQueued, !stopped else { return false }
            tickQueued = true
            return true
        }
        if schedule { loaderQueue.async { self.tick() } }
    }

    /// Groups blocks by file position into Range requests: neighbours closer than
    /// `maxGapBytes` share a request, up to `maxRequestBytes` each.
    private struct FetchItem {
        let node: Int
        let block: Int
        let entry: GsxBlockEntry
    }

    private static func coalesce(_ items: [FetchItem]) -> [[FetchItem]] {
        var groups: [[FetchItem]] = []
        var current: [FetchItem] = []
        var groupStart = 0, groupEnd = 0
        for item in items.sorted(by: { $0.entry.offset < $1.entry.offset }) {
            let itemEnd = item.entry.offset + item.entry.sizeCompressed
            if !current.isEmpty, item.entry.offset - groupEnd <= maxGapBytes, itemEnd - groupStart <= maxRequestBytes {
                current.append(item)
                groupEnd = max(groupEnd, itemEnd)
            } else {
                if !current.isEmpty { groups.append(current) }
                current = [item]
                groupStart = item.entry.offset
                groupEnd = itemEnd
            }
        }
        if !current.isEmpty { groups.append(current) }
        return groups
    }

    private func decode(node: Int, data: Data, entry: GsxBlockEntry, flags: UInt16, blockSize: Int, isRoot: Bool,
                        fromCache: Bool) {
        let t0 = CACurrentMediaTime()
        var reserved: [Int] = []
        do {
            let count = try GsxDecoder.decode(compressed: data, entry: entry, flags: flags, maxSplats: blockSize) { count in
                let need = (count + Self.pageSize - 1) / Self.pageSize
                return try self.lock.withLock {
                    guard let splatBuffer = self.splatBuffer, let positions = self.positions,
                          self.freePages.count >= need else { throw LoadError.noSpace }
                    reserved = Array(self.freePages.suffix(need))
                    self.freePages.removeLast(need)
                    return GsxBlockTarget(splats: splatBuffer.contents(), positions: positions,
                                          pages: reserved, pageSize: Self.pageSize)
                }
            }
            let bounds = isRoot ? computeBounds(pages: reserved, count: count) : nil
            let ms = (CACurrentMediaTime() - t0) * 1000
            lock.withLock {
                inFlight.remove(node)
                retryAt[node] = nil
                if stopped { return }
                resident[node] = Resident(pages: reserved, count: count)
                splatsByNode[node] = count
                residentVersion += 1
                currentStats.decoded += 1
                if fromCache { currentStats.fromCache += 1 } else { currentStats.fromNetwork += 1 }
                currentStats.bytes += data.count
                currentStats.decodeMs += (ms - currentStats.decodeMs) / Double(min(currentStats.decoded, 20))
                if let bounds { robustBounds = bounds }
            }
            sortSignal.signal()
        } catch LoadError.noSpace {
            lock.withLock { freePages.append(contentsOf: reserved) }
            // Pages free up as soon as evicted blocks cool down.
            blockFailed(node, error: "no space in splat buffer", retryIn: 1)
        } catch {
            lock.withLock { freePages.append(contentsOf: reserved) }
            blockFailed(node, error: "decode: \(error)", retryIn: 30)
        }
    }

    private func computeBounds(pages: [Int], count: Int) -> (center: SIMD3<Float>, extent: SIMD3<Float>)? {
        guard count > 16, let positions = lock.withLock({ self.positions }) else { return nil }
        var lo = SIMD3<Float>(), hi = SIMD3<Float>()
        for axis in 0..<3 {
            var values = [Float]()
            values.reserveCapacity(count)
            for i in 0..<count {
                let g = pages[i / Self.pageSize] * Self.pageSize + i % Self.pageSize
                values.append(positions[g * 3 + axis])
            }
            values.sort()
            lo[axis] = values[count * 2 / 100]
            hi[axis] = values[count * 98 / 100]
        }
        return ((lo + hi) / 2, hi - lo)
    }

    private func blockFailed(_ node: Int, error: String, retryIn: CFTimeInterval) {
        lock.withLock {
            inFlight.remove(node)
            retryAt[node] = CACurrentMediaTime() + retryIn
            currentStats.errors += 1
            currentStats.lastError = error
        }
    }

    private func setState(_ state: String) {
        lock.withLock { currentStats.state = state }
    }

    private func fail(_ message: String) {
        lock.withLock {
            currentStats.state = "failed"
            currentStats.lastError = message
            currentStats.errors += 1
        }
    }

    /// The bytes and the file's ETag.
    private func fetchRange(offset: Int, length: Int, completion: @escaping (Result<(Data, String?), Error>) -> Void) {
        var request = URLRequest(url: url)
        request.setValue("bytes=\(offset)-\(offset + length - 1)", forHTTPHeaderField: "Range")
        let task: URLSessionDataTask? = lock.withLock {
            guard !stopped else { return nil }
            return session.dataTask(with: request) { data, response, error in
                completion(Self.rangeResult(data: data, response: response, error: error, offset: offset, length: length))
            }
        }
        task?.resume()
    }

    /// The requested bytes and the file's ETag, from a Range response.
    private static func rangeResult(data: Data?, response: URLResponse?, error: Error?, offset: Int, length: Int) -> Result<(Data, String?), Error> {
        if let error { return .failure(error) }
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        guard status == 206 || status == 200 else { return .failure(LoadError.http(status)) }
        guard var data, data.count >= length else { return .failure(LoadError.short(data?.count ?? 0, length)) }
        if status == 200 { data = data.subdata(in: offset..<(offset + length)) }   // server ignored Range
        return .success((data, http?.value(forHTTPHeaderField: "ETag")))
    }

    // MARK: - Depth sort (port of engine/sorter.ts)

    private func sortLoop() {
        var lastVersion = -1
        var lastView: simd_float4x4?
        var capacity = 0
        var indices: UnsafeMutablePointer<UInt32>?
        var keys: UnsafeMutablePointer<UInt32>?
        var depths: UnsafeMutablePointer<Float>?
        let counts = UnsafeMutablePointer<UInt32>.allocate(capacity: 1 << 20)
        defer {
            indices?.deallocate()
            keys?.deallocate()
            depths?.deallocate()
            counts.deallocate()
        }

        var lastSort: CFTimeInterval = 0
        var lastDuration: CFTimeInterval = 0
        while true {
            _ = sortSignal.wait(timeout: .now() + .milliseconds(100))
            // At most ~30 sorts per second, and busy at most half of the time.
            let interval = max(Self.minSortInterval, 2 * lastDuration)
            let sinceLast = CACurrentMediaTime() - lastSort
            if sinceLast < interval {
                Thread.sleep(forTimeInterval: interval - sinceLast)
            }
            lock.lock()
            if stopped {
                lock.unlock()
                return
            }
            guard let viewModel, let positions, !orderBuffers.isEmpty else {
                lock.unlock()
                continue
            }
            let moved = lastView.map { Self.viewChanged($0, viewModel) } ?? true
            if residentVersion == lastVersion, !moved {
                lock.unlock()
                continue
            }
            let version = residentVersion
            let blocks = Array(resident.values)
            let viewProj = projection.map { $0 * viewModel }
            let target = ((published?.buffer ?? -1) + 1) % Self.orderBufferCount
            let output = orderBuffers[target].contents().bindMemory(to: UInt32.self, capacity: orderBuffers[target].length / 4)
            lock.unlock()

            let t0 = CACurrentMediaTime()
            lastSort = t0
            let total = blocks.reduce(0) { $0 + $1.count }
            if total > capacity {
                indices?.deallocate(); keys?.deallocate(); depths?.deallocate()
                capacity = total
                indices = .allocate(capacity: total)
                keys = .allocate(capacity: total)
                depths = .allocate(capacity: total)
            }
            guard let idx = indices, let keyBuf = keys, let depthBuf = depths else { continue }

            // View-space z (GL convention: negative in front, more negative = farther).
            let row2 = SIMD4<Float>(viewModel.columns.0.z, viewModel.columns.1.z, viewModel.columns.2.z, viewModel.columns.3.z)
            // Clip rows for culling splats off screen (with a margin, since the list is only
            // refreshed at the sort rate) or behind the camera; they are neither sorted nor drawn.
            func row(_ r: Int) -> SIMD4<Float> {
                guard let m = viewProj else { return .zero }
                return SIMD4(m.columns.0[r], m.columns.1[r], m.columns.2[r], m.columns.3[r])
            }
            let cull = viewProj != nil
            let c0 = row(0), c1 = row(1), c3 = row(3)
            let margin = Self.sortCullMargin
            var minZ = Float.greatestFiniteMagnitude, maxZ = -Float.greatestFiniteMagnitude
            var k = 0
            for b in blocks {
                for j in 0..<b.count {
                    let g = b.pages[j / Self.pageSize] * Self.pageSize + j % Self.pageSize
                    let p = positions + g * 3
                    if cull {
                        let w = c3.x * p[0] + c3.y * p[1] + c3.z * p[2] + c3.w
                        if w <= 0 { continue }
                        let x = c0.x * p[0] + c0.y * p[1] + c0.z * p[2] + c0.w
                        let y = c1.x * p[0] + c1.y * p[1] + c1.z * p[2] + c1.w
                        if abs(x) > w * margin || abs(y) > w * margin { continue }
                    }
                    var z = row2.x * p[0] + row2.y * p[1] + row2.z * p[2] + row2.w
                    if !z.isFinite { z = 0 }
                    idx[k] = UInt32(g)
                    depthBuf[k] = z
                    minZ = min(minZ, z)
                    maxZ = max(maxZ, z)
                    k += 1
                }
            }
            let n = k

            // Density-adaptive keys: depth slices with more splats get more of the key space.
            let nbins = 256
            let bits = max(16, min(20, Int(log2(Double(max(n, 16)) / 4).rounded())))
            let buckets = 1 << bits
            let maxKey = buckets - 1
            let binRange = max(maxZ - minZ, 1e-6) / Float(nbins)
            var binCount = [Int](repeating: 0, count: nbins)
            for i in 0..<n {
                binCount[min(max(Int((depthBuf[i] - minZ) / binRange), 0), nbins - 1)] += 1
            }
            var binBase = [Float](repeating: 0, count: nbins)
            var binDiv = [Float](repeating: 0, count: nbins)
            for i in 0..<nbins { binDiv[i] = Float(Int(Double(binCount[i]) / Double(max(n, 1)) * Double(buckets))) }
            for i in 1..<nbins { binBase[i] = binBase[i - 1] + binDiv[i - 1] }

            counts.initialize(repeating: 0, count: buckets)
            for i in 0..<n {
                let d = (depthBuf[i] - minZ) / binRange
                let bin = min(max(Int(d), 0), nbins - 1)
                let key = UInt32(min(max(binBase[bin] + binDiv[bin] * (d - Float(bin)), 0), Float(maxKey)))
                keyBuf[i] = key
                counts[Int(key)] += 1
            }
            var sum: UInt32 = 0
            for i in 0..<buckets {
                let c = counts[i]
                counts[i] = sum
                sum += c
            }
            // Ascending key = farthest first → back-to-front.
            for i in 0..<n {
                let key = Int(keyBuf[i])
                output[Int(counts[key])] = idx[i]
                counts[key] += 1
            }

            lastDuration = CACurrentMediaTime() - t0
            let ms = lastDuration * 1000
            lock.withLock {
                published = (target, n)
                currentStats.sortMs = ms
                currentStats.drawn = n
            }
            lastVersion = version
            lastView = viewModel
        }
    }

    private static func viewChanged(_ a: simd_float4x4, _ b: simd_float4x4) -> Bool {
        func forward(_ m: simd_float4x4) -> SIMD3<Float> {
            simd_normalize(SIMD3(m.columns.0.z, m.columns.1.z, m.columns.2.z))
        }
        let dir = simd_reduce_add(simd_abs(forward(a) - forward(b)))
        let pos = simd_reduce_add(simd_abs(SIMD3(a.columns.3.x, a.columns.3.y, a.columns.3.z)
            - SIMD3(b.columns.3.x, b.columns.3.y, b.columns.3.z)))
        return dir > 0.005 || pos > 0.005
    }

    // MARK: - Frustum

    /// Left, right, bottom, top (widened to |ndc| ≤ `margin`) and "in front" planes
    /// (a reverse-Z infinite projection has no usable far plane, so none is used).
    private static func frustumPlanes(_ m: simd_float4x4, margin: Float) -> [SIMD4<Float>] {
        func row(_ r: Int) -> SIMD4<Float> { SIMD4(m.columns.0[r], m.columns.1[r], m.columns.2[r], m.columns.3[r]) }
        let r0 = row(0), r1 = row(1), r3 = row(3)
        let w = r3 * margin
        return [w + r0, w - r0, w + r1, w - r1, r3]
    }

    private static func aabbVisible(_ lo: SIMD3<Float>, _ hi: SIMD3<Float>, _ planes: [SIMD4<Float>]) -> Bool {
        for p in planes {
            let v = SIMD3<Float>(p.x >= 0 ? hi.x : lo.x, p.y >= 0 ? hi.y : lo.y, p.z >= 0 ? hi.z : lo.z)
            if p.x * v.x + p.y * v.y + p.z * v.z + p.w < 0 { return false }
        }
        return true
    }
}

/// Downloaded parts of a .gsx kept on disk, so blocks evicted from the GPU buffer (turning away
/// and back) or seen in an earlier session are decoded without a network request.
///
/// One directory per file: `meta` (header + tables, plus the ETag that identifies the version)
/// and `blocks`, a sparse file holding each compressed block at its offset in the .gsx, with
/// `have` marking the blocks written. One instance per file (`shared(for:)`), used from any
/// thread.
final class GsxDiskCache: @unchecked Sendable {
    /// Most recently used files kept; older ones are deleted when a new file is opened.
    private static let keepFiles = 4
    private static let flushInterval: CFTimeInterval = 2

    private let dir: URL
    private let lock = NSLock()
    private var fd: Int32 = -1
    private var openedHeader: Data?
    private var have: [UInt8] = []
    private var dirty = false
    private var lastFlush: CFTimeInterval = 0

    private static var root: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("gsx", isDirectory: true)
    }

    private static let registryLock = NSLock()
    private static let registry = NSMapTable<NSString, GsxDiskCache>.strongToWeakObjects()

    /// The cache for `url` (query ignored: the signature changes, the file does not), shared by
    /// every stream of that file (a reload can overlap the stream it replaces).
    static func shared(for url: URL) -> GsxDiskCache {
        let key = (url.host ?? "") + url.path
        let name = String(key.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }.joined().suffix(120))
        return registryLock.withLock {
            if let cache = registry.object(forKey: name as NSString) { return cache }
            let cache = GsxDiskCache(dir: root.appendingPathComponent(name, isDirectory: true))
            registry.setObject(cache, forKey: name as NSString)
            return cache
        }
    }

    private init(dir: URL) {
        self.dir = dir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Mark as recently used, then drop the least recently used others.
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: dir.path)
        Self.trim(keeping: dir)
    }

    deinit {
        flush(force: true)
        if fd >= 0 { Darwin.close(fd) }
    }

    /// Header + tables cached for this version of the file, if any.
    func cachedMeta(header: Data, etag: String?) -> Data? {
        guard let stored = storedMeta(), stored.header == header, stored.etag == etag else { return nil }
        return stored.tables
    }

    /// Forgets the cached version, so the next `open` starts the file over.
    func discardMeta() {
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("meta"))
    }

    /// Whatever header + tables were cached last, for opening the file without waiting for them.
    func storedMeta() -> (header: Data, tables: Data, etag: String?)? {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent("meta")),
              let stored = try? JSONDecoder().decode(StoredMeta.self, from: data) else { return nil }
        return (stored.header, stored.tables, stored.etag)
    }

    /// Starts caching blocks for this version of the file. A different version wipes the cache;
    /// opening the version already open does nothing.
    func open(header: Data, tables: Data, etag: String?, blockCount: Int) {
        lock.lock()
        defer { lock.unlock() }
        if openedHeader == header, fd >= 0 { return }
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
        let metaURL = dir.appendingPathComponent("meta")
        let blocksPath = dir.appendingPathComponent("blocks").path
        let havePath = dir.appendingPathComponent("have").path
        if cachedMeta(header: header, etag: etag) == nil {
            try? FileManager.default.removeItem(atPath: blocksPath)
            try? FileManager.default.removeItem(atPath: havePath)
            if let data = try? JSONEncoder().encode(StoredMeta(header: header, tables: tables, etag: etag)) {
                try? data.write(to: metaURL, options: .atomic)
            }
        }
        var bits = (try? [UInt8](Data(contentsOf: URL(fileURLWithPath: havePath)))) ?? []
        if bits.count != blockCount { bits = [UInt8](repeating: 0, count: blockCount) }
        have = bits
        fd = Darwin.open(blocksPath, O_RDWR | O_CREAT, 0o644)
        openedHeader = header
        dirty = false
    }

    func has(_ block: Int) -> Bool {
        lock.withLock { has(locked: block) }
    }

    // IO happens under the lock (blocks are a few KB) so a reopen cannot pull the descriptor
    // away mid-call and have its number reused for another file.

    func read(_ block: Int, entry: GsxBlockEntry) -> Data? {
        lock.withLock {
            guard fd >= 0, has(locked: block) else { return nil }
            var data = Data(count: entry.sizeCompressed)
            let n = data.withUnsafeMutableBytes { pread(fd, $0.baseAddress, entry.sizeCompressed, off_t(entry.offset)) }
            return n == entry.sizeCompressed ? data : nil
        }
    }

    func store(_ data: Data, block: Int, entry: GsxBlockEntry) {
        lock.withLock {
            guard fd >= 0, block < have.count, data.count == entry.sizeCompressed else { return }
            let n = data.withUnsafeBytes { pwrite(fd, $0.baseAddress, data.count, off_t(entry.offset)) }
            // Marked only once the bytes are written: a crash can lose blocks, never serve bad ones.
            guard n == data.count else { return }
            have[block] = 1
            dirty = true
        }
    }

    /// Saves which blocks are cached; at most every `flushInterval` unless `force`.
    func flush(force: Bool = false) {
        let now = CACurrentMediaTime()
        let bits: [UInt8]? = lock.withLock {
            guard dirty, force || now - lastFlush >= Self.flushInterval else { return nil }
            dirty = false
            lastFlush = now
            return have
        }
        guard let bits else { return }
        try? Data(bits).write(to: dir.appendingPathComponent("have"), options: .atomic)
    }

    private func has(locked block: Int) -> Bool { block < have.count && have[block] != 0 }

    private struct StoredMeta: Codable {
        let header: Data
        let tables: Data
        let etag: String?
    }

    private static func trim(keeping current: URL) {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        func date(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
        let stale = dirs.filter { $0.standardizedFileURL != current.standardizedFileURL }
            .sorted { date($0) > date($1) }
            .dropFirst(keepFiles - 1)
        for url in stale { try? fm.removeItem(at: url) }
    }
}
