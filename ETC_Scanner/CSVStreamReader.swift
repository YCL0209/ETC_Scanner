//
//  CSVStreamReader.swift
//  ETC_Scanner
//
//  Created on 2025/07/17.
//  CSV 串流讀取器，用於高效讀取大型 CSV 檔案
//

import Foundation

/// CSV 串流讀取器，避免一次性載入整個檔案到記憶體
class CSVStreamReader {
    private let fileHandle: FileHandle
    private let bufferSize: Int
    private var buffer = Data()
    private let delimiter = "\n".data(using: .utf8)!
    private let encoding: String.Encoding
    private var isAtEnd = false
    
    /// 初始化 CSV 串流讀取器
    /// - Parameters:
    ///   - url: CSV 檔案的 URL
    ///   - bufferSize: 緩衝區大小，預設 4KB
    ///   - encoding: 文字編碼，預設 UTF-8
    init?(url: URL, bufferSize: Int = 4096, encoding: String.Encoding = .utf8) {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        self.fileHandle = handle
        self.bufferSize = bufferSize
        self.encoding = encoding
    }
    
    /// 讀取下一行
    /// - Returns: 讀取到的行內容，如果到達檔案結尾則返回 nil
    func readLine() -> String? {
        while !isAtEnd {
            // 1. 檢查緩衝區是否有完整的一行
            if let range = buffer.range(of: delimiter) {
                let lineData = buffer.subdata(in: 0..<range.lowerBound)
                buffer.removeSubrange(0..<range.upperBound)
                
                // 轉換為字串並返回
                if let line = String(data: lineData, encoding: encoding) {
                    return line
                }
            }
            
            // 2. 如果沒有完整的行，從檔案讀取更多資料
            let chunk = fileHandle.readData(ofLength: bufferSize)
            
            if chunk.isEmpty {
                // 檔案結束
                isAtEnd = true
                
                // 如果緩衝區還有資料，返回最後一行
                if !buffer.isEmpty {
                    defer { buffer.removeAll() }
                    return String(data: buffer, encoding: encoding)
                }
                
                return nil
            }
            
            // 3. 將新資料加入緩衝區
            buffer.append(chunk)
        }
        
        return nil
    }
    
    /// 讀取所有剩餘的行
    /// - Returns: 剩餘的所有行
    func readAllLines() -> [String] {
        var lines: [String] = []
        
        while let line = readLine() {
            lines.append(line)
        }
        
        return lines
    }
    
    /// 跳過指定數量的行
    /// - Parameter count: 要跳過的行數
    func skipLines(_ count: Int) {
        for _ in 0..<count {
            guard readLine() != nil else { break }
        }
    }
    
    /// 重置讀取位置到檔案開頭
    func reset() {
        fileHandle.seek(toFileOffset: 0)
        buffer.removeAll()
        isAtEnd = false
    }
    
    /// 關閉檔案
    func close() {
        fileHandle.closeFile()
    }
    
    deinit {
        close()
    }
}

// MARK: - CSV 解析輔助擴展
extension CSVStreamReader {
    
    /// 解析 CSV 行為欄位陣列
    /// - Parameter line: CSV 行
    /// - Returns: 解析後的欄位陣列
    static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var previousChar: Character?
        
        for char in line {
            if char == "\"" {
                if insideQuotes && previousChar == "\"" {
                    // 雙引號轉義
                    currentField.append(char)
                    previousChar = nil
                    continue
                } else {
                    insideQuotes = !insideQuotes
                }
            } else if char == "," && !insideQuotes {
                // 欄位分隔符
                fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
                currentField = ""
            } else {
                currentField.append(char)
            }
            
            previousChar = char
        }
        
        // 添加最後一個欄位
        fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
        
        return fields
    }
}

// MARK: - 使用範例
extension CSVStreamReader {
    
    /// 串流處理 CSV 檔案的範例方法
    /// - Parameters:
    ///   - url: CSV 檔案 URL
    ///   - batchSize: 批次處理大小
    ///   - processHandler: 處理每批資料的閉包
    static func processCSVInBatches(
        url: URL,
        batchSize: Int = 100,
        processHandler: @escaping ([ScanItem]) -> Void
    ) {
        guard let reader = CSVStreamReader(url: url) else {
            print("無法開啟 CSV 檔案")
            return
        }
        
        // 跳過標題行
        _ = reader.readLine()
        
        var batch: [ScanItem] = []
        var lineNumber = 1
        
        while let line = reader.readLine() {
            lineNumber += 1
            
            autoreleasepool {
                let columns = parseCSVLine(line)
                
                // 確保至少有必要的欄位
                if columns.count >= 1 && !columns[0].isEmpty {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
                    let timeString = dateFormatter.string(from: Date())
                    
                    let item = ScanItem(
                        code: columns[0],
                        time: timeString,
                        building: columns.count > 1 ? columns[1] : nil,
                        household: columns.count > 2 ? columns[2] : nil,
                        parkingNumber: columns.count > 6 ? columns[6] : nil,
                        carType: columns.count > 7 ? columns[7] : nil,
                        carNumber: columns.count > 8 ? columns[8] : nil,
                        etagNumber: columns.count > 9 ? columns[9] : nil,
                        isEdited: columns.count > 9 && !columns[9].isEmpty,
                        isSelected: false,
                        owner: columns.count > 3 ? columns[3] : nil,
                        tenant: columns.count > 4 ? columns[4] : nil,
                        phone: columns.count > 5 ? columns[5] : nil
                    )
                    
                    batch.append(item)
                    
                    // 達到批次大小時處理
                    if batch.count >= batchSize {
                        processHandler(batch)
                        batch.removeAll(keepingCapacity: true)
                    }
                }
            }
        }
        
        // 處理剩餘的資料
        if !batch.isEmpty {
            processHandler(batch)
        }
        
        reader.close()
    }
}