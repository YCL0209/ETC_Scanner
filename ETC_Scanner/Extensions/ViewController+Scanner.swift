//
//  ViewController+Scanner.swift
//  ETC_Scanner
//
//  Created by ViewController Extension Implementation
//  處理掃描相關功能的擴展
//

import UIKit
import AudioToolbox

// MARK: - Scanner Functions
extension ViewController {
    
    // MARK: - Scanner Setup
    func setupScanner() {
        setupTextField()
        updateScannerStatus()
    }
    
    // MARK: - Scanner State Management
    func updateScannerStatus() {
        let status = isScanning ? "掃描中..." : "待機中"
        statusLabel?.text = status
        scanTextLabel?.text = isScanning ? "" : "等待掃描..."
    }
    
    // MARK: - Handle Scan Completion
    func handleScanCompletion(_ code: String) {
        guard !code.isEmpty else {
            resetScanner(complete: false)
            return
        }

        // 檢查重複
        if let duplicateIndex = checkForDuplicate(code: code) {
            handleDuplicateScan(at: duplicateIndex)
            return
        }

        // 創建新掃描項目
        let newItem = createScanItem(with: code)
        scannedItems.append(newItem)

        // 更新 UI
        tableView?.reloadData()

        // 播放成功音效
        AudioServicesPlaySystemSound(1004)

        // 重置掃描器
        resetScanner(complete: true)
    }
    
    // MARK: - Scanner Reset
    func resetScanner(complete: Bool) {
        // 清空輸入
        scannerTextField?.text = ""
        scanTextLabel?.text = complete ? "掃描完成" : "等待掃描..."
        
        // 延遲後顯示等待掃描
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.scanTextLabel?.text = "等待掃描..."
            self?.scannerTextField?.becomeFirstResponder()
        }
    }
    
    // MARK: - Private Helper Methods
    func checkForDuplicate(code: String) -> Int? {
        for (index, item) in scannedItems.enumerated() {
            if item.code == code && (selectedItemIndex == nil || selectedItemIndex != index) {
                return index
            }
        }
        return nil
    }
    
    func handleDuplicateScan(at index: Int) {
        // 清除所有選擇
        for i in 0..<scannedItems.count {
            scannedItems[i].isSelected = false
        }
        
        // 選中重複項目
        scannedItems[index].isSelected = true
        selectedItemIndex = index
        
        // 更新表格
        tableView?.reloadData()
        
        // 滾動到重複項目
        let indexPath = IndexPath(row: index, section: 0)
        tableView?.scrollToRow(at: indexPath, at: .middle, animated: true)
        
        // 播放錯誤音效
        AudioServicesPlaySystemSound(1006)
        
        // 顯示提示
        showDuplicateAlert(for: scannedItems[index].code)
        
        // 重置掃描器
        resetScanner(complete: false)
    }
    
    func createScanItem(with code: String) -> ScanItem {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        
        return ScanItem(
            code: code,
            time: timestamp,
            building: nil,
            household: nil,
            parkingNumber: nil,
            carType: nil,
            carNumber: nil,
            etagNumber: nil,
            isEdited: false,
            isSelected: false,
            owner: nil,
            tenant: nil,
            phone: nil
        )
    }
    
    func showDuplicateAlert(for code: String) {
        let alert = UIAlertController(
            title: "重複掃描",
            message: "條碼 \(code) 已經存在",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }
}