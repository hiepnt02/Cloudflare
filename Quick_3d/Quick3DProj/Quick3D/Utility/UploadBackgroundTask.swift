//
//  UploadBackgroundTask.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 30/06/2022.
//

import Foundation

class UploadBackgroundTask: NSObject {
    // HTTPBodyデータの作成に使用
    private let boundary = "example.boundary.\(ProcessInfo.processInfo.globallyUniqueString)"
    private let fileManager = FileManager.default
    private let streamBufferSize = 1024
    
    var uploadProgress: ((Double) -> Void)?
    var responseHandler: ((UploadFile?) -> Void)?
    
    private var uploadTask: URLSessionUploadTask?
    
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
    
    func upload(with cat: Cat, fileUrl: URL, jobsite: String, useARMarker: Bool) {
        var request = URLRequest(url: URL(string: Constant.baseUrl + "api/v1/project")!)
        if cat.projectId != nil {
            request.url = URL(string: Constant.baseUrl + "api/v1/project/" + cat.projectId! )!
            request.httpMethod = "PUT"
        } else {
            request.httpMethod = "POST"
        }
        request.setValue("multipart/form-data; boundary=\(self.boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        guard let inputStream = InputStream(url: fileUrl) else {
            return
        }
        
        inputStream.open()
        defer { inputStream.close() }
        
        var encoded = Data()
        
        // ファイルのURLを読み取る
        while inputStream.hasBytesAvailable {
            var buffer = [UInt8](repeating: 0, count: streamBufferSize)
            let bytesRead = inputStream.read(&buffer, maxLength: streamBufferSize)
            
            if let error = inputStream.streamError {
                print(error.localizedDescription.description)
                return
            }
            
            if bytesRead > 0 {
                encoded.append(buffer, count: bytesRead)
            } else {
                break
            }
        }
        
        let data = createHttpBody(binaryData: encoded,
                                  fieldName: "uploadFile",
                                  fileName: "archive.zip",
                                  mimeType: "application/zip",
                                  parameters: ["jobsiteId": jobsite,
                                               "projectName": cat.title,
                                               "directory": cat.folderName,
                                               "useArmarker": useARMarker,
                                               "timeStamp": cat.createDate.toString(format: Constant.rfcFormat, timeZone: .utc),
                                               "timezone": TimeZone.current.secondsFromGMT()/60])
        
        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent("uploadFile")
        try? data.write(to: localURL)
        
        let task = session.uploadTask(with: request, fromFile: localURL)
        task.resume()
    }
    
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
    
