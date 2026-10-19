//
//  PlaneGridNode.swift
//  Quick3D
//

import ARKit
import CoreGraphics
import SceneKit

/// Lưới ô vuông phủ lên mặt phẳng ngang (mặt sàn) mà ARKit phát hiện được.
///
/// Lưới được vẽ sau model/point cloud nhưng vẫn đọc depth buffer, nên bị model
/// nằm trên mặt sàn che đúng như một decal thật. Việc làm nhạt phần model nằm
/// dưới mặt sàn KHÔNG còn do node này đảm nhiệm nữa — point cloud tự làm việc
/// đó trong shader của chính nó (xem MetalViewARProgram/Shaders.metal), so
/// sánh trực tiếp world-Y của từng điểm với độ cao mặt sàn mà ViewARContext
/// theo dõi. `fillAlpha` ở đây giờ chỉ còn là độ đậm của lưới trên mặt sàn
/// thật, không còn ảnh hưởng gì đến độ nhạt của model nữa.
final class PlaneGridNode: SCNNode {

    static let nodeName = "PlaneGridNode"

    /// Cạnh của ô lưới lớn (đường đậm), tính bằng mét.
    static let cellSize: Float = 1.0

    /// Số ô nhỏ trong một ô lớn: ô nhỏ = `cellSize / subdivisions` = 0.2 m.
    /// Ô nhỏ cho cảm giác về khoảng cách, đường đậm mỗi mét cho mốc đo thật.
    private static let subdivisions = 5

    /// Mặt phẳng nhỏ hơn ngưỡng này thường là nhiễu, chưa vẽ lưới.
    private static let minExtent: Float = 0.2

    /// Nhấc lưới khỏi mặt phẳng để không bị z-fighting với occlusion plane hoặc
    /// scene mesh của ARKit. Cạnh tam giác của scene mesh đo trên iPad Pro là
    /// ~3 cm (trung vị), có chỗ tới ~9 cm, nên phải nhấc cao hơn 1 cm mới đủ.
    private static let surfaceOffset: Float = 0.03

    /// Ngưỡng thay đổi (mét) tối thiểu để dựng lại hình học lưới. ARKit cập nhật
    /// plane anchor nhiều lần mỗi giây; mỗi lần đổi `SCNPlane.width/height` là
    /// một lần dựng lại geometry nên viền lưới không bao giờ đứng yên.
    private static let updateThreshold: Float = 0.02

    /// Vẽ sau cùng: lớn hơn renderingOrder của model (0, hoặc 100 khi bật occlusion).
    private static let renderOrder = 500

    /// Độ mờ của lớp phủ trên toàn mặt phẳng. Để 0: lưới chỉ còn các đường,
    /// không có nền. Không còn liên quan gì đến độ nhạt của model nằm dưới mặt
    /// sàn (xem doc ở đầu file).
    ///
    /// Từng chốt 10% trên máy (thang 0–50%, bước 10%) nhưng phải bỏ: một lớp
    /// alpha thấp phủ kín mặt sàn làm lộ ra chỗ khác nhau giữa hai đường render
    /// của ARSCNView. Occlusion ON (people occlusion — scene được vẽ ra offscreen
    /// rồi composite theo alpha lên ảnh camera) và Occlusion OFF (blend thẳng lên
    /// ảnh camera) cho ra độ đậm nền khác nhau, nên độ sáng của sàn thật đổi theo
    /// switch Occlusion (ON đậm, OFF nhạt). Đường lưới alpha cao gần như không bị
    /// ảnh hưởng. Nếu bật lại nền thì phải soi sàn ở cả hai chế độ Occlusion.
    private static let fillAlpha: CGFloat = 0

    /// Đường chia ô nhỏ và đường mốc mỗi `cellSize` mét. Phải đậm hơn
    /// `fillAlpha` đủ nhiều, không thì lưới bị chính lớp phủ làm mờ mất.
    ///
    /// Không chọn tự do mà suy ra từ `fillAlpha` để giữ đúng tỉ lệ tương phản
    /// (phần headroom còn lại tới alpha = 1) như mức 0.08 → 0.40/0.85 từng
    /// được xác nhận là vừa mắt:
    ///
    ///     minor = 1 − 0.65 × (1 − fillAlpha)
    ///     major = 1 − 0.16 × (1 − fillAlpha)
    ///
    /// Đổi `fillAlpha` thì tính lại hai số này theo đúng hai công thức trên,
    /// đừng nhấn tay từng số — lưới sẽ mất cái "tính cách" đường đọc rõ trên
    /// một lớp phủ nhạt.
    private static let minorLineAlpha: CGFloat = 0.35
    private static let majorLineAlpha: CGFloat = 0.84

    private let plane: SCNPlane
    private var lastExtent: SIMD3<Float> = .zero
    private var lastCenter: SIMD3<Float> = .zero

