//
//  ViewController.swift
//  ETC_Scanner
//
//  Created by 廖亞丞 on 2025/2/16.
// 1.0.1版

import UIKit
import CoreBluetooth
import AudioToolbox 

// MARK: - Properties
struct ScanItem {
    let code: String           //掃描碼
    let time: String
    var building: String?      // 棟別
    var household: String?     // 戶別
    var parkingNumber: String? // 車位號碼
    var carType: String?      // 車種
    var carNumber: String?    // 車牌
    var etagNumber: String?   // ETAG
    var isEdited: Bool         // 是否編輯過
    var isSelected: Bool       // 是否選取
    // 新增額外資訊欄位
    var owner: String?        // 所有權人
    var tenant: String?       // 承租人
    var phone: String?        // 電話
}
// 首先新增一個結構來儲存檔案資訊
struct FileInfo: Codable {
    let fileName: String
    let size: Int
    let uploadTime: String
    
    // 格式化檔案大小的計算屬性
    var formattedSize: String {
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
        }
    }
    
    // 格式化上傳時間的計算屬性
    var formattedTime: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSZZZZZ"
        if let date = dateFormatter.date(from: uploadTime) {
            dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
            return dateFormatter.string(from: date)
        }
        return uploadTime
    }
}

struct ServerResponse: Codable {
    let success: Bool
    let files: [FileInfo]
}

class NetworkManager {
    static let shared = NetworkManager()
    private var serverURL: String = "http://192.168.1.102:5000"
    private var fileName: String = "住戶ETC資料.csv" // 預設檔案名稱
    private let adminPassword = "123456" // 設定管理員密碼
    
    private init() {}

