//
//  RTKStateObject.swift
//  Quick3D
//
//  Created by HaNST on 20/11/24.
//

import Foundation
import Combine
import VigramSDK
import CoreBluetooth
import CoreLocation

final class RTKStateObject: ObservableObject {
    
    static let maxRecentMountpointsCount = 5
        
    @Published var isReady: Bool = false
    @Published var vidocConnected: Peripheral? = nil
    @Published var devices: [CBPeripheral] = []
    
    @Published var state: RTKState = .disconnected
    
    @Published var cameraOffsetSegment: CameraOffsetEnum = CameraOffsetEnum.SPCPlus
    // @Published var rtkDeviceType: RTKRoverEnum = RTKRoverEnum.viDoc
    let rtkDeviceType: RTKRoverEnum = .viDoc
    
    @Published var ntripServiceProvider: NtripServiceProviderEnum = .other
    @Published var hostnameNtrip: String = ""
    @Published var portNtrip: String = ""
    @Published var usernameNtrip: String = ""
    @Published var passwordNtrip: String = ""
    @Published var isNtripProviderStatus = false
    
    @Published var currentNtripCoordinateSystem: CoordinateSystemNtripModel?
    @Published var isNtripCoordinateSystemStatus = false
    
    @Published var currentMountpoint: String = ""
    @Published var isNtripMountpointStatus = false
    
    @Published var mountpoints: [MountPointModel] = []
    
    /// Recent mountpoint selections, most recent first.
    @Published var recentMountpoints: [MountPointModel] = []
    
    @Published var isMountpointsFetched = false
    @Published var isMountpointsFetching = false
    
    @Published var ntripError: String? = nil
    
    @Published var customOffsetVidoc: SIMD3<Double> = .zero
    
    private var fetchTask: Task<Void, Never>?
    
    var allowNtripValid: Bool {
        !hostnameNtrip.isEmpty && !portNtrip.isEmpty && !usernameNtrip.isEmpty && !passwordNtrip.isEmpty
    }
    
    private var subscription = Set<AnyCancellable>()
    
    public var isNtripValidated: Bool {
        isNtripProviderStatus && isNtripCoordinateSystemStatus && isNtripMountpointStatus
    }
    
    init() {
        configure()
    }
    
    func configure() {
        
        RTKManager.shared.devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.devices = devices
            }.store(in: &subscription)
        
