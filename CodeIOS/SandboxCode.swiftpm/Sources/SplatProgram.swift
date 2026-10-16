//
//  SplatProgram.swift
//  Quick3DDemo
//
//  SCNProgram cho Gaussian splatting (splatVertex / splatFragment trong Shaders.metal).
//  Ngoài 2 uniform, binding per-frame còn là chỗ duy nhất SceneKit cho ta biết "đang vẽ node này
//  với camera nào" → dùng để kích hoạt sắp xếp độ sâu trong SplatCloud (không cần SCNSceneRendererDelegate).
//

import SceneKit
import Metal

final class SplatProgram: SCNProgram {

    /// Nhân σ của mọi splat (1 = đúng file). Slider Point size / 14.
    var splatScale: Float = 1
    var opacity: Float = 1
    /// Gọi mỗi frame trên thread render với node đang vẽ và renderer (để lấy pointOfView).
    var onFrame: ((SCNNode, SCNRenderer) -> Void)?

    override init() {
        super.init()
        vertexFunctionName = "splatVertex"
        fragmentFunctionName = "splatFragment"
        isOpaque = false

        handleBinding(ofBufferNamed: "splatScale", frequency: .perFrame) { [weak self] buffer, _, _, _ in
            var v = self?.splatScale ?? 1
            buffer.writeBytes(&v, count: MemoryLayout<Float>.size)
        }
        handleBinding(ofBufferNamed: "opacity", frequency: .perFrame) { [weak self] buffer, node, _, renderer in
            var v = self?.opacity ?? 1
            buffer.writeBytes(&v, count: MemoryLayout<Float>.size)
            self?.onFrame?(node, renderer)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
