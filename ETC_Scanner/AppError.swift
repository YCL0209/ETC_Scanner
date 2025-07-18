//
//  AppError.swift
//  ETC_Scanner
//
//  Created by Error Handling Architecture Implementation
//  統一的錯誤處理機制
//

import Foundation
import UIKit

// MARK: - AppError
enum AppError: LocalizedError {
    // 網路相關錯誤
    case networkError(String)
    case networkTimeout
    case noInternetConnection
    case serverError(Int, String?)
    
    // 檔案相關錯誤
    case fileError(String)
    case fileNotFound(String)
    case fileSizeTooLarge(Int64, Int64) // actual, maximum
    case fileCorrupted(String)
    
    // 藍牙相關錯誤
    case bluetoothError(String)
    case bluetoothNotAvailable
    case bluetoothConnectionFailed(String)
    case bluetoothDeviceNotFound
    
    // 驗證相關錯誤
    case validationError(String)
    case invalidBarcode(String)
    case duplicateBarcode(String)
    case invalidFormat(String)
    
    // CSV相關錯誤
    case csvParsingError(String)
    case csvFormatError(String)
    case csvEmptyFile
    case csvTruncated(Int, Int) // expected rows, actual rows
    
    // 資料庫相關錯誤
    case storageError(String)
    case dataNotFound
    case dataCorrupted
    
    // 郵件相關錯誤
    case emailError(String)
    case emailNotConfigured
    case emailSendFailed(String)
    
    // 一般錯誤
    case unknown(String)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        // 網路錯誤
        case .networkError(let message):
            return "網路錯誤：\(message)"
        case .networkTimeout:
            return "網路連線逾時"
        case .noInternetConnection:
            return "無網路連線"
        case .serverError(let code, let message):
            return "伺服器錯誤 (\(code)): \(message ?? "未知錯誤")"
            
        // 檔案錯誤
        case .fileError(let message):
            return "檔案錯誤：\(message)"
        case .fileNotFound(let fileName):
            return "找不到檔案：\(fileName)"
        case .fileSizeTooLarge(let actual, let maximum):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let actualSize = formatter.string(fromByteCount: actual)
            let maxSize = formatter.string(fromByteCount: maximum)
            return "檔案太大（\(actualSize)），超過限制（\(maxSize)）"
        case .fileCorrupted(let fileName):
            return "檔案損壞：\(fileName)"
            
        // 藍牙錯誤
        case .bluetoothError(let message):
            return "藍牙錯誤：\(message)"
        case .bluetoothNotAvailable:
            return "藍牙功能不可用"
        case .bluetoothConnectionFailed(let device):
            return "無法連接到裝置：\(device)"
        case .bluetoothDeviceNotFound:
            return "找不到藍牙裝置"
            
        // 驗證錯誤
        case .validationError(let message):
            return "驗證錯誤：\(message)"
        case .invalidBarcode(let code):
            return "無效的條碼：\(code)"
        case .duplicateBarcode(let code):
            return "條碼重複：\(code)"
        case .invalidFormat(let format):
            return "格式錯誤：\(format)"
            
        // CSV錯誤
        case .csvParsingError(let message):
            return "CSV 解析錯誤：\(message)"
        case .csvFormatError(let message):
            return "CSV 格式錯誤：\(message)"
        case .csvEmptyFile:
            return "CSV 檔案為空"
        case .csvTruncated(let expected, let actual):
            return "CSV 檔案可能被截斷（預期 \(expected) 行，實際 \(actual) 行）"
            
        // 資料庫錯誤
        case .storageError(let message):
            return "儲存錯誤：\(message)"
        case .dataNotFound:
            return "找不到資料"
        case .dataCorrupted:
            return "資料損壞"
            
        // 郵件錯誤
        case .emailError(let message):
            return "郵件錯誤：\(message)"
        case .emailNotConfigured:
            return "郵件服務未設定"
        case .emailSendFailed(let reason):
            return "郵件發送失敗：\(reason)"
            
        // 一般錯誤
        case .unknown(let message):
            return "未知錯誤：\(message)"
        case .cancelled:
            return "操作已取消"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .noInternetConnection:
            return "請檢查您的網路連線"
        case .bluetoothNotAvailable:
            return "請在設定中開啟藍牙"
        case .emailNotConfigured:
            return "請在設定中配置郵件帳戶"
        case .csvEmptyFile:
            return "請選擇包含資料的 CSV 檔案"
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkTimeout:
            return "請稍後重試"
        case .fileSizeTooLarge:
            return "請使用較小的檔案或分批處理"
        case .csvTruncated:
            return "請重新下載完整的檔案"
        case .bluetoothConnectionFailed:
            return "請確認裝置已開啟並在範圍內"
        default:
            return nil
        }
    }
}

// MARK: - Error Handler Protocol
protocol ErrorHandlerProtocol {
    func handle(_ error: Error, in viewController: UIViewController)
    func handle(_ error: Error, completion: @escaping (Bool) -> Void)
}

// MARK: - Default Error Handler
class ErrorHandler: ErrorHandlerProtocol {
    
    static let shared = ErrorHandler()
    
    private init() {}
    
    func handle(_ error: Error, in viewController: UIViewController) {
        let appError = error as? AppError ?? AppError.unknown(error.localizedDescription)
        
        let alert = UIAlertController(
            title: "錯誤",
            message: appError.errorDescription,
            preferredStyle: .alert
        )
        
        // 添加失敗原因
        if let reason = appError.failureReason {
            alert.message = "\(appError.errorDescription ?? "")\n\n\(reason)"
        }
        
        // 添加恢復建議
        if let suggestion = appError.recoverySuggestion {
            alert.message = "\(alert.message ?? "")\n\n建議：\(suggestion)"
        }
        
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        
        // 某些錯誤可能需要重試選項
        switch appError {
        case .networkTimeout, .networkError, .bluetoothConnectionFailed:
            alert.addAction(UIAlertAction(title: "重試", style: .default) { _ in
                // 通知需要重試的操作
                NotificationCenter.default.post(name: .errorRetryRequested, object: error)
            })
        default:
            break
        }
        
        viewController.present(alert, animated: true)
    }
    
    func handle(_ error: Error, completion: @escaping (Bool) -> Void) {
        // 記錄錯誤
        print("❌ Error: \(error)")
        
        // 根據錯誤類型決定是否可以恢復
        let canRecover: Bool
        
        if let appError = error as? AppError {
            switch appError {
            case .cancelled:
                canRecover = true
            case .networkTimeout, .bluetoothConnectionFailed:
                canRecover = true
            default:
                canRecover = false
            }
        } else {
            canRecover = false
        }
        
        completion(canRecover)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let errorRetryRequested = Notification.Name("errorRetryRequested")
}

// MARK: - UIViewController Extension
extension UIViewController {
    func handleError(_ error: Error) {
        ErrorHandler.shared.handle(error, in: self)
    }
    
    func showError(_ message: String) {
        let error = AppError.unknown(message)
        handleError(error)
    }
}