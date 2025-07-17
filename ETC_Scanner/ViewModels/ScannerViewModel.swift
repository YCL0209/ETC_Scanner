//
//  ScannerViewModel.swift
//  ETC_Scanner
//
//  Created by MVVM Architecture Implementation
//

import Foundation
import UIKit

// MARK: - ScannerViewModel Protocol
protocol ScannerViewModelDelegate: AnyObject {
    func viewModelDidUpdateItems()
    func viewModelDidUpdateStatus(_ status: String)
    func viewModelDidEncounterError(_ error: Error)
    func viewModelDidUpdateScanningState(_ isScanning: Bool)
}

// MARK: - ScannerViewModel
class ScannerViewModel {
    
    // MARK: - Properties
    weak var delegate: ScannerViewModelDelegate?
    
    // Data properties
    private(set) var scanItems: [ScanItem] = [] {
        didSet {
            delegate?.viewModelDidUpdateItems()
        }
    }
    
    private(set) var filteredItems: [ScanItem] = []
    private(set) var isSearching: Bool = false
    private(set) var selectedItemIndex: Int?
    
    // Status properties
    private(set) var isScanning: Bool = false {
        didSet {
            updateScanStatus()
            delegate?.viewModelDidUpdateScanningState(isScanning)
        }
    }
    
    private(set) var scanStatus: String = "待機中" {
        didSet {
            delegate?.viewModelDidUpdateStatus(scanStatus)
        }
    }
    
    // MARK: - Initialization
    init() {
        loadSavedItems()
    }
    
    // MARK: - Public Methods
    
    // Scanning Operations
    func startScanning() {
        isScanning = true
    }
    
    func stopScanning() {
        isScanning = false
    }
    
