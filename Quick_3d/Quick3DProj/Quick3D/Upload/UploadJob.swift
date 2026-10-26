//
//  UploadJob.swift
//  Quick3D
//
//  QU3DW-1423 — one payload for every kind of upload the app can queue.
//

import Foundation

struct UploadJob: Identifiable {
    let id: UUID

    let cat: Cat

    let jobsiteId: String

    let displayName: String

    let kind: Kind

    let byteWeight: Int64?

    var catId: String { cat.id }

    var fileNames: [String] {
        switch kind {
        case .projectZip(let parameters):
            let pickedName = cat.zipFileName.map { $0.removingPercentEncoding ?? $0 }
            return [pickedName ?? parameters.fileURL.displayFileName]
        case .arZip(let parameters):
            return [parameters.fileURL.displayFileName]
        case .arFile(let parameters):
            let names = parameters.sourceFileNames.isEmpty
                ? [parameters.fileName]
                : parameters.sourceFileNames
            return names.map { $0.removingPercentEncoding ?? $0 }
        case .arData(let parameters):
            switch parameters.source {
            case .local(let file1URL, let file2URL):
                return [file1URL.displayFileName] + (file2URL.map { [$0.displayFileName] } ?? [])
            case .groupware(let groupware):
                return [groupware.name]
            case .groupwareWithLocalFile(let groupware, let file2URL):
                return [groupware.name, file2URL.displayFileName]
            }
        }
    }

    init(cat: Cat, jobsiteId: String, displayName: String? = nil, kind: Kind) {
        self.id = UUID()
        self.cat = cat
        self.jobsiteId = jobsiteId
        self.displayName = displayName ?? cat.title
        self.kind = kind
        self.byteWeight = UploadJob.byteWeight(of: kind)
    }
}

extension UploadJob {
    enum Kind {
        case projectZip(ZipParameters)
        case arZip(ZipParameters)
        case arFile(ARFileParameters)
        case arData(ARDataParameters)
    }

    static func projectZip(
        cat: Cat,
        jobsiteId: String,
        fileURL: URL,
        useARMarker: Bool,
        coordinateSetting: Bool,
        linkDashboard: Bool,
        shouldInterpolate: Bool,
        useAiProcessing: Bool = false
    ) -> UploadJob {
        UploadJob(
            cat: cat,
            jobsiteId: jobsiteId,
            kind: .projectZip(
                ZipParameters(
                    fileURL: fileURL,
                    useARMarker: useARMarker,
                    coordinateSetting: coordinateSetting,
                    linkDashboard: linkDashboard,
                    shouldInterpolate: shouldInterpolate,
                    useAiProcessing: useAiProcessing
                )
            )
        )
    }

    struct ZipParameters {
        let fileURL: URL
        let useARMarker: Bool
        let coordinateSetting: Bool
        let linkDashboard: Bool
        let shouldInterpolate: Bool
        let useAiProcessing: Bool
    }

    struct ARFileParameters {
        let fileURL: URL
        let fileName: String
        let arColor: String
        var sourceFileNames: [String] = []
    }

    struct ARDataParameters {
        let source: ARUploadSource
        let arColor: String
    }

    private static func byteWeight(of kind: Kind) -> Int64? {
        switch kind {
        case .projectZip(let parameters), .arZip(let parameters):
            return parameters.fileURL.fileSize.map(Int64.init)
        case .arFile(let parameters):
            return parameters.fileURL.fileSize.map(Int64.init)
        case .arData(let parameters):
            return parameters.source.byteWeight
        }
    }
}

extension UploadJob: Equatable {
    static func == (lhs: UploadJob, rhs: UploadJob) -> Bool {
        lhs.id == rhs.id
    }
}

extension ARUploadSource {
    var localFileURL: URL? {
        switch self {
        case .local(let file1URL, _):
            return file1URL
        case .groupware:
            return nil
        case .groupwareWithLocalFile(_, let file2URL):
            return file2URL
        }
    }

    var byteWeight: Int64? {
        switch self {
        case .local(let file1URL, let file2URL):
            guard let first = file1URL.fileSize else { return nil }
            return Int64(first) + Int64(file2URL?.fileSize ?? 0)
        case .groupware:
            return nil
        case .groupwareWithLocalFile(_, let file2URL):
            return file2URL.fileSize.map(Int64.init)
        }
    }
}

private extension URL {
    var displayFileName: String {
        lastPathComponent.removingPercentEncoding ?? lastPathComponent
    }
}
