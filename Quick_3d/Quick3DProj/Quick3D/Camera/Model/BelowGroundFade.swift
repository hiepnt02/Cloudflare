//
//  BelowGroundFade.swift
//  Quick3D
//

import SceneKit

/// Làm nhạt phần model design (USDZ/IFC) nằm dưới mặt sàn ARKit.
///
/// Point cloud đã tự làm việc này trong `SCNProgram` của riêng nó (xem
/// `MetalViewARProgram`/`Shaders.metal`), nhưng model design thì dùng đúng
/// material gốc của file USDZ nên không có shader nào để cài vào. Slider
/// **Design** cũng chỉ ghi được `ifcNode.opacity` — một scalar cho cả node,
/// không phân biệt được phần trên và phần dưới mặt sàn.
///
/// Nên ở đây dùng `shaderModifiers` thay vì `SCNProgram`: nó *bổ sung* vào
/// chuỗi tô sẵn có của SceneKit nên giữ nguyên PBR/ánh sáng/texture của USDZ,
/// khác `SCNProgram` vốn *thay thế* toàn bộ shading (dùng được cho point cloud
/// vì point cloud không có material gốc nào để giữ).
///
/// Độ mờ cuối cùng là **tích** của hai thứ, không phải hai giá trị phải giữ
/// đồng bộ với nhau: SceneKit nhân `ifcNode.opacity` (slider Design) vào kết
/// quả tô, modifier nhân thêm `alphaScale` cho fragment nằm dưới sàn. Kéo
/// slider xuống 50% thì phần trên còn 50%, phần dưới còn 15%.
enum BelowGroundFade {

    /// Độ mờ còn lại của phần nằm dưới mặt sàn, so với phần nằm trên.
    /// 0.3 = phần dưới đậm bằng 30% phần trên.
    ///
    /// Hai hằng số dưới đây là **nguồn sự thật cho cả hai loại nội dung**:
    /// `MetalViewARProgram` đọc thẳng chúng cho point cloud, nên đổi ở đây là
    /// đổi cho cả model design và point cloud, không phải sửa hai chỗ.
    static let alphaScale: Float = 0.3

    /// Bề dày (mét) dải chuyển tiếp quanh mặt sàn, để ranh giới của model và
    /// của point cloud trùng nhau. Cắt cứng ở đúng độ cao sàn thì viền sẽ giật
    /// theo mỗi lần ARKit tinh chỉnh lại ước lượng plane.
    static let transitionBand: Float = 0.03

    /// Tên các argument của shader modifier, dùng cho `setValue(_:forKey:)`.
    enum Key {
        static let groundPlaneY = "groundPlaneY"
        static let hasGroundPlane = "hasGroundPlane"
        static let alphaScale = "belowGroundAlphaScale"
        static let transitionBand = "belowGroundTransitionBand"
    }

    /// `_surface.position` ở entry point `.fragment` nằm trong view space, nên
    /// phải đưa về world mới so được với `groundPlaneY` — giá trị mà
    /// `ViewARContext` đo trong world space của scene root.
    ///
    /// `#pragma transparent` là **bắt buộc**, không phải trang trí: nó ép
    /// SceneKit trộn theo `_output.color.rgb + (1 - _output.color.a) * dst.rgb`.
    /// Material của USDZ mặc định là opaque, mà với material opaque SceneKit
    /// bỏ qua hẳn alpha của fragment — thiếu dòng này thì ở trạng thái mặc
    /// định (slider Design = 100%) hiệu ứng sẽ im lặng không làm gì cả. Đổi
    /// lại, model luôn đi qua nhánh vẽ trong suốt kể cả khi không fade; alpha
    /// lúc đó bằng 1 nên nhìn không khác, nhưng thứ tự vẽ thì có đổi.
    ///
    /// Phương trình trộn đó nhận màu premultiplied, nên nhân cả RGBA cho cùng
    /// một hệ số chính là giảm alpha đúng nghĩa.
    ///
    /// `hasGroundPlane = 0` (chưa dò được sàn, hoặc người dùng tắt switch
    /// Ground grid) đưa hệ số về 1 — không fade gì cả.
    private static let modifier = """
    #pragma arguments
    float groundPlaneY;
    float hasGroundPlane;
    float belowGroundAlphaScale;
    float belowGroundTransitionBand;

    #pragma transparent
    #pragma body
    float3 belowGroundWorldPos = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).xyz;
    float belowGroundDelta = belowGroundWorldPos.y - groundPlaneY;
    float belowGroundAboveness = smoothstep(-belowGroundTransitionBand, 0.0, belowGroundDelta);
    float belowGroundFactor = mix(belowGroundAlphaScale, 1.0, belowGroundAboveness);
    _output.color *= mix(1.0, belowGroundFactor, hasGroundPlane);
    """

    /// Gắn modifier cho mọi material trong cây `node` và trả về danh sách
    /// material đó, để `ViewARContext` cache lại và cập nhật độ cao sàn sau này
    /// mà không phải duyệt lại cả cây.
    ///
    /// Duyệt `geometry.materials` chứ không chỉ `firstMaterial`: một node IFC
    /// xuất từ USDZ có thể mang nhiều material, bỏ sót cái nào là cái đó không
    /// fade.
    @discardableResult
    static func attach(to node: SCNNode) -> [SCNMaterial] {
        var materials: [SCNMaterial] = []

        func apply(_ node: SCNNode) {
            guard let geometry = node.geometry else { return }
            for material in geometry.materials {
                material.shaderModifiers = (material.shaderModifiers ?? [:])
                    .merging([.fragment: modifier]) { _, new in new }
                material.setValue(alphaScale, forKey: Key.alphaScale)
                material.setValue(transitionBand, forKey: Key.transitionBand)
                materials.append(material)
            }
        }

        apply(node)
        node.enumerateChildNodes { child, _ in apply(child) }
        return materials
    }

    /// Đẩy độ cao mặt sàn hiện tại vào các material đã gắn modifier.
    /// `groundPlaneY == nil` nghĩa là chưa có mặt sàn nào đang được bám.
    static func update(_ materials: [SCNMaterial], groundPlaneY: Float?) {
        for material in materials {
            material.setValue(groundPlaneY ?? 0, forKey: Key.groundPlaneY)
            material.setValue(groundPlaneY == nil ? Float(0) : Float(1), forKey: Key.hasGroundPlane)
        }
    }
}
