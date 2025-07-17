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
    
    // MARK: - Import Actions
    @IBAction func importButtonTapped(_ sender: UIButton) {
        // 顯示選項
        let alert = UIAlertController(title: "匯入選項", message: "請選擇匯入方式", preferredStyle: .actionSheet)
        
        // 從檔案匯入
        alert.addAction(UIAlertAction(title: "從檔案匯入", style: .default) { [weak self] _ in
            self?.showFileImportPicker()
        })
        
        // 從伺服器下載
        alert.addAction(UIAlertAction(title: "從伺服器下載", style: .default) { [weak self] _ in
            self?.showServerFileList()
        })
        
        // 取消
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // iPad 適配
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - Export Actions
    @IBAction func exportButtonTapped(_ sender: UIButton) {
        let hasSelection = scannedItems.contains { $0.isSelected }
        
        let alert = UIAlertController(title: "匯出選項", message: "請選擇匯出方式", preferredStyle: .actionSheet)
        
        // 匯出所選
        if hasSelection {
            alert.addAction(UIAlertAction(title: "匯出所選項目", style: .default) { [weak self] _ in
                self?.exportSelectedItems()
            })
        }
        
        // 匯出全部
        alert.addAction(UIAlertAction(title: "匯出全部項目", style: .default) { [weak self] _ in
            self?.exportAllItems()
        })
        
        // 取消
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // iPad 適配
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - Delete Actions
    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        guard let selectedIndex = selectedItemIndex else {
            showAlert(title: "提示", message: "請先選擇要刪除的項目")
            return
        }
        
        // 確認刪除
        let item = scannedItems[selectedIndex]
        let alert = UIAlertController(
            title: "確認刪除",
            message: "確定要刪除條碼 \(item.code) 嗎？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "刪除", style: .destructive) { [weak self] _ in
            self?.deleteSelectedItem()
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - Search Actions
    @IBAction func searchButtonTapped(_ sender: UIButton) {
        if isSearching {
            // 結束搜尋
            endSearch()
        } else {
            // 開始搜尋
            showSearchDialog()
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func showFileImportPicker() {
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
    
    private func showServerFileList() {
        // 這裡將調用 NetworkManager 來獲取檔案列表
        // 暫時顯示提示
        showAlert(title: "功能開發中", message: "伺服器檔案列表功能即將推出")
    }
    
    private func exportSelectedItems() {
        let selectedItems = scannedItems.filter { $0.isSelected }
        exportItems(selectedItems, filename: "selected_items_\(Date().timeIntervalSince1970).csv")
    }
    
    private func exportAllItems() {
        exportItems(scannedItems, filename: "all_items_\(Date().timeIntervalSince1970).csv")
    }
    
    private func exportItems(_ items: [ScanItem], filename: String) {
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
    
    private func deleteSelectedItem() {
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
    
    private func showSearchDialog() {
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
    
    private func endSearch() {
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