//
//  PointProgram.swift
//  Quick3DDemo
//
//  Tầng ⑥ (shader) — SCNProgram = ShaderMaterial của Three.js.
//  Chỉ tên hàm vertex/fragment + closure nạp uniform mỗi frame.
//  Trong project thật: Camera/Metal/MetalViewARProgram.swift
//

import SceneKit
import Metal

final class PointProgram: SCNProgram {

    // "uniform" — đổi giá trị ở đây, frame sau shader nhận được
    var pointCount: Int32 = -1          // -1 = vẽ hết
    var pointSize: Float = 14
    var opacity: Float = 1

    override init() {
        super.init()

        vertexFunctionName = "demoVertex"
        fragmentFunctionName = "demoFragment"
        isOpaque = false                 // cho phép blend alpha

        // Xcode biên dịch Shaders.metal vào default.metallib của app;
        // SCNProgram tự tìm hàm theo tên trong main bundle, không cần chỉ library.

        // Tương đương material.uniforms.pointSize.value = … nhưng theo kiểu "pull":
        // SceneKit gọi closure này mỗi frame trước khi vẽ node dùng program.
        handleBinding(ofBufferNamed: "pointCount", frequency: .perFrame) { [weak self] buffer, _, _, _ in
            var v = self?.pointCount ?? -1
            buffer.writeBytes(&v, count: MemoryLayout<Int32>.size)
        }
        handleBinding(ofBufferNamed: "pointSize", frequency: .perFrame) { [weak self] buffer, _, _, _ in
            var v = self?.pointSize ?? 1
            buffer.writeBytes(&v, count: MemoryLayout<Float>.size)
        }
        handleBinding(ofBufferNamed: "opacity", frequency: .perFrame) { [weak self] buffer, _, _, _ in
            var v = self?.opacity ?? 1
            buffer.writeBytes(&v, count: MemoryLayout<Float>.size)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
