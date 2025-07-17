//
//  DownloadManager.swift
//  ETC_Scanner
//
//  Created on 2025/07/17.
//  專門處理檔案下載的管理器，使用 URLSessionDownloadDelegate 提供更好的進度追蹤和穩定性
//

import Foundation
import UIKit

// MARK: - Download Progress Protocol
protocol DownloadManagerDelegate: AnyObject {
    func downloadDidUpdateProgress(_ progress: Float)
    func downloadDidComplete(with data: Data?, error: Error?)
    func downloadDidReceiveWarnings(_ warnings: [String])
}

// MARK: - DownloadManager
class DownloadManager: NSObject {
    
    // MARK: - Properties
    
    weak var delegate: DownloadManagerDelegate?
    private var downloadTask: URLSessionDownloadTask?
    private var backgroundSession: URLSession!
    private var expectedContentLength: Int64 = 0
    private var downloadedBytes: Int64 = 0
    private var retryCount = 0
    private var maxRetryCount = 3
    private var currentFileName: String?
    private var downloadStartTime: Date?
    
    // Download completion handler
    private var completionHandler: ((Result<Data, Error>) -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        configureBackgroundSession()
    }
    
    // Configure background URLSession
    private func configureBackgroundSession() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.etcscanner.download")
        
        // 優化設定
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        
        // 超時設定
        config.timeoutIntervalForRequest = 300 // 5 分鐘
        config.timeoutIntervalForResource = 600 // 10 分鐘
        
        // 網路設定
        config.httpMaximumConnectionsPerHost = 2
        config.httpShouldUsePipelining = true
        config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.networkServiceType = .background
        
        // 建立 session
        backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - Public Methods
    
    /// 下載 CSV 檔案
    /// - Parameters:
    ///   - fileName: 要下載的檔案名稱
    ///   - completion: 完成回調
    func downloadCSV(fileName: String, completion: @escaping (Result<Data, Error>) -> Void) {
        // 重置狀態
        retryCount = 0
        currentFileName = fileName
        completionHandler = completion
        downloadStartTime = Date()
        
        // 開始下載
        startDownload(fileName: fileName)
    }
    
    /// 取消當前下載
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        completionHandler = nil
        delegate?.downloadDidComplete(with: nil, error: NSError(domain: "", code: -999, userInfo: [NSLocalizedDescriptionKey: "下載已取消"]))
    }
    
    /// 暫停下載
    func pauseDownload() {
        downloadTask?.suspend()
    }
    
    /// 恢復下載
    func resumeDownload() {
        downloadTask?.resume()
    }
    
    // MARK: - Private Methods
    
    private func startDownload(fileName: String) {
        guard let url = NetworkManager.shared.getDownloadURL(fileName: fileName) else {
            let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無效的下載 URL"])
            completionHandler?(.failure(error))
            delegate?.downloadDidComplete(with: nil, error: error)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue(NetworkManager.shared.apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 120.0
        
        // 取消之前的任務
        downloadTask?.cancel()
        
        // 建立新的下載任務
        downloadTask = backgroundSession.downloadTask(with: request)
        downloadTask?.resume()
        
        print("[DownloadManager] 開始下載: \(fileName)")
    }
    
    // 重試下載
    private func retryDownload() {
        guard let fileName = currentFileName, retryCount < maxRetryCount else {
            let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "已達最大重試次數"])
            completionHandler?(.failure(error))
            delegate?.downloadDidComplete(with: nil, error: error)
            return
        }
        
        retryCount += 1
        print("[DownloadManager] 重試下載 (\(retryCount)/\(maxRetryCount)): \(fileName)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.startDownload(fileName: fileName)
        }
    }
    
    // 執行資料完整性檢查
    private func performIntegrityCheck(data: Data) -> [String] {
        var warnings: [String] = []
        
        guard let csvString = String(data: data, encoding: .utf8) else {
            warnings.append("無法解析 CSV 資料")
            return warnings
        }
        
        let lines = csvString.components(separatedBy: .newlines)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // 基本檢查
        if nonEmptyLines.count < 2 {
            warnings.append("檔案只有 \(nonEmptyLines.count) 行資料，可能不完整")
        }
        
        // 檢查檔案大小
        if expectedContentLength > 0 && Int64(data.count) != expectedContentLength {
            let percentage = Double(data.count) * 100.0 / Double(expectedContentLength)
            warnings.append(String(format: "檔案大小只有預期的 %.1f%%", percentage))
        }
        
        // 檢查最後一行
        if let lastLine = nonEmptyLines.last, !lastLine.isEmpty {
            let commaCount = lastLine.components(separatedBy: ",").count - 1
            if commaCount < 3 {
                warnings.append("最後一行資料可能不完整（只有 \(commaCount) 個欄位）")
            }
        }
        
        // 檢查 CSV 標題
        if let firstLine = nonEmptyLines.first {
            let expectedHeaders = ["序號", "棟別", "戶別", "條碼"]
            let hasValidHeader = expectedHeaders.contains { firstLine.contains($0) }
            if !hasValidHeader {
                warnings.append("CSV 標題格式可能不正確")
            }
        }
        
        // 檢查是否需要重試
        let shouldRetry = retryCount < maxRetryCount && (
            (lines.last?.isEmpty == false && !lines.last!.contains(",")) ||
            (!csvString.hasSuffix("\n") && !csvString.hasSuffix("\r\n"))
        )
        
        if shouldRetry {
            warnings.append("檔案結尾可能被截斷，將自動重試")
        }
        
        return warnings
    }
}

