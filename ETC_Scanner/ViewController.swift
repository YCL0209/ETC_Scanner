//
//  ViewController.swift
//  ETC_Scanner
//
//  Created by 廖亞丞 on 2025/2/16.
//

import UIKit
import CoreBluetooth
import AudioToolbox 

// MARK: - Properties
struct ScanItem {
    let code: String
    let time: String
    var building: String?      // 棟別
    var household: String?     // 戶別
    var parkingNumber: String? // 車位號碼
    var carType: String?      // 車種
    var carNumber: String?    // 車牌
    var etagNumber: String?   // ETAG
    var isEdited: Bool   
    var isSelected: Bool
}
class NetworkManager {
    static let shared = NetworkManager()
    private var serverURL: String = "http://default-url.com" // 預設網址
    private var fileName: String = "住戶ETC資料.csv" // 預設檔案名稱
    private let adminPassword = "123456" // 設定管理員密碼
    
    private init() {}
    // 新增獲取檔案名稱的方法
    func getFileName() -> String {
        return fileName
    }
    
    func updateSettings(newURL: String, newFileName: String, password: String) -> Bool {
        guard password == adminPassword else {
            return false
        }
        serverURL = newURL
        fileName = newFileName
        return true
    }
    func downloadCSV(completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: "\(serverURL)/\(fileName)") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            completion(.success(data))
        }
        task.resume()
    }
    
     func uploadCSV(fileURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        guard let url = URL(string: serverURL) else {
            completion(false, NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: text/csv\r\n\r\n".data(using: .utf8)!)
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            data.append(fileData)
            data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            
            let task = URLSession.shared.uploadTask(with: request, from: data) { (_, response, error) in
                if let error = error {
                    completion(false, error)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    completion(httpResponse.statusCode == 200, nil)
                }
            }
            task.resume()
        } catch {
            completion(false, error)
        }
    }
}
class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIDocumentPickerDelegate, EditDetailViewControllerDelegate {
    
    // MARK: - Properties
    private var selectedItemIndex: Int?
    private var filteredItems: [ScanItem] = []
    private var isSearching = false
    
    // MARK: - IBOutlets
    //@IBOutlet weak var titleLabel: UILabel!      // 新增標題 Label
    @IBOutlet weak var statusLabel: UILabel?     // 新增狀態 Label
    @IBOutlet weak var tableView: UITableView?   // 掃描記錄表格
    //@IBOutlet weak var inputTitleLabel: UILabel?     // 新增 "當前輸入:" 標籤
    //@IBOutlet weak var scanningLabel: UILabel?       // 新增 "等待掃描..." 標籤
    @IBOutlet weak var importButton: UIButton?           // 匯入按鈕
    @IBOutlet weak var exportButton: UIButton?       // 匯出所選按鈕
    @IBOutlet weak var deleteButton: UIButton?       // 刪除所選按鈕
    @IBOutlet weak var topBackgroundImage: UIImageView?  // 掃描標題
    @IBOutlet weak var scannerImageView: UIImageView?  //掃描背景
    @IBOutlet weak var scanTextLabel: UILabel?
    @IBOutlet weak var searchButton: UIButton?  // 搜尋按鈕
    
