//
//  ViewController+TableView.swift
//  ETC_Scanner
//
//  Created by ViewController Extension Implementation
//  處理 TableView 相關功能的擴展
//

import UIKit

// MARK: - TableView Setup and Configuration
extension ViewController {
    
    // MARK: - Setup
    func setupTableViewDelegates() {
        tableView?.delegate = self
        tableView?.dataSource = self
        tableView?.allowsMultipleSelection = false
    }
    
    func configureTableViewAppearance() {
        guard let table = tableView else { return }
        
        // 設置表格外觀
        table.rowHeight = 110
        table.separatorStyle = .singleLine
        table.backgroundColor = .systemBackground
        
        // 註冊 cell
        if table.dequeueReusableCell(withIdentifier: "ScanItemCell") == nil {
            table.register(ScanItemCell.self, forCellReuseIdentifier: "ScanItemCell")
        }
    }
    
    // MARK: - Data Management
    func reloadTableData() {
        DispatchQueue.main.async { [weak self] in
            self?.tableView?.reloadData()
        }
    }
    
    func reloadTableRow(at index: Int) {
        let indexPath = IndexPath(row: index, section: 0)
        tableView?.reloadRows(at: [indexPath], with: .automatic)
    }
    
    // MARK: - Selection Management
    func updateTableSelection() {
        guard let table = tableView else { return }
        
        // 清除所有選擇
        if let indexPaths = table.indexPathsForSelectedRows {
            for indexPath in indexPaths {
                table.deselectRow(at: indexPath, animated: false)
            }
        }
        
        // 設置新的選擇
        let items = isSearching ? filteredItems : scannedItems
        for (index, item) in items.enumerated() {
            if item.isSelected {
                let indexPath = IndexPath(row: index, section: 0)
                table.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        }
    }
    
    // MARK: - Cell Configuration
    func configureCell(_ cell: ScanItemCell, with item: ScanItem, at indexPath: IndexPath) {
        // 準備重用
        cell.prepareForReuse()
        
        // 配置 cell
        cell.configure(with: item)
        cell.selectionStyle = .default
        
        // 設定選擇狀態
        if item.isSelected {
            cell.setSelected(true, animated: false)
            tableView?.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        } else {
            cell.setSelected(false, animated: false)
            tableView?.deselectRow(at: indexPath, animated: false)
        }
        
        // 設置編輯按鈕回調
        cell.onEditButtonTapped = { [weak self] in
            self?.handleEditButtonTapped(for: item, at: indexPath)
        }
    }
    
    // MARK: - Actions
    func handleEditButtonTapped(for item: ScanItem, at indexPath: IndexPath) {
        let originalIndex: Int
        
        if isSearching {
            // 找到原始數據中的索引
            if let index = scannedItems.firstIndex(where: { $0.code == item.code && $0.time == item.time }) {
                originalIndex = index
            } else {
                return
            }
        } else {
            originalIndex = indexPath.row
        }
        
        // 延遲顯示編輯視圖，確保 UI 更新完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.showEditViewController(for: originalIndex)
        }
    }
    
    // MARK: - Scrolling
    func scrollToItem(at index: Int, animated: Bool = true) {
        let indexPath = IndexPath(row: index, section: 0)
        tableView?.scrollToRow(at: indexPath, at: .middle, animated: animated)
    }
    
    func scrollToTop(animated: Bool = true) {
        guard let table = tableView, table.numberOfRows(inSection: 0) > 0 else { return }
        let indexPath = IndexPath(row: 0, section: 0)
        table.scrollToRow(at: indexPath, at: .top, animated: animated)
    }
    
    func scrollToBottom(animated: Bool = true) {
        guard let table = tableView else { return }
        let rowCount = table.numberOfRows(inSection: 0)
        guard rowCount > 0 else { return }
        
        let indexPath = IndexPath(row: rowCount - 1, section: 0)
        table.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }
}