// MARK: - URLSessionDownloadDelegate
extension DownloadManager: URLSessionDownloadDelegate {
    
    // 下載完成
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("[DownloadManager] 下載完成，臨時檔案位置: \(location)")
        
        // 計算下載時間
        if let startTime = downloadStartTime {
            let duration = Date().timeIntervalSince(startTime)
            print("[DownloadManager] 下載耗時: \(duration) 秒")
        }
        
        // 讀取下載的資料
        do {
            let data = try Data(contentsOf: location)
            print("[DownloadManager] 實際下載大小: \(data.count) bytes")
            
            // 執行完整性檢查
            let warnings = performIntegrityCheck(data: data)
            
            if !warnings.isEmpty {
                print("[DownloadManager] 完整性警告:")
                warnings.forEach { print("- \($0)") }
                
                // 通知代理
                delegate?.downloadDidReceiveWarnings(warnings)
                
                // 檢查是否需要重試
                if warnings.contains(where: { $0.contains("將自動重試") }) {
                    retryDownload()
                    return
                }
            }
            
            // 成功完成
            completionHandler?(.success(data))
            delegate?.downloadDidComplete(with: data, error: nil)
            
        } catch {
            print("[DownloadManager] 讀取下載檔案失敗: \(error)")
            
            // 重試或失敗
            if retryCount < maxRetryCount {
                retryDownload()
            } else {
                completionHandler?(.failure(error))
                delegate?.downloadDidComplete(with: nil, error: error)
            }
        }
    }
    
    // 下載進度更新
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        downloadedBytes = totalBytesWritten
        expectedContentLength = totalBytesExpectedToWrite
        
        if totalBytesExpectedToWrite > 0 {
            let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            print("[DownloadManager] 下載進度: \(Int(progress * 100))%")
            
            // 通知代理更新進度
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.downloadDidUpdateProgress(progress)
            }
        }
    }
}

// MARK: - URLSessionTaskDelegate
extension DownloadManager: URLSessionTaskDelegate {
    
    // 任務完成（成功或失敗）
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("[DownloadManager] 下載任務失敗: \(error)")
            
            // 檢查是否為取消操作
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                return // 已經在 cancelDownload 中處理
            }
            
            // 嘗試重試
            if retryCount < maxRetryCount {
                retryDownload()
            } else {
                completionHandler?(.failure(error))
                delegate?.downloadDidComplete(with: nil, error: error)
            }
        }
    }
    
    // 處理伺服器回應
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }
        
        print("[DownloadManager] 收到伺服器回應: \(httpResponse.statusCode)")
        expectedContentLength = httpResponse.expectedContentLength
        print("[DownloadManager] 預期檔案大小: \(expectedContentLength) bytes")
        
        if (200...299).contains(httpResponse.statusCode) {
            completionHandler(.allow)
        } else {
            completionHandler(.cancel)
            
            let error = NSError(domain: "", code: httpResponse.statusCode, 
                               userInfo: [NSLocalizedDescriptionKey: "伺服器錯誤: \(httpResponse.statusCode)"])
            self.completionHandler?(.failure(error))
            self.delegate?.downloadDidComplete(with: nil, error: error)
        }
    }
}

// MARK: - URLSessionDelegate
extension DownloadManager: URLSessionDelegate {
    
    // 背景下載完成
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("[DownloadManager] 背景下載事件完成")
        
        // 如果需要背景任務完成處理，可以在這裡添加
        DispatchQueue.main.async {
            // 背景任務完成後的處理
            print("[DownloadManager] 背景任務已完成")
        }
    }
}