    private var scannerTextField: UITextField!
    var scannedItems: [ScanItem] = [] {
        didSet {
            ()
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
        // 檢查 IBOutlet 連接
        checkIBOutletConnections()
        
        setupUI()
        setupTextField()
        updateSearchButtonTitle()
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // 調整按鈕大小以符合圖片
        if let all = importButton,
           let export = exportButton,
           let delete = deleteButton {
            [all, export, delete].forEach { button in
                button.imageView?.contentMode = .scaleAspectFit
                button.imageView?.frame = button.bounds
            }
        }
    }
    // 新增一個檢查方法
    private func checkIBOutletConnections() {
        // 檢查 TableView
        if tableView != nil {
            print("✅ TableView 已正確連接")
        } else {
            print("❌ 錯誤：TableView 未連接")
        }
        
        // 檢查其他 IBOutlet
        if statusLabel == nil { print("❌ statusLabel 未連接") }
        if scanTextLabel == nil { print("❌  scanTextLabel 未連接") }
        if scannerImageView == nil { print("❌ scannerImageView 未連接") }
        if importButton == nil { print("❌ importButton 未連接") }
        if exportButton == nil { print("❌ exportButton 未連接") }
        if deleteButton == nil { print("❌ deleteButton 未連接") }
        if topBackgroundImage == nil { print("❌ topBackgroundImage 未連接") }
    }
    
    
    // MARK: - Setup
    private func setupUI() {
        setupTopBackground()
        setupStatusArea()
        setupScanningArea()
        setupButtonsArea()
        setupTableView()
    }
    private func setupScanningArea() {
        guard let imageView = scannerImageView,
              let textLabel = scanTextLabel else {
            print("❌ 掃描區域元件未連接")
            return
        }
        
        // 檢查圖片是否能夠載入
        let image = UIImage(named: "scanner_background")
        print("掃描器圖片: \(image != nil ? "載入成功" : "載入失敗")")
        
        imageView.image = image
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        
        // 確保視圖可見
        imageView.isHidden = false
        imageView.alpha = 1.0
        
        // 設置掃描文字標籤
        textLabel.text = "等待掃描..."
        textLabel.textColor = .darkGray
        textLabel.backgroundColor = .clear  // 透明背景
        textLabel.textAlignment = .center
    }
    //頂部圖片
    private func setupTopBackground() {
        guard let topImage = topBackgroundImage else {
            print("❌ 頂部背景圖未連接")
            return
        }
        topImage.contentMode = .scaleAspectFill
        topImage.clipsToBounds = true
    }
    //狀態
    private func setupStatusArea() {
        guard let status = statusLabel else {
            print("❌ 狀態標籤未連接")
            return
        }
        status.text = "待機中"
        status.textColor = .white
        status.font = .systemFont(ofSize: 14)
    }
    
    //按鈕
    private func setupButtonsArea() {
        guard let all = importButton,
              let export = exportButton,
              let delete = deleteButton,
              let search = searchButton else {
            print("❌ 按鈕未完全連接")
            return
        }
        
        // 設定共用的按鈕大小和樣式
        let buttonSize = CGSize(width: 70, height: 40)
        let buttons = [all, export, delete, search]
        
        // 統一設定所有按鈕的基本屬性
        buttons.forEach { button in
            // 設定大小約束
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: buttonSize.width),
                button.heightAnchor.constraint(equalToConstant: buttonSize.height)
            ])
            
            // 基本樣式設定
            button.backgroundColor = UIColor(red: 135/255, green: 206/255, blue: 235/255, alpha: 1.0)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
            button.layer.cornerRadius = 8
            button.layer.masksToBounds = true
            
