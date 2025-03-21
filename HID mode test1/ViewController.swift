//
//  ViewController.swift
//  HID mode test1
//
//  Created by 廖亞丞 on 2025/2/16.
//

import UIKit
import CoreBluetooth


  // MARK: - Properties
struct ScanItem {
        let code: String
        let time: String
        var carNumber: String?
        var residentNumber: String?    // 新增
        var parkingCount: String?      // 新增
        var isEdited: Bool   
        var isSelected: Bool
    }
    
class ViewController: UIViewController{
    
    // MARK: - IBOutlets
    @IBOutlet weak var titleLabel: UILabel!      // 新增標題 Label
    @IBOutlet weak var statusLabel: UILabel!     // 新增狀態 Label
    @IBOutlet weak var tableView: UITableView!   // 掃描記錄表格
    @IBOutlet weak var inputTitleLabel: UILabel!     // 新增 "當前輸入:" 標籤
    @IBOutlet weak var scanningLabel: UILabel!       // 新增 "等待掃描..." 標籤
    @IBOutlet weak var allButton: UIButton!          // 全選按鈕
    @IBOutlet weak var exportButton: UIButton!       // 匯出所選按鈕
    @IBOutlet weak var deleteButton: UIButton!       // 刪除所選按鈕

    private var scannerTextField: UITextField!
     
   
    var scannedItems: [ScanItem] = [] {
        didSet {
            updateButtonStates()
        }
    }
    
    private var isScanning = false {
        didSet {
            updateStatusLabel()
        }
    }
   
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

         // 設定只能直向顯示
        AppDelegate.AppUtility.lockOrientation(.portrait)
        
        // 強制使用淺色模式（白天模式）
        overrideUserInterfaceStyle = .light
 
        print("viewDidLoad 開始") 

        // 檢查 TableView 是否正確連接
        if let tableView = self.tableView {
            print("TableView 已連接")
        } else {
            print("錯誤：TableView 未連接")
        }

        setupUI()
        setupTableView()
        setupTextField()
        // 設置隱藏的輸入視圖（這樣不會顯示鍵盤，但仍可接收 HID 輸入）
        let hiddenInputView = UIView(frame: .zero)
        hiddenInputView.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        scannerTextField.inputView = hiddenInputView

