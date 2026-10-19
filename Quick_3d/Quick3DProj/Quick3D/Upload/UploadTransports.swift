//
//  UploadTransports.swift
//  Quick3D
//
//  QU3DW-1423 — the adapters that sit between the queue and the existing network code.
//

import Foundation
import Alamofire

struct UploadTransportEnvironment {
    let uploadTask: UploadBackgroundTask
    let productData: ProductData
    let uploadProject: UploadProject
    let onProjectIdAssigned: (_ projectId: String, _ jobsiteId: String, _ cat: Cat) -> Void
}


final class ZipStreamTransport: UploadJobTransport {

    private let environment: UploadTransportEnvironment

    init(environment: UploadTransportEnvironment) {
        self.environment = environment
    }

    func start(
        job: UploadJob,
        onProgress: @escaping (Double) -> Void,
        onFinish: @escaping (UploadJobOutcome) -> Void
    ) {
        let isARZip: Bool
        let parameters: UploadJob.ZipParameters
        switch job.kind {
        case .projectZip(let value):
            parameters = value
            isARZip = false
        case .arZip(let value):
            parameters = value
            isARZip = true
        case .arFile, .arData:
            onFinish(.failure(.unknown))
            return
        }

        let task = environment.uploadTask
        task.uploadProgress = { progress in
            DispatchQueue.main.async { onProgress(progress) }
        }
        task.responseHandler = { [weak self] response in
            DispatchQueue.main.async {
                guard let self else {
                    onFinish(.failure(.unknown))
                    return
                }
                Task { @MainActor in
                    let outcome = isARZip
                        ? await self.finishARZip(job: job, response: response)
                        : await self.finishProjectZip(job: job, response: response)
                    onFinish(outcome)
                }
            }
        }

        if isARZip {
            task.uploadZipStream(
                with: job.cat,
                fileUrl: parameters.fileURL,
                jobsite: job.jobsiteId,
                useARMarker: parameters.useARMarker,
                coordinateSetting: parameters.coordinateSetting,
                linkDashboard: parameters.linkDashboard,
                shouldInterpolate: parameters.shouldInterpolate
            )
        } else {
            task.uploadStream(
                with: job.cat,
                fileUrl: parameters.fileURL,
                jobsite: job.jobsiteId,
                useARMarker: parameters.useARMarker,
                coordinateSetting: parameters.coordinateSetting,
                linkDashboard: parameters.linkDashboard,
                shouldInterpolate: parameters.shouldInterpolate
            )
        }
    }

    func cancel() {
        environment.uploadTask.cancelUpload()
    }

    @MainActor
    private func finishProjectZip(job: UploadJob, response: UploadFile?) async -> UploadJobOutcome {
        let productData = environment.productData
        productData.removeTempFile()

        guard let response else { return .failure(.network) }

        if response.isShortageImage == true {
            try? await productData.removeLocalProjectWithUpload(id: job.catId)
            try? await productData.refreshProjectListWithCurrentFilters()
            environment.uploadProject.isInsufficientPhoto = true
            return .failure(.businessError)
        }

        guard let projectId = response.projectId else { return .failure(.businessError) }

        if productData.products.contains(where: { $0.id == job.catId }) {
            try? await productData.removeLocalProjectWithUpload(id: job.catId)
            try? await productData.refreshProjectListWithCurrentFilters()
        }
        productData.updateProjectId(projectId, jobsiteId: job.jobsiteId, for: job.cat)
        environment.onProjectIdAssigned(projectId, job.jobsiteId, job.cat)
        productData.remove(job.cat)
        return .success
    }

    @MainActor
    private func finishARZip(job: UploadJob, response: UploadFile?) async -> UploadJobOutcome {
        let productData = environment.productData
        productData.removeTempFile()

        guard let response else { return .failure(.network) }

        if response.isShortageImage == true {
            environment.uploadProject.isInsufficientPhoto = true
            return .failure(.businessError)
        }

        try? await productData.refreshProjectListWithCurrentFilters()

        guard let projectId = response.projectId else { return .failure(.businessError) }
        productData.updateProjectId(projectId, jobsiteId: job.jobsiteId, for: job.cat)
        productData.remove(job.cat)
        return .success
    }
}


final class ARStreamTransport: UploadJobTransport {

    private let environment: UploadTransportEnvironment

    init(environment: UploadTransportEnvironment) {
        self.environment = environment
    }

    func start(
        job: UploadJob,
        onProgress: @escaping (Double) -> Void,
        onFinish: @escaping (UploadJobOutcome) -> Void
    ) {
        guard case .arFile(let parameters) = job.kind else {
            onFinish(.failure(.unknown))
            return
        }

        let task = environment.uploadTask
        task.uploadProgress = { progress in
            DispatchQueue.main.async { onProgress(progress) }
        }
        task.responseHandler = { [weak self] response in
            DispatchQueue.main.async {
                guard let self else {
                    onFinish(.failure(.unknown))
                    return
                }
                Task { @MainActor in
                    try? await self.environment.productData.refreshProjectListWithCurrentFilters()
                    self.environment.productData.removeARTempFile(fileName: parameters.fileName)
                    onFinish(response == nil ? .failure(.unknown) : .success)
                }
            }
        }

        task.uploadARStream(
            with: job.cat,
            jobsite: job.jobsiteId,
            fileUrl: parameters.fileURL,
            fileName: parameters.fileName,
            ar_color: parameters.arColor
        )
    }

    func cancel() {
        environment.uploadTask.cancelUpload()
    }
}


final class ARDataTransport: UploadJobTransport {

    private let environment: UploadTransportEnvironment

    init(environment: UploadTransportEnvironment) {
        self.environment = environment
    }

    func start(
        job: UploadJob,
        onProgress: @escaping (Double) -> Void,
        onFinish: @escaping (UploadJobOutcome) -> Void
    ) {
        guard case .arData(let parameters) = job.kind else {
            onFinish(.failure(.unknown))
            return
        }

        environment.productData.uploadARData(
            cat: job.cat,
            jobsiteId: job.jobsiteId,
            arColor: parameters.arColor,
            source: parameters.source,
            progress: { fraction in
                DispatchQueue.main.async { onProgress(fraction) }
            },
            completion: { [weak self] response in
                Task { @MainActor in
                    try? await self?.environment.productData.refreshProjectListWithCurrentFilters()
                    onFinish(response.error == nil ? .success : .failure(.network))
                }
            }
        )
    }

    func cancel() {
        environment.productData.cancelARUpload()
    }
}


struct AppUploadTransportFactory: UploadJobTransportFactory {

    let environment: UploadTransportEnvironment

    func transport(for job: UploadJob) -> UploadJobTransport {
        switch job.kind {
        case .projectZip, .arZip:
            return ZipStreamTransport(environment: environment)
        case .arFile:
            return ARStreamTransport(environment: environment)
        case .arData:
            return ARDataTransport(environment: environment)
        }
    }
}
