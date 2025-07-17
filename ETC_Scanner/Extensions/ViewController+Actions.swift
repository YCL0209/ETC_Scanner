//
//  ViewController+Actions.swift
//  ETC_Scanner
//
//  Created by ViewController Extension Implementation
//  處理按鈕動作和使用者互動的擴展
//

import UIKit
import UniformTypeIdentifiers

// MARK: - Button Actions
extension ViewController {
    
    // MARK: - Import Actions Helper Methods
    
    // MARK: - Export Actions Helper Methods
    
    // MARK: - Delete Actions Helper Methods
    
    // MARK: - Search Actions Helper Methods
    
    // MARK: - Helper Methods
    
    func showFileImportPicker() {
        let documentPicker: UIDocumentPickerViewController
        
        if #available(iOS 14.0, *) {
            let csvType = UTType(filenameExtension: "csv") ?? .commaSeparatedText
            documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [csvType])
        } else {
            documentPicker = UIDocumentPickerViewController(documentTypes: ["public.comma-separated-values-text"], in: .import)
        }
        
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
    }
    
    func showServerFileList() {
        // 這裡將調用 NetworkManager 來獲取檔案列表
        // 暫時顯示提示
        showAlert(title: "功能開發中", message: "伺服器檔案列表功能即將推出")
    }
    
    func exportSelectedItems() {
        let selectedItems = scannedItems.filter { $0.isSelected }
        exportItems(selectedItems, filename: "selected_items_\(Date().timeIntervalSince1970).csv")
    }
    
    func exportAllItems() {
        exportItems(scannedItems, filename: "all_items_\(Date().timeIntervalSince1970).csv")
    }
    
    func exportItems(_ items: [ScanItem], filename: String) {
        // 使用 EmailManager 或其他方式匯出
        DependencyContainer.shared.emailService.showSendEmailDialog(
            on: self,
            selectedItems: items
        ) { [weak self] success, error in
            if success {
                self?.showAlert(title: "成功", message: "檔案已準備完成")
            } else {
                self?.showAlert(title: "錯誤", message: error ?? "匯出失敗")
            }
        }
    }
    
    func deleteSelectedItem() {
        guard let index = selectedItemIndex else { return }
        
        // 刪除項目
        scannedItems.remove(at: index)
        selectedItemIndex = nil
        
        // 如果在搜尋模式，更新過濾列表
        if isSearching {
            performSearch(with: currentSearchQuery)
        }
        
        // 更新 UI
        tableView?.reloadData()
        updateButtonStates()
        
        // 顯示成功提示
        showAlert(title: "成功", message: "項目已刪除")
    }
    
    func showSearchDialog() {
        let alert = UIAlertController(title: "搜尋", message: "請輸入搜尋關鍵字", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "條碼、棟別、戶別..."
            textField.text = self.currentSearchQuery
        }
        
        alert.addAction(UIAlertAction(title: "搜尋", style: .default) { [weak self] _ in
            if let query = alert.textFields?.first?.text, !query.isEmpty {
                self?.performSearch(with: query)
            }
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func endSearch() {
        isSearching = false
        filteredItems = []
        currentSearchQuery = ""
        updateSearchButtonTitle()
        tableView?.reloadData()
    }
    
    // MARK: - UI Updates
    func updateButtonStates() {
        let hasSelection = selectedItemIndex != nil
        let hasItems = !scannedItems.isEmpty
        
        exportButton?.isEnabled = hasItems
        deleteButton?.isEnabled = hasSelection
        
        // 更新按鈕外觀
        exportButton?.alpha = hasItems ? 1.0 : 0.5
        deleteButton?.alpha = hasSelection ? 1.0 : 0.5
    }
    
    func updateSearchButtonTitle() {
        let title = isSearching ? "結束搜尋" : "搜尋"
        searchButton?.setTitle(title, for: .normal)
    }
    
    // MARK: - Alerts
    func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}