        print("viewDidLoad 完成")
    }
    // 在 class ViewController 內，其他方法的同層級添加這兩個方法
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 確保方向鎖定在直向
        AppDelegate.AppUtility.lockOrientation(.portrait)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 離開頁面時解除方向鎖定
        AppDelegate.AppUtility.lockOrientation(.all)
    }

    // MARK: - Setup
    private func setupUI() {
        // 設置標題
        titleLabel.text = "RFID 標籤收集器"
        titleLabel.font = .systemFont(ofSize: 20, weight: .medium)
        
        // 設置狀態標籤
        statusLabel.text = "待機中"
        statusLabel.textColor = .systemGray
        statusLabel.font = .systemFont(ofSize: 14)
        
        // 設置輸入區域
        inputTitleLabel.text = "當前輸入:"
        inputTitleLabel.font = .systemFont(ofSize: 14)
        
        // 設置掃描狀態標籤
        scanningLabel.text = "等待掃描..."
        scanningLabel.font = .systemFont(ofSize: 14)
        scanningLabel.textColor = .systemGray
        scanningLabel.backgroundColor = .systemGray6
        scanningLabel.layer.cornerRadius = 5
        scanningLabel.clipsToBounds = true
        
        // 設置寬度約束（可以在 Storyboard 中設置）
    if let widthConstraint = scanningLabel.constraints.first(where: { $0.firstAttribute == .width }) {
        widthConstraint.constant = 300 // 調整為您需要的寬度
    }

    // 設置內邊距
    let padding = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
    scanningLabel.layoutMargins = padding

        // 設置按鈕
        setupButtons()
    }
    
    private func setupButtons() {
        // 全選按鈕
        allButton.setTitle("全選", for: .normal)
        allButton.backgroundColor = .white
        allButton.layer.borderWidth = 1
        allButton.layer.borderColor = UIColor.systemGray4.cgColor
        allButton.layer.cornerRadius = 5
        
        // 匯出按鈕
        exportButton.setTitle("匯出所選 (0)", for: .normal)
        exportButton.backgroundColor = .systemBlue
        exportButton.setTitleColor(.white, for: .normal)
        exportButton.layer.cornerRadius = 5
        
        // 刪除按鈕
        deleteButton.setTitle("刪除所選 (0)", for: .normal)
        deleteButton.backgroundColor = .systemRed
        deleteButton.setTitleColor(.white, for: .normal)
        deleteButton.layer.cornerRadius = 5
        
        updateButtonStates()
    }

    private func setupTableView() {
    print("開始設置 TableView")
    
    tableView.delegate = self
    tableView.dataSource = self
    
    // 重要：註冊自定義 Cell
    tableView.register(ScanItemCell.self, forCellReuseIdentifier: ScanItemCell.identifier)
    
    tableView.rowHeight = 110
    tableView.backgroundColor = .white
    tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    
    // 確保 TableView 可見
    tableView.isHidden = false
    tableView.alpha = 1.0
    
    print("TableView 設置完成")
}

    private func setupTextField() {
        scannerTextField = UITextField()
        scannerTextField.delegate = self
        // 防止鍵盤彈出
        scannerTextField.isHidden = true
        view.addSubview(scannerTextField)
        scannerTextField.becomeFirstResponder()
    }

    private func ensureTextFieldIsFocused() {
    if !scannerTextField.isFirstResponder {
        scannerTextField.becomeFirstResponder()
       }
    }

    private func updateStatusLabel() {
        statusLabel.text = isScanning ? "讀取中" : "待機中"
        statusLabel.textColor = isScanning ? .systemGreen : .systemGray
    }

    private func updateButtonStates() {
        let selectedCount = scannedItems.filter { $0.isSelected }.count
        exportButton.setTitle("匯出所選 (\(selectedCount))", for: .normal)
        deleteButton.setTitle("刪除所選 (\(selectedCount))", for: .normal)
        
        let isAllSelected = !scannedItems.isEmpty && scannedItems.allSatisfy { $0.isSelected }
        allButton.setTitle(isAllSelected ? "取消全選" : "全選", for: .normal)
    }

    // MARK: - Actions
    @IBAction func allButtonTapped(_ sender: UIButton) {
        let shouldSelectAll = !scannedItems.allSatisfy { $0.isSelected }
        scannedItems = scannedItems.map { item in
            var newItem = item
            newItem.isSelected = shouldSelectAll
            return newItem
        }
        tableView.reloadData()
    }

     @IBAction func exportButtonTapped(_ sender: UIButton) {
        let selectedItems = scannedItems.filter { $0.isSelected }
        let exportText = selectedItems.map { "條碼: \($0.code), 車牌: \($0.carNumber ?? "未設置"), 時間: \($0.time)" }
            .joined(separator: "\n")
        
        let activityVC = UIActivityViewController(activityItems: [exportText], applicationActivities: nil)
        present(activityVC, animated: true)
    }

    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "確認刪除",
                                    message: "確定要刪除所選項目嗎？",
                                    preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "刪除", style: .destructive) { [weak self] _ in
            self?.deleteSelectedItems()
        })
        
        present(alert, animated: true)
    }

     private func deleteSelectedItems() {
        scannedItems = scannedItems.filter { !$0.isSelected }
        tableView.reloadData()
    }

   @objc private func editCarNumber(_ sender: UIButton) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    if let editVC = storyboard.instantiateViewController(withIdentifier: "EditDetailViewController") as? EditDetailViewController {
        let index = sender.tag
        let item = scannedItems[index]
        
        // 傳遞現有的資料到編輯視圖
        editVC.currentCarNumber = item.carNumber ?? ""
        editVC.currentResidentNumber = item.residentNumber ?? ""
        editVC.currentParkingCount = item.parkingCount ?? ""
        editVC.itemIndex = index
        editVC.delegate = self
        editVC.modalPresentationStyle = .fullScreen
        present(editVC, animated: true)
        }
    }
}