            // 添加觸控反饋
            button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(buttonTouchUpInside(_:)), for: .touchUpInside)
            button.addTarget(self, action: #selector(buttonTouchUpOutside(_:)), for: .touchUpOutside)
            button.addTarget(self, action: #selector(buttonTouchDragExit(_:)), for: .touchDragExit)
        }
        
        // 設定按鈕文字
        all.setTitle("匯入", for: .normal)
        export.setTitle("匯出", for: .normal)
        delete.setTitle("刪除", for: .normal)
        search.setTitle("搜尋", for: .normal)
        
        // 刪除按鈕使用紅色背景
        delete.backgroundColor = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0)
    }
    
    // MARK: - Button Actions
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.alpha = 0.8
            
            // 如果是匯入按鈕，改變背景色
            if sender == self.importButton {
                sender.backgroundColor = UIColor(red: 100/255, green: 181/255, blue: 210/255, alpha: 1.0)
            }
        }
        
        // 添加觸覺反饋
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @objc private func buttonTouchUpInside(_ sender: UIButton) {
        resetButtonState(sender)
    }
    
    @objc private func buttonTouchUpOutside(_ sender: UIButton) {
        resetButtonState(sender)
    }
    
    @objc private func buttonTouchDragExit(_ sender: UIButton) {
        resetButtonState(sender)
    }
    
    
    
    private func resetButtonState(_ button: UIButton) {
        UIView.animate(withDuration: 0.1) {
            button.transform = .identity
            button.alpha = 1.0
            
            // 根據按鈕類型恢復原始顏色
            if button == self.deleteButton {
                button.backgroundColor = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0)
            } else {
                button.backgroundColor = UIColor(red: 135/255, green: 206/255, blue: 235/255, alpha: 1.0)
            }
        }
    }
    // 添加搜尋按鈕動作
    @IBAction func searchButtonTapped(_ sender: UIButton) {
         // 如果當前正在搜尋中，點擊搜尋按鈕會直接重置回完整列表
          if isSearching {
             resetSearch()
          } else {
             showSearchDialog()
    }
    }
    
    // 顯示搜尋對話框
    private func showSearchDialog() {
    let alert = UIAlertController(title: "搜尋", message: "請輸入搜尋內容", preferredStyle: .alert)
    
    alert.addTextField { textField in
        textField.placeholder = "輸入搜尋內容"
    }
    
    let searchAction = UIAlertAction(title: "搜尋", style: .default) { [weak self] _ in
        if let searchText = alert.textFields?.first?.text {
            self?.performSearch(searchText)
        }
    }
    
    let cancelAction = UIAlertAction(title: "取消", style: .cancel)
    
    alert.addAction(searchAction)
    alert.addAction(cancelAction)
    
    present(alert, animated: true)
}
    // 更新搜尋按鈕的標題
     private func updateSearchButtonTitle() {
          searchButton?.setTitle(isSearching ? "返回搜尋" : "搜尋", for: .normal)
    }
 
    
    // 執行搜尋
    private func performSearch(_ searchText: String) {
        if searchText.isEmpty {
            resetSearch()
            return
        }
        
        isSearching = true
       searchButton?.setTitle("返回搜尋", for: .normal)

        let searchTextLower = searchText.lowercased()
        
        filteredItems = scannedItems.filter { item in
            return item.code.lowercased().contains(searchTextLower) ||
                   (item.building?.lowercased().contains(searchTextLower) ?? false) ||
                   (item.household?.lowercased().contains(searchTextLower) ?? false) ||
                   (item.parkingNumber?.lowercased().contains(searchTextLower) ?? false) ||
                   (item.carType?.lowercased().contains(searchTextLower) ?? false) ||
                   (item.carNumber?.lowercased().contains(searchTextLower) ?? false) ||
                   (item.etagNumber?.lowercased().contains(searchTextLower) ?? false)
        }
        
        if filteredItems.isEmpty {
            showAlert(title: "搜尋結果", message: "找不到符合的項目")
            resetSearch()
        } else {
            tableView?.reloadData()
        }
    }
    
    // 重置搜尋
    private func resetSearch() {
        isSearching = false
        filteredItems.removeAll()
        searchButton?.setTitle("搜尋", for: .normal) 
        tableView?.reloadData()
    }
    
    
    // MARK: - Actions
    private func setupTableView() {
        guard let table = tableView else {
            print("❌ 表格視圖未連接")
            return
        }
        
        print("開始設置 TableView")
        
        table.delegate = self
        table.dataSource = self
        
        // 重要：註冊自定義 Cell
        table.register(ScanItemCell.self, forCellReuseIdentifier: ScanItemCell.identifier)
        
        table.rowHeight = 110
        table.backgroundColor = .white
        table.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        // 確保 TableView 可見
        table.isHidden = false
        table.alpha = 1.0
        
        print("TableView 設置完成")
    }
    // 將編輯視圖控制器的顯示邏輯移到獨立的方法中
    private func showEditViewController(for index: Int) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let editVC = storyboard.instantiateViewController(withIdentifier: "EditDetailViewController") as? EditDetailViewController {
            editVC.delegate = self
            editVC.itemIndex = index
            
            let item = scannedItems[index]
            editVC.currentBuilding = item.building ?? ""
            editVC.currentHousehold = item.household ?? ""
            editVC.currentParkingNumber = item.parkingNumber ?? ""
            editVC.currentCarType = item.carType ?? ""
            editVC.currentCarNumber = item.carNumber ?? ""
            editVC.currentEtagNumber = item.etagNumber ?? ""
            
            editVC.modalPresentationStyle = .formSheet
            present(editVC, animated: true)
        }
    }
    
    // MARK: - EditDetailViewControllerDelegate
    func didUpdateDetails(building: String, household: String, parkingNumber: String, carType: String, carNumber: String, etagNumber: String, at index: Int) {
        var updatedItem = scannedItems[index]
        updatedItem.building = building
        updatedItem.household = household
        updatedItem.parkingNumber = parkingNumber
        updatedItem.carType = carType
        updatedItem.carNumber = carNumber
        updatedItem.etagNumber = etagNumber
        updatedItem.isEdited = true
        scannedItems[index] = updatedItem
        
        let indexPath = IndexPath(row: index, section: 0)
        tableView?.reloadRows(at: [indexPath], with: .automatic)
        
        DispatchQueue.main.async { [weak self] in
            self?.ensureTextFieldIsFocused()
        }
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? filteredItems.count : scannedItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("準備設置 Cell，row: \(indexPath.row)")
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ScanItemCell", for: indexPath) as? ScanItemCell else {
            print("錯誤：無法建立 Cell")
            return UITableViewCell()
        }
        
        let item = isSearching ? filteredItems[indexPath.row] : scannedItems[indexPath.row]
             cell.configure(with: item)
             cell.selectionStyle = .default
    
    // 設定選擇狀態
        if item.isSelected {
              cell.setSelected(true, animated: false)
           tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
         } else {
            cell.setSelected(false, animated: false)
            tableView.deselectRow(at: indexPath, animated: false)
    }  
    
              cell.onEditButtonTapped = { [weak self] in
        guard let self = self else { return }
        let originalIndex: Int
        if self.isSearching {
            if let index = self.scannedItems.firstIndex(where: { $0.code == item.code && $0.time == item.time }) {
                originalIndex = index
            } else {
                return
            }
        } else {
            originalIndex = indexPath.row
        }
        self.showEditViewController(for: originalIndex)
    }
    
        return cell
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 110
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // 取消所有項目的選擇
        for i in 0..<scannedItems.count {
            scannedItems[i].isSelected = false
        }
         // 同時清除過濾項目的選擇狀態
        for i in 0..<filteredItems.count {
            filteredItems[i].isSelected = false
        }
    
        
        if isSearching {
        // 在搜尋模式下
        let selectedItem = filteredItems[indexPath.row]
        if let originalIndex = scannedItems.firstIndex(where: { $0.code == selectedItem.code && $0.time == selectedItem.time }) {
            // 更新原始資料中的選擇狀態
            scannedItems[originalIndex].isSelected = true
            selectedItemIndex = originalIndex
            
            // 更新過濾資料中的選擇狀態
            filteredItems[indexPath.row].isSelected = true
        }
          } else {
        // 非搜尋模式下
        scannedItems[indexPath.row].isSelected = true
        selectedItemIndex = indexPath.row
    }
        // 更新按鈕狀態
        updateButtonStates()
        // 重新加載表格以更新顯示
        tableView.reloadData()
    }

    // MARK: - UITextFieldDelegate
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // 更新掃描標籤 - 這樣用戶能看到正在輸入的內容
        if !string.isEmpty {
            // 將字母轉為大寫，保持與車牌格式一致
            let formattedString = string.uppercased()
            scanTextLabel?.text = (textField.text ?? "").uppercased() + formattedString
        }
        
        // 如果是換行符，表示一次掃描完成
        if string == "\n" || string == "\r" {
            let fullScan = textField.text?.uppercased() ?? ""
            print("完整掃描結果: \(fullScan)")
            
            // 提取 EPC Code 並轉為大寫
            let epcCode = extractEPCCode(from: fullScan)?.uppercased()
            
            if let code = epcCode, !code.isEmpty {
                print("提取的 EPC Code: \(code)")
                
                // 檢查是否有選中的項目
                if let selectedIndex = selectedItemIndex {
                    // 更新選中項目的 ETAG 號碼
                    var updatedItem = scannedItems[selectedIndex]
                    updatedItem.etagNumber = code
                    updatedItem.isEdited = true
                    scannedItems[selectedIndex] = updatedItem
                    
                    // 顯示成功訊息
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.showAlert(title: "更新成功", message: "ETC 標籤已更新")
                        self.tableView?.reloadRows(at: [IndexPath(row: selectedIndex, section: 0)], with: .automatic)
                        textField.text = ""
                        self.scanTextLabel?.text = "等待掃描..."
                        self.isScanning = false
                    }
                } else {
                    // 如果沒有選中項目，創建新項目
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
                    let timeString = dateFormatter.string(from: Date())
                    
                    let newItem = ScanItem(
                        code: code,
                        time: timeString,
                        building: "",
                        household: "",
                        parkingNumber: "",
                        carType: "",
                        carNumber: "",
                        etagNumber: code,
                        isEdited: false,
                        isSelected: false
                    )
                    
                    // 新增到資料陣列
                    scannedItems.insert(newItem, at: 0)
                    
                    // 更新 UI
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.tableView?.reloadData()
                        
                        // 滾動到頂部並自動選中新項目
                        if !self.scannedItems.isEmpty, let tableView = self.tableView {
                            let indexPath = IndexPath(row: 0, section: 0)
                            tableView.scrollToRow(at: indexPath, at: .top, animated: true)
                            
                            // 自動選中新項目
                            for i in 0..<self.scannedItems.count {
                                self.scannedItems[i].isSelected = (i == 0)
                            }
                            self.selectedItemIndex = 0
                            tableView.reloadData()
                            
                            // 提示用戶完成其他資料
                            self.showAlert(title: "新建項目", message: "已新建ETC項目，請點擊編輯按鈕完成其餘資料")
                        }
                        
                        // 清空輸入欄位
                        textField.text = ""
                        self.scanTextLabel?.text = "等待掃描..."
                        self.isScanning = false
                    }
                }
            } else {
                // 沒有找到有效的 EPC Code
                DispatchQueue.main.async { [weak self] in
                    self?.showAlert(title: "掃描錯誤", message: "無法識別有效的 EPC Code")
                    textField.text = ""
                    self?.scanTextLabel?.text = "等待掃描..."
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

    // MARK: - UIDocumentPickerDelegate
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedFileURL = urls.first else { return }
        
        // 添加觸覺反饋
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        parseCSV(from: selectedFileURL)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // 使用者取消選擇檔案
        dismiss(animated: true)
    }
    
    private func setupTextField() {
        scannerTextField = UITextField()
        scannerTextField.delegate = self
        
        // 設定輸入格式為英文和數字
        scannerTextField.keyboardType = .asciiCapable
        scannerTextField.autocapitalizationType = .allCharacters
        
        // 只在主畫面隱藏鍵盤
        let hiddenInputView = UIView(frame: .zero)
        hiddenInputView.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        scannerTextField.inputView = hiddenInputView  // 這行設定會讓鍵盤不顯示
        
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
        guard let status = statusLabel else { return }
        status.text = isScanning ? "讀取中" : "待機中"
        status.textColor = isScanning ? .systemGreen : .white
    }
    
    private func updateButtonStates() {
        let selectedCount = scannedItems.filter { $0.isSelected }.count
        
        // 更新匯入按鈕狀態（如果需要的話）
        importButton?.isEnabled = true // 或根據其他條件設定
        
       // 匯出按鈕永遠啟用
         exportButton?.isEnabled = true
    
        // 只有刪除按鈕需要檢查選擇狀態
         deleteButton?.isEnabled = selectedCount > 0
    }
    
    // MARK: - Actions
    @IBAction func importButtonTapped(_ sender: UIButton) {
       let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
    longPress.minimumPressDuration = 2.0
    importButton?.addGestureRecognizer(longPress)
    
    // 顯示選擇來源的選項
    let alert = UIAlertController(title: "選擇匯入來源", 
                                message: "請選擇從本地檔案或伺服器匯入", 
                                preferredStyle: .actionSheet)
    
    // 從本地檔案匯入
    let localAction = UIAlertAction(title: "從本地檔案匯入", style: .default) { [weak self] _ in
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.commaSeparatedText], asCopy: true)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        self?.present(documentPicker, animated: true)
    }
    
    // 從伺服器匯入
    let serverAction = UIAlertAction(title: "從伺服器匯入", style: .default) { [weak self] _ in
        // 添加觸覺反饋
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        NetworkManager.shared.downloadCSV { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let csvString = String(data: data, encoding: .utf8) {
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp.csv")
                        do {
                            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
                            self?.parseCSV(from: tempURL)
                        } catch {
                            self?.showAlert(title: "錯誤", message: "無法處理檔案：\(error.localizedDescription)")
                        }
                    }
                case .failure(let error):
                    self?.showAlert(title: "錯誤", message: "無法從伺服器下載：\(error.localizedDescription)")
                }
            }
        }
    }
    
    let cancelAction = UIAlertAction(title: "取消", style: .cancel)
    
    alert.addAction(localAction)
    alert.addAction(serverAction)
    alert.addAction(cancelAction)
    
    // iPad 需要設置 popoverPresentationController
    if let popover = alert.popoverPresentationController {
        popover.sourceView = sender
        popover.sourceRect = sender.bounds
    }
    
    present(alert, animated: true)
}
    
    @IBAction func exportButtonTapped(_ sender: UIButton) {
    let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
    longPress.minimumPressDuration = 2.0 // 設定長按 2 秒才觸發
    exportButton?.addGestureRecognizer(longPress)
    
     // 建立 CSV 標題行（與匯入格式完全一致）
    let csvHeader = "序號,棟別,戶別,車位號碼,車種,車牌,ETAG\n"
    
    // 將所有項目轉換為 CSV 格式，注意順序要與匯入時完全一致
    let csvRows = scannedItems.enumerated().map { (index, item) in
        let fields = [
            String(index + 1),                // 序號
            item.building ?? "",              // 棟別
            item.household ?? "",             // 戶別
            item.parkingNumber ?? "",         // 車位號碼
            item.carType ?? "",               // 車種
            item.carNumber ?? "",             // 車牌
            item.etagNumber ?? ""             // ETAG
        ]
        // 確保每個欄位都有值，即使是空值也要保留逗號
        return fields.joined(separator: ",")
    }.joined(separator: "\n")
    
    // 組合完整的 CSV 內容
    let csvContent = csvHeader + csvRows
    
    // 創建暫時的 CSV 檔案
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent(NetworkManager.shared.getFileName())
    
    do {
        try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        // 直接上傳到伺服器
        NetworkManager.shared.uploadCSV(fileURL: fileURL) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.showAlert(title: "成功", message: "檔案已成功上傳到伺服器")
                } else {
                    self?.showAlert(title: "錯誤", message: "上傳失敗：\(error?.localizedDescription ?? "未知錯誤")")
                }
            }
        }
    } catch {
        showAlert(title: "錯誤", message: "無法建立匯出檔案：\(error.localizedDescription)")
    }
}
    
    // 新增長按處理方法
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
         if gesture.state == .began {
        // 震動回饋
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        
        showServerSettingsAlert()
    }
}
    // 新增顯示設定伺服器的彈出視窗方法
    private func showServerSettingsAlert() {
         let alert = UIAlertController(title: "伺服器設定", message: "請輸入新的網址和管理員密碼", preferredStyle: .alert)
    
    alert.addTextField { textField in
        textField.placeholder = "新網址"
        textField.keyboardType = .URL
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
    }
    alert.addTextField { textField in
        textField.placeholder = "住戶ETC資料.csv"
        textField.text = NetworkManager.shared.getFileName()
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
    }
    
    alert.addTextField { textField in
        textField.placeholder = "管理員密碼"
        textField.isSecureTextEntry = true
    }
    
    let confirmAction = UIAlertAction(title: "確認", style: .default) { [weak self] _ in
        guard let newURL = alert.textFields?[0].text,
              let fileName = alert.textFields?[1].text,
              let password = alert.textFields?[2].text else { return }
        
        if NetworkManager.shared.updateSettings(newURL: newURL, newFileName: fileName, password: password) {
            self?.showAlert(title: "成功", message: "伺服器設定已更新")
        } else {
            self?.showAlert(title: "錯誤", message: "密碼錯誤")
        }
    }
    
    alert.addAction(confirmAction)
    alert.addAction(UIAlertAction(title: "取消", style: .cancel))
    
    present(alert, animated: true)
}
    
    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "確認刪除",
                                      message: "確定要刪除所選項目嗎？",
                                       preferredStyle: .alert)  // 修改這裡
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "刪除", style: .destructive) { [weak self] _ in
            self?.deleteSelectedItems()
        })
        
        present(alert, animated: true)
    }
    
    private func deleteSelectedItems() {
        scannedItems = scannedItems.filter { !$0.isSelected }
        tableView?.reloadData()
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }
    
    private func parseCSV(from url: URL) {
        do {
            let csvContent = try String(contentsOf: url, encoding: .utf8)
            // 過濾掉空行並分割
            let rows = csvContent.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            // 假設CSV的標題行為：條碼,棟別,戶別,車位號碼,車種,車牌,ETAG
            // 跳過標題行
            for row in rows.dropFirst() {
                // 移除多餘的空白
                let trimmedRow = row.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedRow.isEmpty else { continue }
                
                let columns = trimmedRow.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                
                // 確保至少有ETC條碼欄位
                if columns.count >= 1 && !columns[0].isEmpty {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
                    let timeString = dateFormatter.string(from: Date())
                    
                    let etcCode = columns[0]
                    
                    let newItem = ScanItem(
                        code: etcCode,
                        time: timeString,
                        building: columns.count > 1 ? columns[1] : nil,      // 棟別
                        household: columns.count > 2 ? columns[2] : nil,     // 戶別
                        parkingNumber: columns.count > 3 ? columns[3] : nil, // 車位號碼
                        carType: columns.count > 4 ? columns[4] : nil,       // 車種
                        carNumber: columns.count > 5 ? columns[5] : nil,     // 車牌
                        etagNumber: etcCode,                                // ETAG（與條碼相同）
                        isEdited: false,
                        isSelected: false
                    )
                    
                    scannedItems.insert(newItem, at: 0)
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.tableView?.reloadData()
                self?.showAlert(title: "成功", message: "檔案已成功匯入")
            }
            
        } catch {
            showAlert(title: "錯誤", message: "無法讀取檔案：\(error.localizedDescription)")
        }
    }
    // 在 ViewController 類中添加這個函數
    private func extractEPCCode(from scanResult: String) -> String? {
        // 基於掃描樣本：
        // Time Log: 2014/12/19 12:30:59
        // RSSI:3A
        // EPC Scheme:STGIN-96
        // EPC Code:301122334455667788990011
        // PC: 3000
        // CRC: ABCD
        // TID: 123456789012 設備掃出來的樣式
        
        // 嘗試方法 1：查找 "EPC Code:" 行
        let lines = scanResult.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("EPC Code:") || line.contains("EPC Code：") {
                // 可能出現中文全形冒號
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    // 提取 EPC Code 部分並清理
                    var epcCode = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // 過濾非英數字符並轉為大寫
                    epcCode = epcCode.filter { $0.isLetter || $0.isNumber }.uppercased()
                    
                    return epcCode
                } else {
                    // 嘗試使用全形冒號分割
                    let componentsFullWidth = line.components(separatedBy: "：")
                    if componentsFullWidth.count > 1 {
                        var epcCode = componentsFullWidth[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        epcCode = epcCode.filter { $0.isLetter || $0.isNumber }.uppercased()
                        return epcCode
                    }
                }
            }
        }
        
        // 嘗試方法 2：尋找符合 EPC Code 格式的行
        // 通常 EPC Code 是 24 個十六進制字符或更長
        for line in lines {
            // 過濾掉非英數的字符
            let filteredLine = line.filter { $0.isLetter || $0.isNumber }
            // 如果過濾後的行有足夠長度且只包含十六進制字符 (0-9, A-F)
            if filteredLine.count >= 24 && filteredLine.allSatisfy({
                ($0 >= "0" && $0 <= "9") || ($0 >= "A" && $0 <= "F") || ($0 >= "a" && $0 <= "f")
            }) {
                return filteredLine.uppercased()
            }
        }
        
        // 嘗試方法 3：提取最長的連續英數字字符串
        var longestAlphanumeric = ""
        var currentAlphanumeric = ""
        
        for char in scanResult {
            if char.isLetter || char.isNumber {
                currentAlphanumeric.append(char)
            } else {
                if currentAlphanumeric.count > longestAlphanumeric.count {
                    longestAlphanumeric = currentAlphanumeric
                }
                currentAlphanumeric = ""
            }
        }
        
        // 檢查最後一段
        if currentAlphanumeric.count > longestAlphanumeric.count {
            longestAlphanumeric = currentAlphanumeric
        }
        
        // 如果找到足夠長的字符串，認為它可能是 EPC Code
        if longestAlphanumeric.count >= 12 {
            return longestAlphanumeric.uppercased()
        }
        
        return nil
    }
}

// MARK: - UIImage Extension
extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
