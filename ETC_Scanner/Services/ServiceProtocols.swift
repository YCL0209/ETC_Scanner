//
//  ServiceProtocols.swift
//  ETC_Scanner
//
//  Created by Service Architecture Implementation
//  定義服務層的統一協議介面
//

import Foundation
import UIKit

// MARK: - Base Service Protocol
protocol ServiceProtocol {
    var serviceName: String { get }
    func initialize()
}

// MARK: - Network Service Protocol
protocol NetworkServiceProtocol: ServiceProtocol {
    func uploadFile(url: URL, completion: @escaping (Result<String, Error>) -> Void)
    func downloadFile(fileName: String, completion: @escaping (Result<Data, Error>) -> Void)
    func fetchFileList(completion: @escaping (Result<[FileInfo], Error>) -> Void)
}

// MARK: - Email Service Protocol
protocol EmailServiceProtocol: ServiceProtocol {
    func canSendEmail() -> Bool
    func sendEmail(to recipients: [String], subject: String, body: String, attachments: [Data]?, from viewController: UIViewController, completion: @escaping (Bool, String?) -> Void)
}

// MARK: - CSV Service Protocol
protocol CSVServiceProtocol: ServiceProtocol {
    func parseCSV(from url: URL, completion: @escaping (Result<[ScanItem], Error>) -> Void)
    func generateCSV(from items: [ScanItem], completion: @escaping (Result<URL, Error>) -> Void)
    func validateCSV(at url: URL) -> Bool
}

// MARK: - Bluetooth Service Protocol
protocol BluetoothServiceProtocol: ServiceProtocol {
    var isScanning: Bool { get }
    var isConnected: Bool { get }
    func startScanning()
    func stopScanning()
    func connectToDevice(_ deviceId: String)
    func disconnect()
}

// MARK: - Storage Service Protocol
protocol StorageServiceProtocol: ServiceProtocol {
    func save<T: Codable>(_ object: T, forKey key: String) -> Bool
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T?
    func delete(forKey key: String) -> Bool
    func clearAll() -> Bool
}

// MARK: - Service Error Types
enum ServiceError: LocalizedError {
    case initializationFailed(String)
    case networkError(String)
    case fileError(String)
    case bluetoothError(String)
    case storageError(String)
    case csvError(String)
    case emailError(String)
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "服務初始化失敗：\(message)"
        case .networkError(let message):
            return "網路錯誤：\(message)"
        case .fileError(let message):
            return "檔案錯誤：\(message)"
        case .bluetoothError(let message):
            return "藍牙錯誤：\(message)"
        case .storageError(let message):
            return "儲存錯誤：\(message)"
        case .csvError(let message):
            return "CSV 處理錯誤：\(message)"
        case .emailError(let message):
            return "郵件錯誤：\(message)"
        }
    }
}