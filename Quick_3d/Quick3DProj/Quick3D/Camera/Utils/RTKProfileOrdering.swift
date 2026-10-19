//
//  RTKProfileOrdering.swift
//  Quick3D
//
//  Created by MOR on 6/10/26.
//

import Foundation

enum RTKProfileOrdering {
    /// Profile đang chọn (lần dùng gần nhất, kể cả chỉ chọn mà chưa kết nối) đứng đầu.
    /// Còn lại: đã kết nối thì lên trước, mới nhất trước; chưa kết nối xếp sau theo thứ tự tạo.
    /// `sorted` của Swift không đảm bảo stable nên so sánh thêm vị trí ban đầu.
    static func ordered(_ profiles: [RTKConnectionProfile], selectedId: String? = nil) -> [RTKConnectionProfile] {
        var result = byLastConnected(profiles)
        if let index = result.firstIndex(where: { $0.id == selectedId }) {
            result.insert(result.remove(at: index), at: 0)
        }
        return result
    }

    private static func byLastConnected(_ profiles: [RTKConnectionProfile]) -> [RTKConnectionProfile] {
        profiles.enumerated().sorted { lhs, rhs in
            let (a, b) = (lhs.element, rhs.element)
            switch (a.lastConnectedAt, b.lastConnectedAt) {
            case let (x?, y?) where x != y:
                return x > y
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                return a.createdAt != b.createdAt ? a.createdAt < b.createdAt : lhs.offset < rhs.offset
            }
        }.map(\.element)
    }

    /// Giữ nguyên thứ tự đã chụp để card không nhảy chỗ khi đang ở màn: bỏ id đã xoá,
    /// profile vừa tạo chưa từng kết nối nên xếp cuối, đúng như `ordered` sẽ xếp.
    static func reconcile(snapshot: [String], profiles: [RTKConnectionProfile]) -> [String] {
        let existing = Set(profiles.map(\.id))
        let known = Set(snapshot)
        let added = ordered(profiles.filter { !known.contains($0.id) }).map(\.id)
        return snapshot.filter { existing.contains($0) } + added
    }
}