// MARK: - EditDetailViewControllerDelegate
extension ViewController: EditDetailViewControllerDelegate {
    func didUpdateDetails(carNumber: String, residentNumber: String, parkingCount: String, at index: Int) {
        var updatedItem = scannedItems[index]
        updatedItem.carNumber = carNumber
        updatedItem.residentNumber = residentNumber
        updatedItem.parkingCount = parkingCount
        updatedItem.isEdited = true
        scannedItems[index] = updatedItem
        
        let indexPath = IndexPath(row: index, section: 0)
        tableView.reloadRows(at: [indexPath], with: .automatic)
        
        // 確保編輯完成後 TextField 重新獲得焦點
        DispatchQueue.main.async { [weak self] in
            self?.ensureTextFieldIsFocused()
        }
    }
}

// MARK: - UITableViewDataSource
extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = scannedItems.count
        print("TableView 請求資料數量: \(count)")
        return count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("準備設置 Cell，row: \(indexPath.row)")
         guard let cell = tableView.dequeueReusableCell(withIdentifier: "ScanItemCell", for: indexPath) as? ScanItemCell else {
            print("錯誤：無法建立 Cell")
            return UITableViewCell()
        }
        
        let item = scannedItems[indexPath.row]
        cell.configure(with: item)
        print("完成設置 Cell，條碼: \(item.code)")
        // 設置編輯按鈕的動作
    cell.onEditButtonTapped = { [weak self] in
        guard let self = self else { return }
        
        // 創建並顯示編輯視圖控制器
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let editVC = storyboard.instantiateViewController(withIdentifier: "EditDetailViewController") as? EditDetailViewController {
            editVC.delegate = self
            editVC.itemIndex = indexPath.row
            editVC.currentCarNumber = item.carNumber ?? ""
            editVC.currentResidentNumber = item.residentNumber ?? ""
            editVC.currentParkingCount = item.parkingCount ?? ""
            
            // 以模態方式顯示編輯視圖
            editVC.modalPresentationStyle = .formSheet
            self.present(editVC, animated: true)
          }
       }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 110
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var item = scannedItems[indexPath.row]
        item.isSelected.toggle()
        scannedItems[indexPath.row] = item
        tableView.reloadRows(at: [indexPath], with: .none)
    }
}

// MARK: - UITextFieldDelegate
extension ViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // 更新掃描標籤
        if !string.isEmpty {
            scanningLabel.text = (textField.text ?? "") + string
        }
        
        // 當收到換行符號時
        if string == "\n" || string == "\r" {
            // 取得完整的掃描碼
            if let barcode = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !barcode.isEmpty {
                print("掃描到條碼: \(barcode)") // 除錯用
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
                let timeString = dateFormatter.string(from: Date())
                
                let newItem = ScanItem(
                    code: barcode,
                    time: timeString,
                    carNumber: nil,
                    residentNumber: nil,
                    parkingCount: nil,
                    isEdited: false,
                    isSelected: false
                )
                
                // 新增到資料陣列
                scannedItems.insert(newItem, at: 0)
                print("新增項目，目前總數: \(scannedItems.count)")
                
                // 更新 UI
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.tableView.reloadData()
                    
                    // 滾動到頂部
                    if !self.scannedItems.isEmpty {
                        let indexPath = IndexPath(row: 0, section: 0)
                        self.tableView.scrollToRow(at: indexPath, at: .top, animated: true)
                    }
                    
                    // 清空輸入欄位
                    textField.text = ""
                    self.scanningLabel.text = "等待掃描..."
                    self.isScanning = false
                }
            }
            return false
        }
        
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        ensureTextFieldIsFocused()
    }

    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return true
    }
}
