//
//  MetalViewARProgram.swift
//  Quick3D
//
//  Created by HaNST on 10/3/26.
//

import Foundation
import Metal
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

    /// DXF overlay (SC_QUICK-1986), the same blend as the web viewer's point shader: a
    /// point within `dxfRadius` meters (top-down) of a DXF edge takes on the edge's color.
    /// Drawn once `setDxfOverlay` was called and while the user switch is on.
    var isDxfOverlayOn: Bool = true
    var dxfRadius: Float = 2
    var dxfHardness: Float = 0
    var dxfOpacity: Float = 1
    private var dxfOverlay: DxfOverlayTexture?
    /// Point position → texture UV: u = x * [0] + [1], v = z * [2] + [3].
    private var dxfUVTransform: SIMD4<Float> = .zero

    /// Layout of `DxfOverlayUniforms` in Shaders.metal.
    private struct DxfOverlayUniforms {
        var enabled: Float
        var radius: Float
        var hardness: Float
        var opacity: Float
        var maxDistance: Float
        var uScale: Float
        var uOffset: Float
        var vScale: Float
        var vOffset: Float
    }

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
        self.handleBinding(ofBufferNamed: "dxfOverlay", frequency: .perFrame) { buffer, _, _, _ in
            let uv = self.dxfUVTransform
            var uniforms = DxfOverlayUniforms(
                enabled: self.isDxfOverlayOn && self.dxfOverlay != nil ? 1 : 0,
                radius: self.dxfRadius,
                hardness: self.dxfHardness,
                opacity: self.dxfOpacity,
                maxDistance: DxfOverlayBuilder.maxDistance,
                uScale: uv.x,
                uOffset: uv.y,
                vScale: uv.z,
                vOffset: uv.w
            )
            buffer.writeBytes(&uniforms, count: MemoryLayout<DxfOverlayUniforms>.size)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// `pointsGeoOrigin` is K with (easting, height, -northing) = point position + K for
    /// the point nodes this program draws. The UV offsets are worked out in Double, since
    /// K is in the hundreds of kilometers.
    func setDxfOverlay(_ overlay: DxfOverlayTexture, pointsGeoOrigin origin: SIMD3<Double>) {
        dxfUVTransform = SIMD4<Float>(
            Float(1 / overlay.spanE),
            Float((origin.x - overlay.minE) / overlay.spanE),
            Float(1 / overlay.spanMN),
            Float((origin.z - overlay.minMN) / overlay.spanMN)
        )
        dxfOverlay = overlay
    }

    /// Each point chunk has its own geometry, rebuilt when the opacity changes, so the
    /// texture is set on every one. The program hangs on the geometry, whose values
    /// SceneKit binds by argument name; the material gets it too. Before any DXF a 1×1
    /// "no edge" texture keeps the shader's texture argument bound.
    func attachDxfTexture(to geometry: SCNGeometry) {
        guard let texture = dxfOverlay?.texture ?? Self.emptyDxfTexture else { return }
        let property = SCNMaterialProperty(contents: texture)
        geometry.setValue(property, forKey: "dxfTexture")
        geometry.firstMaterial?.setValue(property, forKey: "dxfTexture")
    }

    private static let emptyDxfTexture: MTLTexture? = {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        var noEdge: [UInt8] = [0, 0, 0, 255]
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &noEdge, bytesPerRow: 4)
        return texture
    }()
}