    // 新增檢查伺服器狀態的方法
    func checkServerStatus(completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(serverURL)/api/server/info") else {
            completion(false, "無效的伺服器網址")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                completion(false, "網路錯誤：\(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "未收到伺服器回應")
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                completion(false, "伺服器回應異常：\(httpResponse.statusCode)")
                return
            }
            
            completion(true, nil)
        }
        task.resume()
    }
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
    func downloadCSV(fileName: String, completion: @escaping (Result<Data, Error>) -> Void) {
        // 修改 URL 構建方式，使用正確的下載 API 路徑
        guard let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(serverURL)/api/file/download?fileName=\(encodedFileName)") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                completion(.failure(NSError(domain: "", code: httpResponse.statusCode, 
                    userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])))
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
        guard let url = URL(string: "\(serverURL)/api/file/upload") else {
            completion(false, NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
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
     func fetchFileList(completion: @escaping (Result<[FileInfo], Error>) -> Void) {
        guard let url = URL(string: "\(serverURL)/api/file/list") else {
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
            
            do {
                let response = try JSONDecoder().decode(ServerResponse.self, from: data)
                if response.success {
                    completion(.success(response.files))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server returned failure"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    }
    

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIDocumentPickerDelegate, EditDetailViewControllerDelegate, CustomAlphaNumKeyboardDelegate {
    
    private struct KeyboardRules {
        unowned let viewController: ViewController
        
        init(_ viewController: ViewController) {
            self.viewController = viewController
        }
        
        func setupScannerKeyboard(_ textField: UITextField) {
            textField.keyboardType = .asciiCapable
            textField.autocapitalizationType = .allCharacters
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.smartQuotesType = .no
            textField.smartDashesType = .no
            textField.isHidden = true
            textField.alpha = 0.01
        }
        
        func handleInput(_ string: String, in textField: UITextField) -> Bool {
            // 一般輸入處理
            if !string.isEmpty {
                let formattedString = string.uppercased()
                let currentText = (textField.text ?? "").uppercased()
                let updatedText = currentText + formattedString
                viewController.scanTextLabel?.text = updatedText
                return true
            }
            
            // 掃描完成處理
            if string == "\n" || string == "\r" {
                if let fullScan = textField.text?.uppercased() {
                    viewController.handleScanCompletion(fullScan)
                }
                return false
            }
            
            return true
        }
    }
    private lazy var keyboardRules: KeyboardRules = {
        return KeyboardRules(self)
    }()
    // MARK: - Properties
    private var selectedItemIndex: Int?
    private var filteredItems: [ScanItem] = []
    private var isSearching = false
    
    private struct ScannerState {
        var isScanning: Bool = false
        var currentInput: String = ""
        var keyboardIsVisible: Bool = false
    }
    
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
            print("目前資料數量：\(scannedItems.count)")
        }
    }
    
    private var isScanning = false {
        didSet {
            updateStatusLabel()
        }
    }
    
    
    var customKeyboard: CustomAlphaNumKeyboard!
    
    // MARK: - Lifecyclerivate 
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
        customKeyboard = CustomAlphaNumKeyboard()
        customKeyboard.delegate = self
        
        // 每次啟動都顯示說明
        showAppInstructions()
        
        print("viewDidLoad 完成")
    }
    // 在 class ViewController 內，其他方法的同層級添加這兩個方法
   override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // 確保方向鎖定在直向
    AppDelegate.AppUtility.lockOrientation(.portrait)
    
    // 延遲執行以確保視圖已加載
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        // 重新設置掃描器
        self.setupTextField()
    }
}
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 離開頁面時解除方向鎖定
        AppDelegate.AppUtility.lockOrientation(.all)

        // 確保離開主頁面時，scannerTextField 不再是第一響應者
        if scannerTextField.isFirstResponder {
        scannerTextField.resignFirstResponder()
        }
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
    if scannerTextField.isFirstResponder {
        scannerTextField.resignFirstResponder()
    }
    
    let alert = UIAlertController(title: "搜尋", message: "請輸入搜尋內容", preferredStyle: .alert)
    
    alert.addTextField { textField in
        textField.placeholder = "輸入搜尋內容"
        
        // 確保創建新的 customKeyboard 實例
        let customKeyboard = CustomAlphaNumKeyboard()
        customKeyboard.targetTextField = textField
        textField.inputView = customKeyboard
        textField.delegate = self
    }
    
    let searchAction = UIAlertAction(title: "搜尋", style: .default) { [weak self] _ in
        if let searchText = alert.textFields?.first?.text {
            self?.performSearch(searchText)
        }
    }
    
    let cancelAction = UIAlertAction(title: "取消", style: .cancel)
    
    alert.addAction(searchAction)
    alert.addAction(cancelAction)
    
    present(alert, animated: true) {
        alert.textFields?.first?.becomeFirstResponder()
    }
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
    
    table.delegate = self
    table.dataSource = self
    
    // 註冊自定義 Cell
    table.register(ScanItemCell.self, forCellReuseIdentifier: ScanItemCell.identifier)
    
    // 啟用自動調整行高
    table.rowHeight = UITableView.automaticDimension
    table.estimatedRowHeight = 110
    
    // 減少重新繪製的頻率
    table.allowsMultipleSelection = true
    
    // 優化記憶體使用
    table.cellLayoutMarginsFollowReadableWidth = false
    
    // 確保 TableView 可見
    table.isHidden = false
    table.alpha = 1.0
    
    print("TableView 設置完成")
}
    // 將編輯視圖控制器的顯示邏輯移到獨立的方法中
    private func showEditViewController(for index: Int) {
         print("有沒有執行scannerTextField釋放焦點")
         // 第一步：強制釋放掃描器的焦點
         if scannerTextField.isFirstResponder {
            scannerTextField.resignFirstResponder()
         }
         
         // 確保系統有足夠時間處理焦點變更
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
             guard let self = self else { return }
             
             let storyboard = UIStoryboard(name: "Main", bundle: nil)
             if let editVC = storyboard.instantiateViewController(withIdentifier: "EditDetailViewController") as? EditDetailViewController {
                editVC.delegate = self
                editVC.itemIndex = index
                
                let item = self.scannedItems[index]
                editVC.currentBuilding = item.building ?? ""
                editVC.currentHousehold = item.household ?? ""
                editVC.currentParkingNumber = item.parkingNumber ?? ""
                editVC.currentCarType = item.carType ?? ""
                editVC.currentCarNumber = item.carNumber ?? ""
                editVC.currentEtagNumber = item.etagNumber ?? ""
                
                // 修改呈現方式，使用全屏呈現更好地處理鍵盤
                editVC.modalPresentationStyle = .fullScreen
                self.present(editVC, animated: true, completion: nil)
                        
                    
                
             }
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
        
        // 如果在搜尋模式下，也更新過濾後的資料
        if isSearching {
            if let filteredIndex = filteredItems.firstIndex(where: { $0.code == updatedItem.code && $0.time == updatedItem.time }) {
                filteredItems[filteredIndex] = updatedItem
                // 更新過濾後列表的對應行
                let filteredIndexPath = IndexPath(row: filteredIndex, section: 0)
                tableView?.reloadRows(at: [filteredIndexPath], with: .automatic)
            }
        } else {
            // 非搜尋模式下更新原始列表的對應行
            let indexPath = IndexPath(row: index, section: 0)
            tableView?.reloadRows(at: [indexPath], with: .automatic)
        }
        
        // 延長等待時間，確保編輯頁面完全關閉後再重新啟用掃描功能
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        self.resetScanner(complete: true)
        }
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? filteredItems.count : scannedItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(withIdentifier: "ScanItemCell", for: indexPath) as? ScanItemCell else {
        return UITableViewCell()
    }
    
    let item = isSearching ? filteredItems[indexPath.row] : scannedItems[indexPath.row]
    
    // 設定 cell 之前先取消所有現有內容，避免複用問題
    cell.prepareForReuse()
    
    // 配置 cell
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
    
    // 設置編輯按鈕回調，使用弱引用避免循環引用
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
        // 使用延遲來確保 UI 更新完成後再顯示編輯視圖
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.showEditViewController(for: originalIndex)
        }
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
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        print("收到輸入：\(string)")
        
        // 檢查是否為掃描結束
        if string == "\n" || string == "\r" || string.isEmpty {
            print("偵測到掃描結束，開始處理掃描結果")
            let fullScan = textField.text?.uppercased() ?? ""
            handleScanCompletion(fullScan)
            return false
        }
        
        // 其他字元照常處理
        return true
    }

    // 處理掃描結果的方法
    private func handleScanResult(epcCode: String) {
        print("handleScanResult 被呼叫，epcCode: \(epcCode)")
        if let selectedIndex = selectedItemIndex {
            // 更新選中項目的 ETAG
            print("更新選中項目 \(selectedIndex) 的 ETAG：\(epcCode)")
            
            var updatedItem = scannedItems[selectedIndex]
            updatedItem.etagNumber = epcCode
            updatedItem.isEdited = true
            scannedItems[selectedIndex] = updatedItem
            
            // 更新 UI
            DispatchQueue.main.async {
                self.tableView?.reloadRows(at: [IndexPath(row: selectedIndex, section: 0)], with: .automatic)
                self.showAlert(title: "更新成功", message: "ETC 標籤已更新")
                self.resetScanner(complete: true)
            }
        } else {
            // 創建新項目
            print("創建新的掃描項目")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
            let timeString = dateFormatter.string(from: Date())
            
            let newItem = ScanItem(
                code: epcCode,
                time: timeString,
                building: "",
                household: "",
                parkingNumber: "",
                carType: "",
                carNumber: "",
                etagNumber: epcCode,
                isEdited: false,
                isSelected: false
            )
            
            // 添加到數據源並更新 UI
            DispatchQueue.main.async {
                self.scannedItems.insert(newItem, at: 0)
                self.tableView?.reloadData()
                
                // 自動選中新項目
                if !self.scannedItems.isEmpty, let tableView = self.tableView {
                    let indexPath = IndexPath(row: 0, section: 0)
                    tableView.scrollToRow(at: indexPath, at: .top, animated: true)
                    
                    for i in 0..<self.scannedItems.count {
                        self.scannedItems[i].isSelected = (i == 0)
                    }
                    self.selectedItemIndex = 0
                    tableView.reloadData()
                    
                    self.showAlert(title: "新建項目", message: "已新建 ETC 項目，請點擊編輯按鈕完成其餘資料")
                }
                
                self.resetScanner(complete: true)
            }
        }
    }

    // 清除掃描狀態的方法
    private func resetScanner(complete: Bool = false) {
        scannerTextField.text = ""
        scanTextLabel?.text = "等待掃描..."
        isScanning = false
        
        if complete {
            scannerTextField.resignFirstResponder()
        }
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
    
   // 修改掃描器的 setupTextField 方法
     private func setupTextField() {
        scannerTextField?.removeFromSuperview()
        
        scannerTextField = UITextField(frame: .zero)
        scannerTextField.delegate = self
        
        // 使用 KeyboardRules 設定鍵盤
        keyboardRules.setupScannerKeyboard(scannerTextField)
        
        scannerTextField.isHidden = true
        scannerTextField.alpha = 0.01
        
        view.addSubview(scannerTextField)
        
        scannerTextField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scannerTextField.widthAnchor.constraint(equalToConstant: 1),
            scannerTextField.heightAnchor.constraint(equalToConstant: 1),
            scannerTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scannerTextField.topAnchor.constraint(equalTo: view.topAnchor, constant: 50)
        ])

        // 讓掃描器獲得焦點，但不顯示系統鍵盤
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        self.scannerTextField.inputView = UIView() // 使用空白視圖作為輸入視圖，防止鍵盤顯示
        self.scannerTextField.becomeFirstResponder()
    }
    }

