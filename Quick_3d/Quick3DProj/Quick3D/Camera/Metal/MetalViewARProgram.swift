//
//  MetalViewARProgram.swift
//  Quick3D
//
//  Created by HaNST on 10/3/26.
//

import Foundation
import SceneKit

class MetalViewARProgram: SCNProgram {

    var pointSize: Float = 20.0
    var pointCloudNodeOpacity: Float = 1.0

    /// Độ cao (world-space) của mặt sàn mà ViewARContext đang bám, và cờ báo
    /// đã phát hiện được mặt sàn hay chưa — false cho tới khi có, nên point
    /// cloud vẫn hiển thị bình thường trước khi ARKit tìm ra sàn.
    var groundPlaneY: Float = 0
    var hasGroundPlane: Bool = false

    /// Alpha còn lại của điểm nằm dưới mặt sàn, so với phần nằm trên, và bề
    /// dày dải chuyển tiếp (mét) quanh mặt sàn (smoothstep thay vì cắt cứng ở
    /// đúng groundPlaneY, để viền không giật khi ARKit tinh chỉnh lại ước lượng
    /// plane giữa các lần cập nhật).
    ///
    /// Đọc thẳng từ `BelowGroundFade` — cùng hai con số mà model design dùng —
    /// nên point cloud và model nhạt bằng nhau ở cùng độ sâu và ranh giới trùng
    /// nhau. Muốn đổi mức fade thì đổi ở `BelowGroundFade`, đừng đặt riêng ở
    /// đây, không thì hai bên lệch nhau.
    var belowGroundAlphaScale: Float = BelowGroundFade.alphaScale
    var belowGroundTransitionBand: Float = BelowGroundFade.transitionBand

    override init() {
        super.init()
        self.vertexFunctionName = "arPointVertex"
        self.fragmentFunctionName = "arPointFragment"

        // Bắt buộc, không phải tinh chỉnh: SCNProgram.isOpaque mặc định true,
        // và với program "đục" thì SceneKit bỏ qua alpha mà fragment trả về.
        // Thiếu dòng này, phần dưới mặt sàn chỉ tối đi (RGB premultiplied bị
        // nhân xuống) chứ không mờ đi, và slider POINT_CLOUD cũng vậy. Cùng
        // vai trò với `#pragma transparent` của BelowGroundFade. Đổi lại, point
        // cloud luôn đi nhánh vẽ trong suốt, kể cả khi không có gì bị fade.
        self.isOpaque = false

        self.handleBinding(ofBufferNamed: "baseSize", frequency: .perFrame) { b, _, _, _ in
            var s = Float(self.pointSize)
            b.writeBytes(&s, count: 4)
        }
        self.handleBinding(ofBufferNamed: "opacity", frequency: .perFrame) { buffer, _, _, _ in
            var o = self.pointCloudNodeOpacity
            buffer.writeBytes(&o, count: MemoryLayout<Float>.size)
        }
        self.handleBinding(ofBufferNamed: "groundPlaneY", frequency: .perFrame) { buffer, _, _, _ in
            var y = self.groundPlaneY
            buffer.writeBytes(&y, count: MemoryLayout<Float>.size)
        }
        self.handleBinding(ofBufferNamed: "hasGroundPlane", frequency: .perFrame) { buffer, _, _, _ in
            var v: Float = self.hasGroundPlane ? 1 : 0
            buffer.writeBytes(&v, count: MemoryLayout<Float>.size)
        }
        self.handleBinding(ofBufferNamed: BelowGroundFade.Key.alphaScale, frequency: .perFrame) { buffer, _, _, _ in
            var a = self.belowGroundAlphaScale
            buffer.writeBytes(&a, count: MemoryLayout<Float>.size)
        }
        self.handleBinding(ofBufferNamed: BelowGroundFade.Key.transitionBand, frequency: .perFrame) { buffer, _, _, _ in
            var t = self.belowGroundTransitionBand
            buffer.writeBytes(&t, count: MemoryLayout<Float>.size)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
