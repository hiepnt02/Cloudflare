//
//  GridLayout.swift
//  Quick3D
//

import CoreGraphics

enum ProjectGridLayout {

    /// Số cột tối đa — giữ đúng giá trị cũ để bố cục ngang KHÔNG đổi.
    static func maxColumns(isIPhone: Bool) -> Int { isIPhone ? 4 : 5 }

    /// Bề rộng tối thiểu để một ô còn đọc được.
    static func minCellWidth(isIPhone: Bool) -> CGFloat { isIPhone ? 150 : 170 }

    /// Số cột vừa với bề rộng khả dụng.
    ///
    /// - Bề rộng chưa đo được (`0`) → trả về số cột tối đa, giữ nguyên bố cục cũ để không nháy.
    /// - Không bao giờ trả `0`: việc chia hàng dùng `stride(from:to:by:)` và `by: 0` sẽ **crash**.
    static func columnCount(availableWidth: CGFloat, isIPhone: Bool) -> Int {
        let maxCols = maxColumns(isIPhone: isIPhone)
        guard availableWidth > 0 else { return maxCols }
        let fitting = Int(availableWidth / minCellWidth(isIPhone: isIPhone))
        return min(max(1, fitting), maxCols)
    }
}
