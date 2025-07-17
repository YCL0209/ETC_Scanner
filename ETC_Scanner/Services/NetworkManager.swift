//
//  NetworkManager.swift
//  ETC_Scanner
//
//  Created on 2025/07/17.
//  網路層管理器，負責所有網路請求和資料傳輸
//

import Foundation

// MARK: - FileInfo 結構
struct FileInfo: Codable {
    let fileName: String
    let size: Int
    let uploadTime: String
    
    // 計算格式化的檔案大小
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    // 計算格式化的上傳時間
    var formattedTime: String {
        // 假設 uploadTime 格式為 "2024-12-11T08:49:43.073Z"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = dateFormatter.date(from: uploadTime) {
            dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
            dateFormatter.timeZone = TimeZone.current
            return dateFormatter.string(from: date)
        }
        
        return uploadTime
    }
}

// 伺服器回應結構
struct ServerResponse: Codable {
    let success: Bool
    let files: [FileInfo]
}

// MARK: - NetworkManager
class NetworkManager {
    static let shared = NetworkManager()
    
    // MARK: - Properties
    
    // 修改預設伺服器 URL 為新的 API 網址
    private var _serverURL: String = "https://sui-yao.com"
    private var serverURL: String {
        get {
            return UserDefaults.standard.string(forKey: "serverURL") ?? _serverURL
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "serverURL")
        }
    }
    
    // API 金鑰
    private var _apiKey: String = "MasHsieh0817"
    var apiKey: String {
        get {
            return UserDefaults.standard.string(forKey: "apiKey") ?? _apiKey
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "apiKey")
        }
    }
    
    // 檔案名稱
    private var fileName: String = "住戶ETC資料.csv"
    
    // 管理員密碼
    private let adminPassword = "123456"
    
    // Email 伺服器 URL
    private var _emailServerURL: String = "https://script.google.com/macros/s/AKfycbwjOkNFAyT-NyHjF4UnXE9slV-SjujYKuN98DQGqoJSUxxpYC9rnqrxLCG4j-kmS7iISQ/exec"
    var emailServerURL: String {
        get {
            return UserDefaults.standard.string(forKey: "emailServerURL") ?? _emailServerURL
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "emailServerURL")
        }
    }
    
    // MARK: - URLSession Configuration
    
    // 優化的 URLSession 配置
    private(set) lazy var optimizedSession: URLSession = {
        let config = URLSessionConfiguration.default
        
        // 增加超時時間以處理大檔案
        config.timeoutIntervalForRequest = 300 // 5 分鐘
        config.timeoutIntervalForResource = 600 // 10 分鐘
        
        // 優化連接設定
        config.httpMaximumConnectionsPerHost = 2
        config.httpShouldUsePipelining = true
        config.httpShouldSetCookies = false
        
        // 設定快取策略
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        
        // 允許蜂窩網路
        config.allowsCellularAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        
        // 背景任務設定
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        
        // 設定網路服務類型為背景傳輸
        config.networkServiceType = .background
        
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    // MARK: - Public Methods
    
    // 獲取檔案名稱
    func getFileName() -> String {
        return fileName
    }
    
    // 更新設定
    func updateSettings(newURL: String, newFileName: String, newAPIKey: String = "", password: String) -> Bool {
        guard password == adminPassword else {
            return false
        }
        serverURL = newURL
        fileName = newFileName
        UserDefaults.standard.set(newFileName, forKey: "fileName")
        
        if !newAPIKey.isEmpty {
            apiKey = newAPIKey
        }
        
        return true
    }
    
    // MARK: - Server Status Check
    
    func checkServerStatus(completion: @escaping (Bool, String?) -> Void) {
        let baseURL = getBaseURL()
        
        guard let url = URL(string: "\(baseURL)/api/status") else {
            completion(false, "無效的伺服器網址")
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let task = optimizedSession.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(false, "網路錯誤：\(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "未收到伺服器回應")
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                completion(false, "伺服器回應異常：\(httpResponse.statusCode)")
                return
            }
            
            completion(true, nil)
        }
        task.resume()
    }
    
    // MARK: - File Operations
    
    // 下載 CSV 檔案
    func downloadCSV(fileName: String, completion: @escaping (Result<Data, Error>) -> Void) {
        downloadCSVWithRetry(fileName: fileName, retryCount: 3, completion: completion)
    }
    
    private func downloadCSVWithRetry(fileName: String, retryCount: Int, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = getDownloadURL(fileName: fileName) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無效的URL"])))
            return
        }
        
        let downloadStartTime = Date()
        
        var request = URLRequest(url: url)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 120.0
        
        let task = optimizedSession.downloadTask(with: request) { [weak self] (tempURL, response, error) in
            let downloadEndTime = Date()
            let downloadDuration = downloadEndTime.timeIntervalSince(downloadStartTime)
            
            print("下載耗時: \(downloadDuration) 秒")
            
            if let error = error {
                print("下載錯誤: \(error)")
                
                if retryCount > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self?.downloadCSVWithRetry(fileName: fileName, retryCount: retryCount - 1, completion: completion)
                    }
                    return
                }
                
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無效的回應"])))
                return
            }
            
            let expectedSize = httpResponse.expectedContentLength
            print("預期檔案大小: \(expectedSize) bytes")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let tempURL = tempURL, let errorData = try? Data(contentsOf: tempURL), let errorString = String(data: errorData, encoding: .utf8) {
                    print("伺服器錯誤訊息: \(errorString)")
                }
                
                completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "伺服器錯誤: \(httpResponse.statusCode)"])))
                return
            }
            
            guard let tempURL = tempURL else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "下載的臨時檔案位置無效"])))
                return
            }
            
            // 從臨時檔案讀取資料
            guard let data = try? Data(contentsOf: tempURL) else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法讀取下載的檔案"])))
                return
            }
            
            print("實際下載大小: \(data.count) bytes")
            
            guard !data.isEmpty else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "下載的數據為空"])))
                return
            }
            
            // 執行完整性檢查
            self?.performIntegrityCheck(data: data, expectedSize: expectedSize, retryCount: retryCount, fileName: fileName, completion: completion)
        }
        
        task.resume()
    }
    
    // 完整性檢查
    private func performIntegrityCheck(data: Data, expectedSize: Int64, retryCount: Int, fileName: String, completion: @escaping (Result<Data, Error>) -> Void) {
        if expectedSize > 0 && Int64(data.count) != expectedSize {
            print("警告: 檔案大小不符 - 預期: \(expectedSize), 實際: \(data.count)")
            
            if let csvString = String(data: data, encoding: .utf8) {
                let lines = csvString.components(separatedBy: .newlines)
                let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                
                print("總行數: \(lines.count), 非空行數: \(nonEmptyLines.count)")
                
                // 檢查最後幾行
                for (i, line) in lines.suffix(5).enumerated() {
                    let lineNumber = lines.count - 5 + i
                    print("第 \(lineNumber) 行: \(line)")
                }
                
                // 檔案完整性檢查
                let shouldRetry = retryCount > 0 && (
                    (lines.last?.isEmpty == false && !lines.last!.contains(",")) ||
                    (!csvString.hasSuffix("\n") && !csvString.hasSuffix("\r\n"))
                )
                
                if shouldRetry {
                    print("檔案可能不完整，準備重試...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.downloadCSVWithRetry(fileName: fileName, retryCount: retryCount - 1, completion: completion)
                    }
                    return
                }
            }
        }
        
        // 最終數據完整性檢查
        if let csvString = String(data: data, encoding: .utf8) {
            let lines = csvString.components(separatedBy: .newlines)
            let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            var integrityWarnings: [String] = []
            
            if nonEmptyLines.count < 2 {
                integrityWarnings.append("檔案只有 \(nonEmptyLines.count) 行資料，可能不完整")
            }
            
            if expectedSize > 0 && Int64(data.count) != expectedSize {
                let percentage = Double(data.count) * 100.0 / Double(expectedSize)
                integrityWarnings.append(String(format: "檔案大小只有預期的 %.1f%%", percentage))
            }
            
            if let lastLine = nonEmptyLines.last, !lastLine.isEmpty {
                let commaCount = lastLine.components(separatedBy: ",").count - 1
                if commaCount < 3 {
                    integrityWarnings.append("最後一行資料可能不完整")
                }
            }
            
            if let firstLine = nonEmptyLines.first {
                let expectedHeaders = ["序號", "棟別", "戶別", "條碼"]
                let hasValidHeader = expectedHeaders.contains { firstLine.contains($0) }
                if !hasValidHeader {
                    integrityWarnings.append("CSV 標題格式可能不正確")
                }
            }
            
            if !integrityWarnings.isEmpty {
                print("下載完整性警告：")
                integrityWarnings.forEach { print("- \($0)") }
                
                let warningInfo = ["warnings": integrityWarnings]
                NotificationCenter.default.post(
                    name: NSNotification.Name("DownloadIntegrityWarning"),
                    object: nil,
                    userInfo: warningInfo
                )
            }
        }
        
        completion(.success(data))
    }
    
    // 上傳 CSV 檔案
    func uploadCSV(fileURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        guard let url = getUploadURL() else {
            completion(false, NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無效的 URL"]))
            return
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        var data = Data()
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            data.append(fileData)
            data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            
            let task = optimizedSession.uploadTask(with: request, from: data) { (responseData, response, error) in
                if let error = error {
                    completion(false, error)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if let responseData = responseData, let responseString = String(data: responseData, encoding: .utf8) {
                        print("伺服器回應: \(responseString)")
                    }
                    
                    let success = (200...299).contains(httpResponse.statusCode)
                    if !success {
                        let error = NSError(domain: "", code: httpResponse.statusCode,
                                            userInfo: [NSLocalizedDescriptionKey: "伺服器回應非成功狀態碼: \(httpResponse.statusCode)"])
                        completion(false, error)
                    } else {
                        completion(true, nil)
                    }
                } else {
                    completion(false, NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法獲取HTTP回應"]))
                }
            }
            
            task.resume()
        } catch {
            completion(false, error)
        }
    }
    
    // 獲取檔案列表
    func fetchFileList(completion: @escaping (Result<[FileInfo], Error>) -> Void) {
        guard let url = getFileListURL() else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無效的URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 8.0
        
        let task = optimizedSession.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if !(200...299).contains(httpResponse.statusCode) {
                    completion(.failure(NSError(domain: "", code: httpResponse.statusCode,
                                               userInfo: [NSLocalizedDescriptionKey: "伺服器回應代碼: \(httpResponse.statusCode)"])))
                    return
                }
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "未接收到數據"])))
                return
            }
            
            if data.isEmpty {
                completion(.success([]))
                return
            }
            
            // 解析回應
            do {
                let response = try JSONDecoder().decode(ServerResponse.self, from: data)
                completion(.success(response.files))
            } catch {
                // 嘗試手動解析
                do {
                    if let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let filesArray = jsonDict["files"] as? [[String: Any]] {
                        
                        let fileInfos = filesArray.compactMap { fileDict -> FileInfo? in
                            guard let fileName = fileDict["fileName"] as? String,
                                  let size = fileDict["size"] as? Int,
                                  let uploadTime = fileDict["uploadTime"] as? String else {
                                return nil
                            }
                            
                            return FileInfo(fileName: fileName, size: size, uploadTime: uploadTime)
                        }
                        
                        completion(.success(fileInfos))
                    } else {
                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法識別的回應格式"])))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Helper Methods
    
    private func getBaseURL() -> String {
        let url = serverURL.hasSuffix("/") ? String(serverURL.dropLast()) : serverURL
        return url
    }
    
    func getUploadURL() -> URL? {
        return URL(string: "\(getBaseURL())/api/file/upload")
    }
    
    func getFileListURL() -> URL? {
        return URL(string: "\(getBaseURL())/api/file/list")
    }
    
    func getDownloadURL(fileName: String) -> URL? {
        guard let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "\(getBaseURL())/api/file/download?fileName=\(encodedFileName)")
    }
}