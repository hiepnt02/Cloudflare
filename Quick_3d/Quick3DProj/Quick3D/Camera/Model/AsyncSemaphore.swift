//
//  AsyncSemaphore.swift
//  Test4
//
//  Created by HaNST on 13/1/26.
//

import Foundation

actor AsyncSemaphore {
    private let max: Int
    private var current = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.max = value
    }

    func wait() async {
        if current < max {
            current += 1
            return
        }

        await withCheckedContinuation { cont in
            waiters.append(cont)
        }
    }

    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            current -= 1
        }
    }
}
