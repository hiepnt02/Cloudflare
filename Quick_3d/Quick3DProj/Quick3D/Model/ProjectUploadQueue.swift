//
//  ProjectUploadQueue.swift
//  Quick3D
//
//  Created by HungNT on 4/3/25.
//

import Foundation

struct ProjectUploadQueue {
    private var elements: [ProjectUploadModel] = []

    mutating func enqueue(_ value: ProjectUploadModel) {
        elements.removeAll { project in
            project.cat != nil && project.cat?.id == value.cat?.id
        }
        elements.append(value)
    }

    mutating func dequeue() -> ProjectUploadModel? {
        guard !elements.isEmpty else {
          return nil
        }
        return elements.removeFirst()
    }

    mutating func dequeueAll() {
        elements = []
    }

    var head: ProjectUploadModel? {
        return elements.first
    }

    var tail: ProjectUploadModel? {
        return elements.last
    }


    mutating func dequeue(catId: String) {
        guard !elements.isEmpty else {
          return
        }

        elements.removeAll { project in
            project.cat != nil && project.cat?.id == catId
        }
    }

    func isInQueue(catId: String?) -> Bool {
        guard let catId = catId else {
            return false
        }
        if elements.isEmpty {
          return false
        }
        if elements.first(where: { $0.cat?.id == catId }) != nil {
            return true
        }
        return false
    }
}
