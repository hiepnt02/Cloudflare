//
//  DxfReader.swift
//  Quick3D
//

import Foundation

/// Downloads the project's DXF (uploaded together with the LAS) for the AR overlay.
/// Most projects have none; that is not an error for the AR view, so failures only log.
class DxfReader: ARProjectHelper {

    private let url: URL

    override init(projectId: String) {
        self.url = URL(string: Constant.baseUrl + "api/v1/project/\(projectId)/ARdownload/DXF")!
        super.init(projectId: projectId)
    }

    /// The drawing's edges, or nil when the project has no usable DXF.
    func fetch() async -> [DxfEdge]? {
        do {
            let presignUrl = try await getPresignUrl(url)
            let fileUrl = try await downloadFile(presignUrl, fileName: "overlay.dxf")
            let edges = DxfParser.parseEdges(try Data(contentsOf: fileUrl))
            print("[DXF] \(edges.count) edges")
            return edges.isEmpty ? nil : edges
        } catch {
            print("[DXF] no overlay: \(error)")
            return nil
        }
    }
}
