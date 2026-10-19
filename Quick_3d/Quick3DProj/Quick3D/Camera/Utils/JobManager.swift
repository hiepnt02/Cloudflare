//
//  JobManager.swift
//  Quick3D
//
//  Created by HaNST on 19/3/26.
//

import Foundation
import Combine

class Job {
    var onFinish: (() -> Void)?
    var onCompleted: (() -> Void)?
    var onError: ((Error) -> Void)?
    
    // Bỏ kế thừa NSObject để nhẹ hơn (trừ khi bạn cần dùng API của Objective-C)
    func execute() {
        defer { finish() }
        do {
            try process()
            onCompleted?()
        } catch {
            onError?(error)
        }
    }
    
    func process() throws {}
    
    func finish() {
        clear()
        onFinish?()
    }
    
    func clear() {}
}

final class JobManager {
    
    // Đảm bảo thao tác với mảng và biến đếm là an toàn
    private let queue = DispatchQueue(label: "ltd.landlog.scquick3d.JobManager")
    
    // Group dùng để block chờ an toàn
    private let group = DispatchGroup()
    
    let maxConcurrentCount: Int
    let maxCount: Int
    
    private var works: [Job] = []
    private var executingCount: Int = 0
    private var isCancelled: Bool = false
    
    var count: Int {
        // Sử dụng cơ chế kiểm tra an toàn hơn
        return queue.sync { [weak self] in
            guard let self = self else { return 0 }
            return self.works.count + self.executingCount
        }
    }
    
    var isLimited: Bool {
        return count >= maxCount
    }
    
    init(maxCount: Int = 100, maxConcurrentCount: Int = 1) {
        self.maxCount = maxCount
        self.maxConcurrentCount = maxConcurrentCount
    }
    
    func addTask(_ work: Job) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // 1. Kiểm tra trạng thái trực tiếp, KHÔNG gọi self.count để tránh deadlock
            let currentTotalCount = self.works.count + self.executingCount
            
            // 2. Chỉ thực hiện khi chưa bị cancel và chưa đạt giới hạn
            guard !self.isCancelled, currentTotalCount < self.maxCount else {
                return
            }
            
            self.works.append(work)
            self.group.enter()
            self.scheduleNext()
        }
    }
    
    private func scheduleNext() {
        // Hàm này luôn được gọi bên trong `queue.async` nên không sợ xung đột biến
        while !works.isEmpty && executingCount < maxConcurrentCount {
            let work = works.removeFirst()
            executingCount += 1
            
            // Xử lý logic Finish trước khi đem đi execute
            work.onFinish = { [weak self] in
                guard let self = self else { return }
                self.queue.async {
                    self.executingCount -= 1
                    self.group.leave() // Báo cáo job đã HOÀN TOÀN kết thúc
                    self.scheduleNext() // Tiếp tục chạy job tiếp theo (nếu có)
                }
            }
            
            // Đẩy job ra luồng Global để không block queue quản lý
            DispatchQueue.global().async {
                work.execute()
            }
        }
    }
    
    func cancel() {
        queue.sync {
            isCancelled = true
            
            // Lấy ra số lượng job chưa kịp chạy
            let unexecutedCount = works.count
            works.removeAll()
            
            // Dọn dẹp DispatchGroup cho những job bị hủy mà chưa chạy
            for _ in 0..<unexecutedCount {
                group.leave()
            }
            
            // Reset state
            isCancelled = false
        }
        
        // Vẫn phải đợi các job đang chạy dở hoàn thành nốt
        waitUntilCompleted()
    }
    
    func waitUntilCompleted() {
        // Dùng DispatchGroup wait thay vì Thread.sleep.
        // Lệnh này sẽ an toàn block thread gọi nó mà không ngốn CPU.
        //group.wait()
        repeat {
            Thread.sleep(forTimeInterval: 0.1)
        } while works.count > 0 || executingCount > 0
    }
}