// 修改 applicationWillEnterForeground 方法
@objc private func applicationWillEnterForeground() {
    // 應用恢復活動時，確保掃描器重新獲得焦點但不顯示鍵盤
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.scannerTextField.inputView = UIView() // 使用空白視圖作為輸入視圖，防止鍵盤顯示
        self.scannerTextField.becomeFirstResponder()
    }
}
  
// 在 viewDidDisappear 方法中添加以下代碼
override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    
    // 確保離開主頁面時，scannerTextField 不再是第一響應者
    if scannerTextField.isFirstResponder {
        scannerTextField.resignFirstResponder()
    }
    
    // 如果有其他需要在離開頁面時處理的邏輯，添加在這裡
}
    private func ensureTextFieldIsFocused() {
    if !scannerTextField.isFirstResponder {
        scannerTextField.inputView = UIView() // 使用空白視圖作為輸入視圖，防止鍵盤顯示
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
    // 創建匯入選項警告控制器
    let alert = UIAlertController(title: "選擇匯入來源",
                               message: "請選擇匯入方式",
                               preferredStyle: .actionSheet)
    
    // 從本地檔案匯入
    let localAction = UIAlertAction(title: "從本地檔案匯入", style: .default) { [weak self] _ in
        self?.importFromLocalFile()
    }
    
    // 從伺服器匯入
    let serverAction = UIAlertAction(title: "從伺服器匯入", style: .default) { [weak self] _ in
        // 顯示加載指示器
        self?.showLoadingAlert(message: "正在連接伺服器...")
        
        // 檢查伺服器狀態
        NetworkManager.shared.checkServerStatus { [weak self] (isAvailable, errorMessage) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.dismissLoadingAlert()
                
                if isAvailable {
                    // 觸覺反饋
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // 獲取檔案列表
                    self.showLoadingAlert(message: "正在獲取檔案列表...")
                    NetworkManager.shared.fetchFileList { result in
                        DispatchQueue.main.async {
                            self.dismissLoadingAlert()
                            
                            switch result {
                            case .success(let fileList):
                                if fileList.isEmpty {
                                    self.showAlert(title: "提示", message: "伺服器上沒有可用的檔案")
                                } else {
                                    self.showFileSelectionAlert(fileList: fileList)
                                }
                            case .failure(let error):
                                self.showAlert(title: "錯誤", message: "無法獲取檔案列表：\(error.localizedDescription)")
                            }
                        }
                    }
                } else {
                    self.showAlert(title: "伺服器錯誤", message: errorMessage ?? "無法連接到伺服器")
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
// 新增本地匯入方法
private func importFromLocalFile() {
    let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.commaSeparatedText], asCopy: true)
    documentPicker.delegate = self
    documentPicker.allowsMultipleSelection = false
    
    // 添加觸覺反饋
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
    
    present(documentPicker, animated: true)
}
    
    private func showFileSelectionAlert(fileList: [FileInfo]) {
        let alert = UIAlertController(title: "選擇檔案", 
                                    message: "請選擇要匯入的檔案", 
                                    preferredStyle: .actionSheet)
        
        for fileInfo in fileList {
            let actionTitle = """
                檔案：\(fileInfo.fileName)
                大小：\(fileInfo.formattedSize)
                上傳時間：\(fileInfo.formattedTime)
                """
            
            let fileAction = UIAlertAction(title: actionTitle, style: .default) { [weak self] _ in
                self?.showLoadingAlert(message: "正在下載檔案...")
                
                NetworkManager.shared.downloadCSV(fileName: fileInfo.fileName) { result in
                    DispatchQueue.main.async {
                        self?.dismissLoadingAlert()
                        
                        switch result {
                        case .success(let data):
                            if let csvString = String(data: data, encoding: .utf8) {
                                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileInfo.fileName)
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
            alert.addAction(fileAction)
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        alert.addAction(cancelAction)
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        
        present(alert, animated: true)
    }
    
    

    

    // 1. 生成單個欄位的字串
private func getFieldValue(index: Int, item: ScanItem, fieldType: Int) -> String {
    switch fieldType {
        case 0: return String(index + 1)    // 序號
        case 1: return item.building ?? ""   // 棟別
        case 2: return item.household ?? ""  // 戶別
        case 3: return item.owner ?? ""      // 所有權人
        case 4: return item.tenant ?? ""     // 承租人
        case 5: return item.phone ?? ""      // 電話
        case 6: return item.parkingNumber ?? "" // 車位號碼
        case 7: return item.carType ?? ""    // 車種
        case 8: return item.carNumber ?? ""  // 車牌
        case 9: return item.etagNumber ?? "" // ETAG
        default: return ""
    }
}

// 2. 生成單行資料
private func generateCSVRow(index: Int, item: ScanItem) -> String {
    var row = ""
    for i in 0...9 {
        row += getFieldValue(index: index, item: item, fieldType: i)
        if i < 9 {
            row += ","
        }
    }
    return row
}

// 3. 生成所有資料行
private func generateCSVRows() -> String {
    var rows = ""
    for (index, item) in scannedItems.enumerated() {
        rows += generateCSVRow(index: index, item: item)
        rows += "\n"
    }
    return rows
}

// 4. 生成 CSV 標題
private func generateCSVHeader() -> String {
    return "序號,棟別,戶別,所有權人,承租人,電話,車位號碼,車種,車牌,ETAG\n"
}

// 5. 生成完整 CSV 內容
private func generateCSVContent(for building: Building) -> String {
    let header = generateCSVHeader()
    var rows = ""
    
    // 過濾指定棟別的資料
    let filteredItems = scannedItems.filter { item in
        return item.building?.contains(building.rawValue) ?? false
    }
    
    // 生成資料行
    for (index, item) in filteredItems.enumerated() {
        rows += generateCSVRow(index: index, item: item)
        rows += "\n"
    }
    
    return header + rows
}
private enum Building: String, CaseIterable {
    case building1 = "第1棟"
    case building2 = "第2棟"
    
    var filenameSuffix: String {
        switch self {
        case .building1: return "#1"
        case .building2: return "#2"
        }
    }
}
// 6. 匯出按鈕動作
@IBAction func exportButtonTapped(_ sender: UIButton) {
    // 保留長按手勢
    let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
    longPress.minimumPressDuration = 1.5
    exportButton?.addGestureRecognizer(longPress)
    
    // 直接顯示棟別選擇
    showBuildingSelectionAlert(sender)
}
// 保留長按處理方法
@objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    if gesture.state == .began {
        // 震動回饋
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        
        showServerSettingsAlert()
    }
}
     // 新增棟別選擇的方法
// 修改匯出相關的方法
private func showBuildingSelectionAlert(_ sender: UIButton) {
    // 先檢查伺服器狀態
    NetworkManager.shared.checkServerStatus { [weak self] (isAvailable, errorMessage) in
        DispatchQueue.main.async {
            guard let self = self else { return }
            
            if !isAvailable {
                self.showAlert(title: "伺服器錯誤", message: errorMessage ?? "無法連接到伺服器")
                return
            }
            
            // 顯示棟別選擇對話框
            let alert = UIAlertController(title: "選擇棟別", 
                                        message: "請選擇要匯出的棟別", 
                                        preferredStyle: .actionSheet)
            
            // 為每個棟別創建選項
            for building in Building.allCases {
                let action = UIAlertAction(title: building.rawValue, style: .default) { [weak self] _ in
                    self?.exportCSVForBuilding(building)
                }
                alert.addAction(action)
            }
            
            let cancelAction = UIAlertAction(title: "取消", style: .cancel)
            alert.addAction(cancelAction)
            
            // iPad 需要設置 popoverPresentationController
            if let popover = alert.popoverPresentationController {
                popover.sourceView = sender
                popover.sourceRect = sender.bounds
            }
            
            self.present(alert, animated: true)
        }
    }
}

private func exportCSVForBuilding(_ building: Building) {
    // 生成檔案名稱，加入時間戳和棟別標記
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMddHHmmss"
    let timestamp = dateFormatter.string(from: Date())
    let fileName = "\(timestamp)_住戶ETC資料\(building.filenameSuffix).csv"
    
    // 生成 CSV 內容
    let csvContent = generateCSVContent(for: building)
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent(fileName)
    
    do {
        try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
        uploadCSVFile(fileURL, for: building)
    } catch {
        showAlert(title: "錯誤", message: "無法建立匯出檔案：\(error.localizedDescription)")
    }
}


private func uploadCSVFile(_ fileURL: URL, for building: Building) {
    NetworkManager.shared.uploadCSV(fileURL: fileURL) { [weak self] success, error in
        DispatchQueue.main.async {
            if success {
                self?.showAlert(title: "成功", message: "\(building.rawValue)的資料已成功上傳到伺服器")
            } else {
                self?.showAlert(title: "錯誤", message: "上傳失敗：\(error?.localizedDescription ?? "未知錯誤")")
            }
        }
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
     // 新增顯示載入中提示的方法
    private func showLoadingAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        
        alert.view.addSubview(loadingIndicator)
        present(alert, animated: true, completion: nil)
    }
    
    // 新增隱藏載入中提示的方法
    private func dismissLoadingAlert() {
        if let alert = presentedViewController as? UIAlertController {
            alert.dismiss(animated: true, completion: nil)
        }
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
    // 顯示加載中提示
    showLoadingAlert(message: "正在處理檔案...")
    
    // 移至背景線程處理
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        do {
            let csvContent = try String(contentsOf: url, encoding: .utf8)
            // 過濾掉空行並分割
            let rows = csvContent.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            // 用於記錄新添加的項目
            var newItems: [ScanItem] = []
            
            // 假設CSV的標題行為：條碼,棟別,戶別,車位號碼,車種,車牌,ETAG
            // 跳過標題行
            for row in rows.dropFirst() {
                // 檢查當前線程是否應該取消操作 (如果 self 已被釋放)
                guard self != nil else { break }
                
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
                    let newItem = ScanItem(
                    code: columns[0],  // 序號
                    time: timeString,
                    building: columns.count > 1 ? columns[1] : nil,      // 棟別
                    household: columns.count > 2 ? columns[2] : nil,     // 戶別
                    parkingNumber: columns.count > 6 ? columns[6] : nil, // 車位號碼
                    carType: columns.count > 7 ? columns[7] : nil,       // 車種
                    carNumber: columns.count > 8 ? columns[8] : nil,     // 車牌
                    etagNumber: columns.count > 9 ? columns[9] : nil,    // ETAG
                    isEdited: false,
                    isSelected: false,
                    owner: columns.count > 3 ? columns[3] : nil,         // 所有權人
                    tenant: columns.count > 4 ? columns[4] : nil,        // 承租人
                    phone: columns.count > 5 ? columns[5] : nil          // 電話
                    )
                    
                    newItems.append(newItem)
                }
            }
            
            // 回到主線程更新UI
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // 關閉加載提示
                self.dismissLoadingAlert()
                
                // 批次添加所有新項目
                if !newItems.isEmpty {
                    self.scannedItems.insert(contentsOf: newItems, at: 0)
                    
                    // 使用批次更新以提高性能
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    self.tableView?.reloadData()
                    CATransaction.commit()
                    
                    self.showAlert(title: "成功", message: "已匯入 \(newItems.count) 筆資料")
                } else {
                    self.showAlert(title: "提示", message: "未找到有效的數據記錄")
                }
            }
            
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.dismissLoadingAlert()
                self.showAlert(title: "錯誤", message: "無法讀取檔案：\(error.localizedDescription)")
            }
        }
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

    private func handleScanCompletion(_ fullScan: String) {
    print("處理掃描結果：\(fullScan)")
    
    if let epcCode = extractEPCCode(from: fullScan)?.uppercased(), !epcCode.isEmpty {
        print("提取的 EPC 碼：\(epcCode)")
        handleScanResult(epcCode: epcCode)
    } else {
        print("無法提取有效的 EPC 碼")
        showAlert(title: "掃描錯誤", message: "無法識別有效的 EPC 碼")
        resetScanner(complete: true)
    }
   }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if let customKeyboard = textField.inputView as? CustomAlphaNumKeyboard {
            customKeyboard.targetTextField = textField
        }
    }
    // 添加這個方法實現 CustomAlphaNumKeyboardDelegate 協議
    func keyboardDidTapDone(text: String?) {
    // 處理鍵盤完成按鈕點擊事件
    if let searchText = text, !searchText.isEmpty {
        performSearch(searchText)
    }
}


    private func showAppInstructions() {
    // 每次都顯示說明，不檢查是否首次啟動
    let alert = UIAlertController(
        title: "使用說明",
        message: "1. APP使用前需先接上HID設備，編輯功能才能正常使用。\n\n2. 需要與主機連接相同WiFi，匯入匯出功能才能正常使用。",
        preferredStyle: .alert
    )
    
    let okAction = UIAlertAction(title: "確認", style: .default, handler: nil)
    alert.addAction(okAction)
    
    // 在主線程中顯示警告框
    DispatchQueue.main.async {
        self.present(alert, animated: true)
    }
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

