//
//  CaptureContext.swift
//  Quick3D
//
//  Created by HaNST on 26/6/26.
//

import Foundation
import SwiftUI
import ARKit
import RealityKit

@available(iOS 18.0, *)
class ARCaptureContext: BaseCaptureContext<ARView>, CameraContext {
    
    struct MeshRecord {
        let mesh: LowLevelMesh
        let entity: ModelEntity
    }
    
    private var meshes: [UUID: MeshRecord] = [:]
    private var lastMeshUpdate: [UUID: TimeInterval] = [:]
    private var meshCopiesInFlight: Set<UUID> = []
    private var meshRoot: Entity?
    private var sharedMaterial: UnlitMaterial?
    
    // Mỗi anchor chỉ copy geometry tối đa 1 lần mỗi meshUpdateInterval.
    var meshUpdateInterval: TimeInterval = 0.5
    
    private static let meshLocalBounds = BoundingBox(
        min: [-5, -5, -5],
        max: [5, 5, 5]
    )
    
    override func setup(_ view: ARView) {
        super.setup(view)
        view.session.delegate = self
        
        let meshAnchor = AnchorEntity(world: matrix_identity_float4x4)
        view.scene.addAnchor(meshAnchor)
        meshRoot = meshAnchor
    }
    
    override func cleanupMesh() {
        Task { @MainActor in
            self.removeAllMeshes()
        }
    }
    
    // MARK: - Mesh add / update / remove
    
    @MainActor func add(_ anchor: ARMeshAnchor) {
        let id = anchor.identifier
        guard meshes[id] == nil else {
            update(anchor)
            return
        }
        guard !meshCopiesInFlight.contains(id) else { return }
        
        let geo = anchor.geometry
        let vSrc = geo.vertices
        let fSrc = geo.faces
        let vc = vSrc.count
        let ic = fSrc.count * fSrc.indexCountPerPrimitive
        
        guard vc > 0, ic > 0,
              vSrc.format == .float3,
              fSrc.bytesPerIndex == 4
        else { return }
        
        // Cấp phát dư 1.5× để geometry còn chỗ lớn thêm, tránh phải huỷ/tạo
        // lại mesh liên tục khi đang quét.
        let vCap = vc + vc / 2
        let iCap = ic + ic / 2
        
        let descriptor = LowLevelMesh.Descriptor(
            vertexCapacity: vCap,
            vertexAttributes: [
                LowLevelMesh.Attribute(semantic: .position, format: .float3,
                                       layoutIndex: 0, offset: 0)
            ],
            vertexLayouts: [
                LowLevelMesh.Layout(bufferIndex: 0, bufferStride: vSrc.stride)
            ],
            indexCapacity: iCap,
            indexType: .uint32
        )
        
        guard let mesh = try? LowLevelMesh(descriptor: descriptor),
              let meshResource = try? MeshResource(from: mesh)
        else { return }
        
        if sharedMaterial == nil {
            var material = UnlitMaterial(color: .white)
            material.blending = .transparent(opacity: 0.75)
            material.triangleFillMode = .lines
            sharedMaterial = material
        }
        
        let entity = ModelEntity(
            mesh: meshResource,
            materials: [sharedMaterial!]
        )
        entity.transform.matrix = anchor.transform
        meshRoot?.addChild(entity)
        
        let record = MeshRecord(mesh: mesh, entity: entity)
        meshes[id] = record
        lastMeshUpdate[id] = CACurrentMediaTime()
        
        meshCopy(geo, record: record, indexCount: ic,
                 transform: anchor.transform, id: id)
    }
    
    @MainActor func update(_ anchor: ARMeshAnchor) {
        let id = anchor.identifier
        guard let record = meshes[id] else {
            add(anchor)
            return
        }
        
        record.entity.transform.matrix = anchor.transform
        
        // Throttle: bỏ qua anchor chưa đến hạn hoặc đang copy dở
        let now = CACurrentMediaTime()
        guard now - (lastMeshUpdate[id] ?? 0) >= meshUpdateInterval,
              !meshCopiesInFlight.contains(id)
        else { return }
        
        let geo = anchor.geometry
        let vc = geo.vertices.count
        let ic = geo.faces.count * geo.faces.indexCountPerPrimitive
        guard vc > 0, ic > 0 else { return }
        
        // Tạo lại mesh nếu geometry vượt quá capacity của mesh hiện tại.
        guard vc <= record.mesh.vertexCapacity,
              ic <= record.mesh.indexCapacity
        else {
            remove(id)
            add(anchor)
            return
        }
        
        lastMeshUpdate[id] = now
        meshCopy(geo, record: record, indexCount: ic, transform: anchor.transform, id: id)
    }
    
    @MainActor func remove(_ id: UUID) {
        lastMeshUpdate.removeValue(forKey: id)
        guard let record = meshes.removeValue(forKey: id) else { return }
        record.entity.removeFromParent()
    }
    
    @MainActor func removeAllMeshes() {
        lastMeshUpdate.removeAll()
        meshes.values.forEach { $0.entity.removeFromParent() }
        meshes.removeAll()
    }
    
    // MARK: - GPU copy
    @MainActor private func meshCopy(
        _ geometry: ARMeshGeometry,
        record: MeshRecord,
        indexCount: Int,
        transform: simd_float4x4,
        id: UUID
    ) {
        guard let builder = MetalManager.shared.makeCommandBuilder() else { return }
        
        let vSrc = geometry.vertices
        let fSrc = geometry.faces
        
        meshCopiesInFlight.insert(id)
        
        builder.add(LowLevelMeshReplaceCommand(
            mesh: record.mesh,
            vertexSource: vSrc.buffer,
            vertexSourceOffset: vSrc.offset,
            vertexBytes: vSrc.count * vSrc.stride,
            indexSource: fSrc.buffer,
            indexBytes: indexCount * fSrc.bytesPerIndex
        ))
        
        record.mesh.parts.replaceAll([
            LowLevelMesh.Part(
                indexOffset: 0,
                indexCount: indexCount,
                topology: .triangle,
                materialIndex: 0,
                bounds: Self.meshLocalBounds
            )
        ])
        record.entity.transform.matrix = transform
        
        builder.onCompleted { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    _ = self?.meshCopiesInFlight.remove(id)
                }
            }
        }
        
        builder.commit()
    }
}

@available(iOS 18.0, *)
extension ARCaptureContext {
    
    @objc(session:didAddAnchors:)
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard status == .running, isEnableMesh else { return }
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        guard !meshAnchors.isEmpty else { return }
        Task { @MainActor in
            meshAnchors.forEach {
                self.add($0)
                CaptureSession.current?.appendMesh($0)
            }
        }
    }
    
    @objc(session:didUpdateAnchors:)
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard status == .running, isEnableMesh else { return }
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        guard !meshAnchors.isEmpty else { return }
        Task { @MainActor in
            meshAnchors.forEach {
                self.update($0)
                CaptureSession.current?.appendMesh($0)
            }
        }
    }
    
    @objc(session:didRemoveAnchors:)
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard isEnableMesh else { return }
        let ids = anchors.compactMap { ($0 as? ARMeshAnchor)?.identifier }
        guard !ids.isEmpty else { return }
        Task { @MainActor in
            ids.forEach {
                self.remove($0)
                CaptureSession.current?.removeMeshById($0)
            }
        }
    }
}