        RTKManager.shared.state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.state = state
                if state == .connected {
                    self?.vidocConnected = RTKManager.shared.connectedDevice
                } else {
                    self?.vidocConnected = nil
                }
            }.store(in: &subscription)
        
        RTKManager.shared.ready
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReady in
                self?.isReady = isReady
            }.store(in: &subscription)
        
        loadNtripINfo()
        
        self.cameraOffsetSegment = UserSession.shared.cameraOffsetSegment
        // self.rtkDeviceType = UserSession.shared.rtkTypeSelected
    }
    
    func loadNtripINfo() {
        ntripServiceProvider = UserSession.shared.ntripServiceProvider

        if let ntripInfo = UserSession.shared.ntripInfo {
            hostnameNtrip = ntripInfo.hostnameOrIp
            portNtrip = "\(ntripInfo.port)"
            usernameNtrip = ntripInfo.username
            passwordNtrip = ntripInfo.password
            isNtripProviderStatus = true
        }

        if let hostname = ntripServiceProvider.hostname, let port = ntripServiceProvider.port {
            hostnameNtrip = hostname
            portNtrip = port
        }
        
        if let mountpoint = UserSession.shared.mountPointNtrip {
            self.isNtripMountpointStatus = !mountpoint.isEmpty
            self.currentMountpoint = mountpoint
        }
        
        if let coordinateSystemNtrip = UserSession.shared.coordinateSystemNtrip {
            isNtripCoordinateSystemStatus = true
            currentNtripCoordinateSystem = coordinateSystemNtrip
        }
    }
    
    func applyNtripServiceProvider(_ provider: NtripServiceProviderEnum) {
        let isProviderChanged = provider != ntripServiceProvider
        
        ntripServiceProvider = provider

        if let hostname = provider.hostname, let port = provider.port {
            hostnameNtrip = hostname
            portNtrip = port
        } else if isProviderChanged {
            hostnameNtrip = ""
            portNtrip = ""
        }
        
        guard isProviderChanged else { return }
        
        cancelFetchingMountpoints()
        
        usernameNtrip = ""
        passwordNtrip = ""
        currentMountpoint = ""
        mountpoints = []
        recentMountpoints = []
        isMountpointsFetched = false
        isNtripProviderStatus = false
        isNtripMountpointStatus = false
        ntripError = nil
    }

    func cancelFetchingMountpoints() {
        fetchTask?.cancel()
        fetchTask = nil
        isMountpointsFetching = false
    }
    
    func fetchMountpoints(onCompletion: (([MountPointModel]) -> Void)? = nil, onError: ((Error) -> Void)? = nil) {
        
        cancelFetchingMountpoints()
        
        fetchTask = Task { @MainActor in
            if self.allowNtripValid && !self.isMountpointsFetching {
                self.isMountpointsFetching = true
                self.isMountpointsFetched = false
                self.ntripError = nil
                var result: [MountPointModel] = []
                
                do {
                    result = try await self.fetchMountpoints(hostname: hostnameNtrip, port: portNtrip, username: usernameNtrip, password: passwordNtrip)
                } catch {
                    self.ntripError = error.localizedDescription
                    onError?(error)
                }
                
                self.isMountpointsFetched = true
                self.isMountpointsFetching = false
                
                self.mountpoints = result
                
                if self.ntripError == nil {
                    self.syncRecentMountpoints(with: result)
                    onCompletion?(result)
                }
            }
        }
    }
    
    /// Drops history entries that are missing from the list returned by the last
    /// mountpoint verification, then rebuilds `recentMountpoints`.
    func syncRecentMountpoints(with fetched: [MountPointModel]) {
        let available = Set(fetched.map { $0.name })
        applyRecentMountpoints(
            UserSession.shared.recentMountPointNtrips.filter { available.contains($0) },
            from: fetched
        )
    }
    
    /// Moves the picked mountpoint to the top of the history, keeping at most
    /// `maxRecentMountpointsCount` entries.
    func saveRecentMountpoint(_ name: String) {
        var names = UserSession.shared.recentMountPointNtrips.filter { $0 != name }
        names.insert(name, at: 0)
        applyRecentMountpoints(Array(names.prefix(Self.maxRecentMountpointsCount)), from: mountpoints)
    }
    
    private func applyRecentMountpoints(_ names: [String], from source: [MountPointModel]) {
        UserSession.shared.recentMountPointNtrips = names
        recentMountpoints = names.compactMap { name in
            source.first { $0.name == name }
                .map { MountPointModel(name: $0.name, distance: $0.distance) }
        }
    }
    
    func fetchMountpoints(hostname: String, port: String, username: String, password: String) async throws -> [MountPointModel] {
        guard let publisher  = RTKManager.shared.getMountpoints(hostname: hostname, port: Int(port) ?? 0, username: username, password: password) else {
            return []
        }
        
        var cancellable: AnyCancellable?
        
        defer {
            cancellable?.cancel()
        }
        
        let result: [MountPointModel] = try await withCheckedThrowingContinuation { continuation in
            cancellable = publisher
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { complition in
                    switch complition {
                    case .finished:
                        break
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }, receiveValue: { mountpoints in
                    let list = mountpoints.map {
                        let coord0 = CLLocation(latitude: $0.latitude ?? 0, longitude: $0.longitude ?? 0)
                        let coord1 = CLLocation(latitude: GPSManager.shared.location.value.latitude, longitude: GPSManager.shared.location.value.longitude)
                        let d = coord0.distance(from: coord1)
                        return MountPointModel(name: $0.name, distance: "\(Int(d/1000))km")
                    }.sorted {
                        $0.name < $1.name
                    }
                    continuation.resume(returning: list)
                })
        }
        
        return result
    }
    
    
}