    func handleScanResult(_ code: String) {
        // 檢查重複
        if let duplicateIndex = checkForDuplicate(code: code) {
            handleDuplicateScan(at: duplicateIndex, code: code)
            return
        }
        
        // 創建新項目
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let newItem = ScanItem(
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
        
        scanItems.append(newItem)
        saveItems()
        
        // 播放提示音
        playSuccessSound()
    }
    
    // Selection Operations
    func selectItem(at index: Int, inSearchMode: Bool = false) {
        // 清除所有選擇
        clearAllSelections()
        
        if inSearchMode && index < filteredItems.count {
            // 在搜尋模式下
            let selectedItem = filteredItems[index]
            if let originalIndex = scanItems.firstIndex(where: { 
                $0.code == selectedItem.code && $0.time == selectedItem.time 
            }) {
                scanItems[originalIndex].isSelected = true
                filteredItems[index].isSelected = true
                selectedItemIndex = originalIndex
            }
        } else if index < scanItems.count {
            // 非搜尋模式
            scanItems[index].isSelected = true
            selectedItemIndex = index
        }
        
        delegate?.viewModelDidUpdateItems()
    }
    
    func toggleItemSelection(at index: Int, inSearchMode: Bool = false) {
        if inSearchMode && index < filteredItems.count {
            let item = filteredItems[index]
            if item.isSelected {
                deselectAll()
            } else {
                selectItem(at: index, inSearchMode: true)
            }
        } else if index < scanItems.count {
            if scanItems[index].isSelected {
                deselectAll()
            } else {
                selectItem(at: index, inSearchMode: false)
            }
        }
    }
    
    func deselectAll() {
        clearAllSelections()
        selectedItemIndex = nil
        delegate?.viewModelDidUpdateItems()
    }
    
    // Update Operations
    func updateItem(at index: Int, with details: ScanItemDetails) {
        guard index < scanItems.count else { return }
        
        scanItems[index].building = details.building
        scanItems[index].household = details.household
        scanItems[index].parkingNumber = details.parkingNumber
        scanItems[index].carType = details.carType
        scanItems[index].carNumber = details.carNumber
        scanItems[index].etagNumber = details.etagNumber
        scanItems[index].isEdited = true
        
        // 如果在搜尋模式，也更新過濾列表
        if isSearching {
            if let filteredIndex = filteredItems.firstIndex(where: { 
                $0.code == scanItems[index].code && $0.time == scanItems[index].time 
            }) {
                filteredItems[filteredIndex] = scanItems[index]
            }
        }
        
        saveItems()
        delegate?.viewModelDidUpdateItems()
    }
    
    // Delete Operations
    func deleteSelectedItems() {
        guard let selectedIndex = selectedItemIndex else { return }
        
        if selectedIndex < scanItems.count {
            scanItems.remove(at: selectedIndex)
            selectedItemIndex = nil
            
            // 如果在搜尋模式，更新過濾列表
            if isSearching {
                performSearch(with: searchQuery)
            }
            
            saveItems()
            delegate?.viewModelDidUpdateItems()
        }
    }
    
    func deleteAllItems() {
        scanItems.removeAll()
        filteredItems.removeAll()
        selectedItemIndex = nil
        saveItems()
        delegate?.viewModelDidUpdateItems()
    }
    
    // Search Operations
    private var searchQuery: String = ""
    
    func performSearch(with query: String) {
        searchQuery = query
        
        if query.isEmpty {
            isSearching = false
            filteredItems = []
        } else {
            isSearching = true
            let lowercasedQuery = query.lowercased()
            
            filteredItems = scanItems.filter { item in
                item.code.lowercased().contains(lowercasedQuery) ||
                (item.building?.lowercased().contains(lowercasedQuery) ?? false) ||
                (item.household?.lowercased().contains(lowercasedQuery) ?? false) ||
                (item.parkingNumber?.lowercased().contains(lowercasedQuery) ?? false) ||
                (item.carNumber?.lowercased().contains(lowercasedQuery) ?? false) ||
                (item.etagNumber?.lowercased().contains(lowercasedQuery) ?? false)
            }
        }
        
        delegate?.viewModelDidUpdateItems()
    }
    
    func clearSearch() {
        isSearching = false
        filteredItems = []
        searchQuery = ""
        delegate?.viewModelDidUpdateItems()
    }
    
    // Export Operations
    func getSelectedItemsForExport() -> [ScanItem] {
        return scanItems.filter { $0.isSelected }
    }
    
    func getAllItemsForExport() -> [ScanItem] {
        return scanItems
    }
    
    // MARK: - Private Methods
    
    private func updateScanStatus() {
        scanStatus = isScanning ? "掃描中..." : "待機中"
    }
    
    private func checkForDuplicate(code: String) -> Int? {
        return scanItems.firstIndex { $0.code == code && selectedItemIndex != scanItems.firstIndex(where: { $0.code == code }) }
    }
    
    private func handleDuplicateScan(at index: Int, code: String) {
        // 處理重複掃描邏輯
        scanItems[index].isSelected = true
        selectedItemIndex = index
        
        // 顯示錯誤提示
        delegate?.viewModelDidEncounterError(ScannerError.duplicateCode(code))
        
        // 播放錯誤音
        playErrorSound()
    }
    
    private func clearAllSelections() {
        for i in 0..<scanItems.count {
            scanItems[i].isSelected = false
        }
        for i in 0..<filteredItems.count {
            filteredItems[i].isSelected = false
        }
    }
    
    private func playSuccessSound() {
        // 播放成功提示音
        AudioServicesPlaySystemSound(1004)
    }
    
    private func playErrorSound() {
        // 播放錯誤提示音
        AudioServicesPlaySystemSound(1006)
    }
    
    // MARK: - Persistence
    
    private let userDefaultsKey = "scannedItems"
    
    private func saveItems() {
        // 簡單的 UserDefaults 儲存
        // 未來可以改為 Core Data 或其他持久化方案
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(scanItems) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadSavedItems() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let items = try? JSONDecoder().decode([ScanItem].self, from: data) else {
            return
        }
        scanItems = items
    }
}

// MARK: - Supporting Types

struct ScanItemDetails {
    let building: String?
    let household: String?
    let parkingNumber: String?
    let carType: String?
    let carNumber: String?
    let etagNumber: String?
}

enum ScannerError: LocalizedError {
    case duplicateCode(String)
    case invalidCode
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .duplicateCode(let code):
            return "條碼 \(code) 已經存在"
        case .invalidCode:
            return "無效的條碼格式"
        case .networkError(let message):
            return "網路錯誤：\(message)"
        }
    }
}