    func uploadStream(with cat: Cat, fileUrl: URL, jobsite: String, useARMarker: Bool, coordinateSetting: Bool, linkDashboard: Bool, shouldInterpolate: Bool) {
        var request = URLRequest(url: URL(string: Constant.baseUrl + "api/v1/project")!)
        
        if cat.projectId != nil {
            request.url = URL(string: Constant.baseUrl + "api/v1/project/" + cat.projectId! )!
            request.httpMethod = "PUT"
        } else {
            request.httpMethod = "POST"
        }
        request.setValue("multipart/form-data; boundary=\(self.boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent("uploadFile")
        print(localURL.absoluteString)
        do {
            try? Data().write(to: localURL)
            let file = try FileHandle.init(forWritingTo: localURL)
            
            guard let inputStream = InputStream(url: fileUrl) else {
                return
            }
            
            inputStream.open()
            defer { inputStream.close() }
            
            createHttpStreamBody(
                outputFile: file,
                inputStream: inputStream,
                fieldName: "uploadFile",
                fileName: "archive.zip",
                mimeType: "application/x-zip-compressed",
                parameters:
                    [
                        "jobsiteId": jobsite,
                        "projectName": cat.title,
                        "directory": cat.folderName,
                        "useArmarker": useARMarker ? "1" : "0",
                        "coordinateSetting": coordinateSetting ? "1" : "0",
                        "linkDashboard": linkDashboard ? "1" : "0",
                        "shouldInterpolate": shouldInterpolate ? "1" : "0",
                        "timeStamp": cat.createDate.toString(format: Constant.rfcFormat, timeZone: .utc),
                        "timezone": TimeZone.current.secondsFromGMT()/60,
                        "vertical": cat.vertical ?? "",
                        "horizontal": cat.horizontal ?? ""
                    ]
            )
            
            file.closeFile()
        } catch {
            print(error.localizedDescription)
            return
        }
        
        cancelUpload()
        uploadTask = session.uploadTask(with: request, fromFile: localURL)
        uploadTask?.resume()
    }
    
    func uploadARStream(with cat: Cat, jobsite: String, fileUrl: URL, fileName: String, ar_color: String) {
        var request = URLRequest(url: URL(string: Constant.baseUrl + "api/v1/project/ar")!)
        
        
        request.url = URL(string: Constant.baseUrl + "api/v1/project/" + cat.projectId! + "/ar" )!
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(self.boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent("uploadFile")
        print(localURL.absoluteString)
        do {
            try? Data().write(to: localURL)
            let file = try FileHandle.init(forWritingTo: localURL)
            
            guard let inputStream = InputStream(url: fileUrl) else {
                return
            }
            
            inputStream.open()
            defer { inputStream.close() }
            
            let fileExtension = URL(fileURLWithPath: fileName).pathExtension
            print("File extension: \(fileExtension)")
            
            createHttpStreamBody(
                outputFile: file,
                inputStream: inputStream,
                fieldName: "uploadFile",
                fileName: fileName,
                mimeType: "application/\(fileExtension)",
                parameters:
                    ["jobsiteId": jobsite,
                     "projectName": cat.title,
                     "timeStamp": cat.createDate.toString(format: Constant.rfcFormat, timeZone: .utc),
                     "timezone": TimeZone.current.secondsFromGMT()/60,
                     "ARColor":ar_color,
                     "uploadFileName": fileName,
                     "name": fileName
                    ]
            )
            
            file.closeFile()
        } catch {
            print(error.localizedDescription)
            return
        }
        
        cancelUpload()
        uploadTask = session.uploadTask(with: request, fromFile: localURL)
        uploadTask?.resume()
    }
    
    func uploadZipStream(with cat: Cat, fileUrl: URL, jobsite: String, useARMarker: Bool, coordinateSetting: Bool, linkDashboard: Bool, shouldInterpolate: Bool) {
        let folderName = "\(NSUUID().uuidString)"
        var request = URLRequest(url: URL(string: Constant.baseUrl + "api/v1/project")!)
        
        if cat.projectId != nil {
            request.url = URL(string: Constant.baseUrl + "api/v1/project/" + cat.projectId! + "/ar/zip" )!
            request.httpMethod = "POST"
        }
        request.setValue("multipart/form-data; boundary=\(self.boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent("uploadFile")
        print(localURL.absoluteString)
        do {
            try? Data().write(to: localURL)
            let file = try FileHandle.init(forWritingTo: localURL)
            
            guard let inputStream = InputStream(url: fileUrl) else {
                return
            }
            
            inputStream.open()
            defer { inputStream.close() }
            
            createHttpStreamBody(
                outputFile: file,
                inputStream: inputStream,
                fieldName: "uploadFile",
                fileName: "archive.zip",
                mimeType: "application/x-zip-compressed",
                parameters:
                    [
                        "jobsiteId": jobsite,
                        "projectName": cat.title,
                        "directory": cat.folderName,
                        "useArmarker": useARMarker ? "1" : "0",
                        "coordinateSetting": coordinateSetting ? "1" : "0",
                        "linkDashboard": linkDashboard ? "1" : "0",
                        "shouldInterpolate": shouldInterpolate ? "1" : "0",
                        "timeStamp": cat.createDate.toString(format: Constant.rfcFormat, timeZone: .utc),
                        "timezone": TimeZone.current.secondsFromGMT()/60
                    ]
            )
            
            file.closeFile()
        } catch {
            print(error.localizedDescription)
            return
        }
        
        cancelUpload()
        uploadTask = session.uploadTask(with: request, fromFile: localURL)
        uploadTask?.resume()
    }
    
    // HttpBodyデータを作成する
    private func createHttpStreamBody(
        outputFile: FileHandle,
        inputStream: InputStream,
        fieldName: String,
        fileName: String, 
        mimeType: String,
        parameters: [String: Any]
    ) {
        // ファイルデータを追加する
        var postContent = "--\(boundary)\r\n"
        postContent += "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n"
        postContent += "Content-Type: \(mimeType)\r\n\r\n"
        
        guard let postData = postContent.data(using: .utf8) else { return }
        outputFile.write(postData)
        
        // Write InputStream to FileHandle in case InputStream not nill
        while inputStream.hasBytesAvailable {
            var buffer = [UInt8](repeating: 0, count: streamBufferSize)
            let bytesRead = inputStream.read(&buffer, maxLength: streamBufferSize)
            
            if let error = inputStream.streamError {
                print(error.localizedDescription.description)
                return
            }
            
            if bytesRead > 0 && bytesRead < streamBufferSize {
                let lastBuffer = Array(buffer[0..<bytesRead])
                try? outputFile.write(contentsOf: lastBuffer)
            } else if bytesRead > 0 && bytesRead == streamBufferSize {
                try? outputFile.write(contentsOf: buffer)
            } else {
                break
            }
        }
        
        // その他パラメータがあれば追加
        var content = ""
        parameters.forEach {
            content += "\r\n--\(boundary)\r\n"
            content += "Content-Disposition: form-data; name=\"\($0.key)\"\r\n\r\n"
            content += "\($0.value)"
        }
        if let postData = content.data(using: .utf8) {
            outputFile.write(postData)
        }
        
        // HTTPBodyの終了を設定
        guard let endData = "\r\n--\(boundary)--\r\n".data(using: .utf8) else { return }
        outputFile.write(endData)
        return
    }
}

extension UploadBackgroundTask: URLSessionTaskDelegate, URLSessionDataDelegate {
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
        //session.finishTasksAndInvalidate()
    }
    
    func cancelUpload() {
        uploadTask?.cancel()
        uploadTask = nil // Clear the reference after cancelling.
    }
}
