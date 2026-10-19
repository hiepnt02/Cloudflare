//
//  UploadPLYTask.swift
//  Quick3D
//
//  Created by 横内浩志 on 2023/01/10.
//

import Foundation

class UploadPLYTask: NSObject {
    // HTTPBodyデータの作成に使用
    private let boundary = "example.boundary.\(ProcessInfo.processInfo.globallyUniqueString)"
    private let fileManager = FileManager.default
    private let streamBufferSize = 1024
    
    var uploadProgress: ((Double) -> Void)?
    var responseHandler: ((UploadFile?) -> Void)?

    // urlSessionの背景を定義する
    lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: UUID().uuidString)
        if let sessionId = UserSession.shared.sessionId {
            let cookieProps = [
                HTTPCookiePropertyKey.domain: Constant.domainUrl,
                HTTPCookiePropertyKey.path: "/",
                HTTPCookiePropertyKey.name: "connect.sid",
                HTTPCookiePropertyKey.value: sessionId
            ]
            if let cookie = HTTPCookie(properties: cookieProps) {
                configuration.httpCookieStorage?.setCookie(cookie)
            }
        }
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)

    }()

    // HttpBodyデータを作成する
    private func createHttpBody(binaryData: Data, fieldName: String, fileName: String, mimeType: String, parameters: [String: Any]) -> Data {
        // ファイルデータを追加する
        var postContent = "--\(boundary)\r\n"
        postContent += "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n"
        postContent += "Content-Type: \(mimeType)\r\n\r\n"

        var data = Data()
        guard let postData = postContent.data(using: .utf8) else { return data }
        data.append(postData)
        data.append(binaryData)

        // その他パラメータがあれば追加
        var content = ""
        parameters.forEach {
            content += "\r\n--\(boundary)\r\n"
            content += "Content-Disposition: form-data; name=\"\($0.key)\"\r\n\r\n"
            content += "\($0.value)"
        }
        if let postData = content.data(using: .utf8) {
            data.append(postData)
        }

        // HTTPBodyの終了を設定
        guard let endData = "\r\n--\(boundary)--\r\n".data(using: .utf8) else { return data }
        data.append(endData)
        return data
    }
}

extension UploadPLYTask: URLSessionTaskDelegate, URLSessionDataDelegate {
    // アップロードの進行状況のコールバック
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        uploadProgress?(Double(totalBytesSent)/Double(totalBytesExpectedToSend))
    }

    // エラーのコールバック
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            responseHandler?(nil)
        }
    }

    // タスク応答のコールバック
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let resp = try? JSONDecoder().decode(UploadFile.self, from: data)
        responseHandler?(resp)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        session.finishTasksAndInvalidate()
    }
}
