//
//  ViewController+Search.swift
//  ETC_Scanner
//
//  Created by ViewController Extension Implementation
//  處理搜尋功能的擴展
//

import UIKit

// MARK: - Search Properties and Methods
extension ViewController {
    
    // 如果 ViewController 中沒有這個屬性，需要添加
    var currentSearchQuery: String {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.searchQuery) as? String ?? ""
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.searchQuery, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // MARK: - Search Implementation
    func performSearch(with query: String) {
        currentSearchQuery = query
        
        if query.isEmpty {
            // 清空搜尋
            isSearching = false
            filteredItems = []
        } else {
            // 執行搜尋
            isSearching = true
            let lowercasedQuery = query.lowercased()
            
            filteredItems = scannedItems.filter { item in
                // 搜尋條碼
                if item.code.lowercased().contains(lowercasedQuery) {
                    return true
                }
                
                // 搜尋其他欄位
                let fieldsToSearch = [
                    item.building,
                    item.household,
                    item.parkingNumber,
                    item.carType,
                    item.carNumber,
                    item.etagNumber,
                    item.owner,
                    item.tenant,
                    item.phone
                ]
                
                return fieldsToSearch.compactMap { $0 }.contains { field in
                    field.lowercased().contains(lowercasedQuery)
                }
            }
        }
        
        // 更新 UI
        updateSearchButtonTitle()
        tableView?.reloadData()
        
        // 如果沒有搜尋結果，顯示提示
        if isSearching && filteredItems.isEmpty {
            showNoResultsMessage()
        }
    }
    
    // MARK: - Search UI Updates
    private func showNoResultsMessage() {
        let alert = UIAlertController(
            title: "搜尋結果",
            message: "找不到符合「\(currentSearchQuery)」的項目",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Clear Search
    func clearSearch() {
        isSearching = false
        filteredItems = []
        currentSearchQuery = ""
        updateSearchButtonTitle()
        tableView?.reloadData()
    }
}

// MARK: - Associated Keys
private struct AssociatedKeys {
    static var searchQuery = "searchQuery"
}