    init(anchor: ARPlaneAnchor) {
        let plane = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        plane.materials = [PlaneGridNode.makeMaterial()]
        self.plane = plane

        super.init()

        name = PlaneGridNode.nodeName
        geometry = plane
        // SCNPlane nằm trong mặt phẳng XY, xoay về mặt phẳng XZ của plane anchor.
        eulerAngles.x = -.pi / 2
        renderingOrder = PlaneGridNode.renderOrder
        castsShadow = false

        update(with: anchor)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Chỉ vẽ lưới cho mặt sàn.
    ///
    /// Mặt bàn, mặt ghế, trần nhà cũng là mặt phẳng ngang nhưng không phải mặt
    /// đất nên phải loại ra. `.none` là trường hợp ARKit chưa/không phân loại
    /// được (máy không có LiDAR) — vẫn vẽ, vì nếu bỏ thì các máy đó không có lưới.
    static func canDisplay(for anchor: ARPlaneAnchor) -> Bool {
        guard anchor.alignment == .horizontal else { return false }
        switch anchor.classification {
        case .floor, .none:
            return true
        default:
            return false
        }
    }

    func update(with anchor: ARPlaneAnchor) {
        let extent = anchor.extent
        let center = anchor.center

        // Bỏ qua những cập nhật li tí: chúng chỉ làm dựng lại geometry chứ không
        // thay đổi gì thấy được. `hasGeometry` để lần đầu luôn được vẽ.
        let hasGeometry = lastExtent != .zero
        let extentChange = max(abs(extent.x - lastExtent.x), abs(extent.z - lastExtent.z))
        let centerChange = simd_distance(center, lastCenter)
        guard !hasGeometry
                || extentChange > PlaneGridNode.updateThreshold
                || centerChange > PlaneGridNode.updateThreshold else { return }

        lastExtent = extent
        lastCenter = center

        // Tắt animation ngầm của SceneKit. Mặc định mọi thay đổi kích thước/vị trí
        // được nội suy trong 0.25 s, nên viền lưới và viền vật thể cứ chạy liên tục.
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0

        plane.width = CGFloat(extent.x)
        plane.height = CGFloat(extent.z)
        simdPosition = center + SIMD3<Float>(0, PlaneGridNode.surfaceOffset, 0)
        isHidden = min(extent.x, extent.z) < PlaneGridNode.minExtent
        plane.firstMaterial?.diffuse.contentsTransform = PlaneGridNode.textureTransform(for: anchor)

        SCNTransaction.commit()
    }

    // MARK: - Material

    private static func makeMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = gridTexture
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        material.diffuse.magnificationFilter = .linear
        material.diffuse.mipFilter = .linear
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.blendMode = .alpha
        // Đọc depth để bị model phía trên mặt sàn che, nhưng không ghi depth để
        // không che mất những gì được vẽ sau nó (trục toạ độ, vật thể ảo khác).
        material.readsFromDepthBuffer = true
        material.writesToDepthBuffer = false
        return material
    }

    /// Một ô lưới lớn: nền mờ, các đường mảnh chia ô nhỏ, và hai cạnh đậm ở
    /// cạnh trên/trái. Khi texture được lặp lại, các cạnh đậm ghép thành đường
    /// mốc mỗi `cellSize` mét, còn đường mảnh chia đều bên trong.
    ///
    /// Node được tạo từ các callback của `ARSCNViewDelegate`, tức là chạy trên
    /// render thread của SceneKit, nên texture phải dựng bằng Core Graphics —
    /// `UIGraphicsImageRenderer` chạm vào state của UIKit (chỉ dùng ở main thread).
    private static let gridTexture: CGImage? = {
        let side = 256
        let minorLineWidth: CGFloat = 2
        let majorLineWidth: CGFloat = 5

        guard let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let bounds = CGRect(x: 0, y: 0, width: CGFloat(side), height: CGFloat(side))

        // .copy để mỗi lần fill đặt thẳng alpha mong muốn thay vì cộng dồn lên
        // lớp phủ đã vẽ — nhờ vậy ba mức đậm nhạt đúng bằng ba hằng số ở trên.
        context.setBlendMode(.copy)

        context.setFillColor(red: 1, green: 1, blue: 1, alpha: fillAlpha)
        context.fill(bounds)

        // Đường chia ô nhỏ
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: minorLineAlpha)
        let step = bounds.width / CGFloat(subdivisions)
        for index in 1..<subdivisions {
            // 256 px không chia hết cho 5 ô: làm tròn về pixel nguyên để các
            // đường không bị anti-alias thành đậm nhạt khác nhau.
            let offset = (step * CGFloat(index)).rounded()
            context.fill(CGRect(x: offset, y: 0, width: minorLineWidth, height: bounds.height))
            context.fill(CGRect(x: 0, y: offset, width: bounds.width, height: minorLineWidth))
        }

        // Đường mốc mỗi cellSize mét
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: majorLineAlpha)
        context.fill(CGRect(x: 0, y: 0, width: bounds.width, height: majorLineWidth))
        context.fill(CGRect(x: 0, y: 0, width: majorLineWidth, height: bounds.height))

        return context.makeImage()
    }()

    /// Số lần lặp texture theo kích thước thật của mặt phẳng, nhờ đó mỗi ô lớn
    /// luôn là hình vuông `cellSize` mét bất kể mặt phẳng lớn nhỏ.
    ///
    /// Phần dịch (translation) neo pha của lưới vào gốc toạ độ của anchor: góc
    /// (u, v) = 0 của `SCNPlane` nằm ở (center.x - extent.x / 2, center.z - extent.z / 2)
    /// trong không gian anchor, nên các đường lưới không bị trượt khi ARKit mở
    /// rộng dần mặt phẳng.
    private static func textureTransform(for anchor: ARPlaneAnchor) -> SCNMatrix4 {
        let scale = SCNMatrix4MakeScale(
            SCNFloat(anchor.extent.x / cellSize),
            SCNFloat(anchor.extent.z / cellSize),
            1
        )
        let translation = SCNMatrix4MakeTranslation(
            SCNFloat((anchor.center.x - anchor.extent.x / 2) / cellSize),
            SCNFloat((anchor.center.z - anchor.extent.z / 2) / cellSize),
            0
        )
        return SCNMatrix4Mult(scale, translation)
    }
}
