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
struct ScanItem: Codable {
    let code: String           //掃描碼
    var time: String
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
    var selectedItemIndex: Int?
    var filteredItems: [ScanItem] = []
    var isSearching = false
    
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
    
    var scannerTextField: UITextField!
    var scannedItems: [ScanItem] = [] {
        didSet {
        }
    }
    
    var isScanning = false {
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
        
        // 檢查 IBOutlet 連接
        checkIBOutletConnections()
        
        setupUI()
        setupTextField()
        updateSearchButtonTitle()
        customKeyboard = CustomAlphaNumKeyboard()
        customKeyboard.delegate = self
        
        // 每次啟動都顯示說明
        showAppInstructions()
        
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
        
        // 記錄UI佈局信息
        logViewHierarchy()
    }
    // 新增一個檢查方法
    private func checkIBOutletConnections() {
        // 檢查 TableView
        if tableView != nil {
        } else {
        }
        
        // 檢查其他 IBOutlet
    }
    
    
    // MARK: - Setup
    private func setupUI() {
        // 設置UI元素的順序很重要
        setupTopBackground()
        setupStatusArea()
        setupScanningArea()
        setupButtonsArea()
        setupTableView()
        
        // 確認UI設置完成
        
        /* 
         UI改進說明：
         1. 使用UIStackView替代手動計算按鈕位置，確保按鈕在不同設備上均勻分布
         2. 修正掃描器圖片的頂部約束，避免與頂部背景重疊
         3. 優化表格視圖的約束，使用堆疊視圖作為參考點
         4. 添加UI佈局日誌功能，方便在不同設備上調試佈局問題
         5. 確保UI元素設置的順序正確，避免相互依賴問題
         
         這些改進使應用程式在各種iPhone尺寸上都能正確顯示，解決了之前在iPhone 14 Pro等設備上的顯示問題。
         */
    }
    private func setupScanningArea() {
        guard let imageView = scannerImageView,
              let textLabel = scanTextLabel else {
            return
        }
        
        // 檢查圖片是否能夠載入
        let image = UIImage(named: "scanner_background")
        
        imageView.image = image
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        
        // 確保視圖可見
        imageView.isHidden = false
        imageView.alpha = 1.0
        
        // 添加自動佈局約束
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topBackgroundImage?.bottomAnchor ?? view.safeAreaLayoutGuide.topAnchor, constant: 10), // 修改為正值，避免重疊
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            imageView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // 設置掃描文字標籤
        textLabel.text = "等待掃描..."
        textLabel.textColor = .darkGray
        textLabel.backgroundColor = .clear  // 透明背景
        textLabel.textAlignment = .center
        
        // 添加標籤的自動佈局約束
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textLabel.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            textLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            textLabel.widthAnchor.constraint(lessThanOrEqualTo: imageView.widthAnchor, constant: -20),
            textLabel.heightAnchor.constraint(equalToConstant: 35)
        ])
    }
    //頂部圖片
    private func setupTopBackground() {
        guard let topImage = topBackgroundImage else {
            return
        }
        topImage.contentMode = .scaleAspectFill
        topImage.clipsToBounds = true
        
        // 添加自動佈局約束
        topImage.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topImage.topAnchor.constraint(equalTo: view.topAnchor),
            topImage.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topImage.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topImage.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.15) // 高度為視圖高度的15%
        ])
    }
    //狀態
    private func setupStatusArea() {
        guard let status = statusLabel else {
            return
        }
        status.text = "待機中"
        status.textColor = .white
        status.font = .systemFont(ofSize: 14)
        
        // 添加自動佈局約束
        status.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            status.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            status.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            status.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    //按鈕
    private func setupButtonsArea() {
        guard let all = importButton,
              let export = exportButton,
              let delete = deleteButton,
              let search = searchButton else {
            return
        }
        
        // 創建堆疊視圖
        let stackView = UIStackView(arrangedSubviews: [all, search, export, delete])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        // 統一設定所有按鈕的基本屬性
        let buttons = [all, search, export, delete]
        buttons.forEach { button in
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
        search.setTitle("搜尋", for: .normal)
        export.setTitle("匯出", for: .normal)
        delete.setTitle("刪除", for: .normal)
        
        // 刪除按鈕使用紅色背景
        delete.backgroundColor = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0)
        
        // 設置堆疊視圖的約束
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scannerImageView?.bottomAnchor ?? view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.heightAnchor.constraint(equalToConstant: 40)
        ])
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
    
    // 尋找堆疊視圖作為參考點
    let buttonStackView = view.subviews.first(where: { $0 is UIStackView }) as? UIStackView
    
    // 添加自動佈局約束
    table.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        table.topAnchor.constraint(equalTo: buttonStackView?.bottomAnchor ?? view.safeAreaLayoutGuide.topAnchor, constant: 20),
        table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        table.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
    ])
    
}

    // 將編輯視圖控制器的顯示邏輯移到獨立的方法中
    func showEditViewController(for index: Int) {
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
        var isCurrentlySelected = false
        var targetIndex: Int? = nil
        
        // 檢查點擊的項目是否已經被選中
        if isSearching {
            let selectedItem = filteredItems[indexPath.row]
            isCurrentlySelected = selectedItem.isSelected
            targetIndex = scannedItems.firstIndex(where: { $0.code == selectedItem.code && $0.time == selectedItem.time })
        } else {
            isCurrentlySelected = scannedItems[indexPath.row].isSelected
            targetIndex = indexPath.row
        }
        
        // 取消所有項目的選擇
        for i in 0..<scannedItems.count {
            scannedItems[i].isSelected = false
        }
        // 同時清除過濾項目的選擇狀態
        for i in 0..<filteredItems.count {
            filteredItems[i].isSelected = false
        }
        
        // 如果點擊的項目原本未被選中，則選中它
        if !isCurrentlySelected, let index = targetIndex {
            if isSearching {
                // 在搜尋模式下
                scannedItems[index].isSelected = true
                selectedItemIndex = index
                
                // 更新過濾資料中的選擇狀態
                filteredItems[indexPath.row].isSelected = true
            } else {
                // 非搜尋模式下
                scannedItems[index].isSelected = true
                selectedItemIndex = index
            }
        } else {
            // 如果點擊的是已選中的項目，則取消選擇
            selectedItemIndex = nil
        }
        
        // 更新按鈕狀態
        updateButtonStates()
        // 重新加載表格以更新顯示
        tableView.reloadData()
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        // 檢查是否為掃描結束
        if string == "\n" || string == "\r" || string.isEmpty {
            let fullScan = textField.text?.uppercased() ?? ""
            handleScanCompletion(fullScan)
            return false
        }
        
        // 其他字元照常處理
        return true
    }

    // 處理掃描結果的方法
    private func handleScanResult(epcCode: String) {
        
        // 先檢查是否有重複的條碼（排除當前選中的項目）
        var duplicateIndex: Int? = nil
        for (index, item) in scannedItems.enumerated() {
            // 檢查 code 或 etagNumber 是否與掃描的條碼相同
            if (item.code == epcCode || item.etagNumber == epcCode) {
                // 如果是當前選中的項目，跳過
                if let selectedIndex = selectedItemIndex, index == selectedIndex {
                    continue
                }
                duplicateIndex = index
                break
            }
        }
        
        if let selectedIndex = selectedItemIndex {
            // 有選中的項目
            
            // 如果發現重複（不是當前選中的項目）
            if let dupIndex = duplicateIndex {
                DispatchQueue.main.async {
                    let existingItem = self.scannedItems[dupIndex]
                    let message = """
                    此條碼已存在於其他資料中：
                    棟別：\(existingItem.building ?? "")
                    戶別：\(existingItem.household ?? "")
                    車位：\(existingItem.parkingNumber ?? "")
                    
                    是否要繼續更新當前選中的項目？
                    """
                    
                    let alert = UIAlertController(title: "發現重複條碼", message: message, preferredStyle: .alert)
                    
                    // 繼續更新選項
                    alert.addAction(UIAlertAction(title: "繼續更新", style: .destructive) { _ in
                        self.updateSelectedItem(at: selectedIndex, with: epcCode)
                    })
                    
                    // 取消選項
                    alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                        self.resetScanner(complete: true)
                    })
                    
                    self.present(alert, animated: true)
                }
            } else {
                // 沒有重複，直接更新
                updateSelectedItem(at: selectedIndex, with: epcCode)
            }
        } else {
            // 檢查是否已存在相同的條碼（檢查 code 或 etagNumber）
            if let existingIndex = scannedItems.firstIndex(where: { $0.code == epcCode || $0.etagNumber == epcCode }) {
                // 找到重複的條碼，顯示確認對話框
                DispatchQueue.main.async {
                    let existingItem = self.scannedItems[existingIndex]
                    let message = """
                    此條碼已存在於資料中：
                    棟別：\(existingItem.building ?? "")
                    戶別：\(existingItem.household ?? "")
                    車位：\(existingItem.parkingNumber ?? "")
                    
                    是否要覆蓋現有資料？
                    """
                    
                    let alert = UIAlertController(title: "發現重複條碼", message: message, preferredStyle: .alert)
                    
                    // 覆蓋選項
                    alert.addAction(UIAlertAction(title: "覆蓋", style: .destructive) { _ in
                        // 覆蓋現有項目
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
                        let timeString = dateFormatter.string(from: Date())
                        
                        var updatedItem = self.scannedItems[existingIndex]
                        updatedItem.time = timeString
                        updatedItem.isEdited = true
                        self.scannedItems[existingIndex] = updatedItem
                        
                        // 移動到最前面
                        self.scannedItems.remove(at: existingIndex)
                        self.scannedItems.insert(updatedItem, at: 0)
                        
                        self.tableView?.reloadData()
                        
                        // 自動選中覆蓋的項目
                        if let tableView = self.tableView {
                            let indexPath = IndexPath(row: 0, section: 0)
                            tableView.scrollToRow(at: indexPath, at: .top, animated: true)
                            
                            for i in 0..<self.scannedItems.count {
                                self.scannedItems[i].isSelected = (i == 0)
                            }
                            self.selectedItemIndex = 0
                            tableView.reloadData()
                        }
                        
                        self.showAlert(title: "已覆蓋", message: "已更新現有條碼資料")
                        self.resetScanner(complete: true)
                    })
                    
                    // 取消選項
                    alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                        self.resetScanner(complete: true)
                    })
                    
                    self.present(alert, animated: true)
                }
            } else {
                // 創建新項目
                
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
    }

    // 更新選中項目的方法
    private func updateSelectedItem(at index: Int, with epcCode: String) {
        var updatedItem = scannedItems[index]
        updatedItem.etagNumber = epcCode
        updatedItem.isEdited = true
        scannedItems[index] = updatedItem
        
        // 如果在搜尋模式，也要更新 filteredItems
        if isSearching {
            if let filteredIndex = filteredItems.firstIndex(where: { $0.code == updatedItem.code && $0.time == updatedItem.time }) {
                filteredItems[filteredIndex] = updatedItem
            }
        }
        
        // 更新 UI
        DispatchQueue.main.async {
            if self.isSearching {
                // 在搜尋模式下，找到正確的顯示索引
                if let displayIndex = self.filteredItems.firstIndex(where: { $0.code == updatedItem.code && $0.time == updatedItem.time }) {
                    self.tableView?.reloadRows(at: [IndexPath(row: displayIndex, section: 0)], with: .automatic)
                } else {
                    // 如果找不到，重新載入整個表格
                    self.tableView?.reloadData()
                }
            } else {
                // 非搜尋模式，直接使用 index
                self.tableView?.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            }
            self.showAlert(title: "更新成功", message: "ETC 標籤已更新")
            self.resetScanner(complete: true)
        }
    }
    
    // 清除掃描狀態的方法
    
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
     func setupTextField() {
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
                    
                    // 設置計時器，防止長時間卡住
                    var timeoutTimer: Timer?
                    timeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                        DispatchQueue.main.async {
                            guard let self = self else { return }
                            
                            // 檢查是否仍在顯示加載提示
                            if let presentedVC = self.presentedViewController as? UIAlertController,
                               presentedVC.message?.contains("正在獲取檔案列表") == true {
                                self.dismissLoadingAlert()
                                self.showAlert(title: "連接超時", message: "獲取檔案列表超時，請檢查網路連接後重試")
                            }
                        }
                    }
                    
                    NetworkManager.shared.fetchFileList { [weak self] result in
                        // 停止計時器
                        timeoutTimer?.invalidate()
                        timeoutTimer = nil
                        
                        DispatchQueue.main.async {
                            guard let self = self else { return }
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
    
    // 修改隱藏載入中提示的方法
    private func dismissLoadingAlert(completion: (() -> Void)? = nil) {
        if let alert = presentedViewController as? UIAlertController {
            alert.dismiss(animated: true) {
                completion?()
            }
        } else {
            completion?()
        }
    }
    
    // 修改檔案選擇的方法
    private func showFileSelectionAlert(fileList: [FileInfo]) {
        // 確保所有現有的警告框已經消失
        self.dismissLoadingAlert {
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
                    
                    // 先註冊完整性警告通知
                    let notificationName = NSNotification.Name("DownloadIntegrityWarning")
                    var observer: NSObjectProtocol?
                    observer = NotificationCenter.default.addObserver(
                        forName: notificationName,
                        object: nil,
                        queue: .main
                    ) { [weak self] notification in
                        if let warnings = notification.userInfo?["warnings"] as? [String] {
                            let warningMessage = warnings.joined(separator: "\n")
                            self?.showAlert(title: "⚠️ 資料完整性警告", message: warningMessage)
                        }
                    }
                    
                    NetworkManager.shared.downloadCSV(fileName: fileInfo.fileName) { result in
                        DispatchQueue.main.async {
                            // 移除通知觀察者
                            if let observer = observer {
                                NotificationCenter.default.removeObserver(observer)
                            }
                            
                            self?.dismissLoadingAlert {
                                switch result {
                                case .success(let data):
                                    
                                    if let csvString = String(data: data, encoding: .utf8) {
                                        let lines = csvString.components(separatedBy: .newlines)
                                        
                                        // 記錄下載的檔案資訊
                                        print("📥 [伺服器下載] 檔案名稱: \(fileInfo.fileName)")
                                        print("📥 [伺服器下載] 預期大小: \(fileInfo.size) bytes")
                                        print("📥 [伺服器下載] 實際大小: \(data.count) bytes")
                                        print("📥 [伺服器下載] 總行數: \(lines.count)")
                                        
                                        // 檢查檔案完整性
                                        if data.count != fileInfo.size {
                                            let percentage = Double(data.count) * 100.0 / Double(fileInfo.size)
                                            print("⚠️ [伺服器下載] 警告：檔案大小不符，只有預期的 \(String(format: "%.1f", percentage))%")
                                        }
                                        
                                        // 檢查最後一行
                                        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                                        if let lastLine = nonEmptyLines.last {
                                            let commaCount = lastLine.components(separatedBy: ",").count - 1
                                            print("📥 [伺服器下載] 最後一行有 \(commaCount) 個逗號")
                                            if commaCount < 9 {
                                                print("⚠️ [伺服器下載] 警告：最後一行可能不完整，應有 9 個逗號（10 個欄位）")
                                            }
                                        }
                                        
                                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileInfo.fileName)
                                        
                                        do {
                                            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
                                            self?.parseCSV(from: tempURL)
                                        } catch {
                                            self?.showAlert(title: "錯誤", message: "無法處理檔案：\(error.localizedDescription)")
                                        }
                                    } else {
                                        self?.showAlert(title: "錯誤", message: "無法解析 CSV 數據")
                                    }
                                    
                                case .failure(let error):
                                    self?.showAlert(title: "錯誤", message: "無法從伺服器下載：\(error.localizedDescription)")
                                }
                            }
                        }
                    }
                }
                alert.addAction(fileAction)
            }
            
            let cancelAction = UIAlertAction(title: "取消", style: .cancel)
            alert.addAction(cancelAction)
            
            // iPad 需要設置 popoverPresentationController
            if let popover = alert.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            self.present(alert, animated: true)
        }
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
    
    // 先呼叫診斷函數檢查數據
    debugScannedItems()
    
    // 過濾指定棟別的資料
    let filteredItems = scannedItems.filter { item in
        if let itemBuilding = item.building {
            // 店面資料應該包含在兩個檔案中
            if itemBuilding.contains("店面") {
                return true
            }
            
            switch building {
            case .buildingAB:
                return itemBuilding.contains("A") || itemBuilding.contains("B")
            case .buildingCDE:
                return itemBuilding.contains("C") || itemBuilding.contains("D") || itemBuilding.contains("E")
            }
        }
        return false
    }
    
    // 新增：打印過濾後的項目數量
    
    // 生成資料行
    var rows = ""
    for (index, item) in filteredItems.enumerated() {
        rows += generateCSVRow(index: index, item: item)
        rows += "\n"
        
        // 新增：顯示正在生成的行
    }
    
    let fullContent = header + rows
    // 新增：檢查最終內容
    
    return fullContent
}

private enum Building: String, CaseIterable {
   
    case buildingAB = "AB棟"
    case buildingCDE = "CDE棟"
    
    var filenameSuffix: String {
        switch self {
        
        case .buildingAB: return "AB"
        case .buildingCDE: return "CDE"
        }
    }
}
// 6. 匯出按鈕動作
@IBAction func exportButtonTapped(_ sender: UIButton) {
    // 檢查是否有任何資料可匯出
    if scannedItems.isEmpty {
        showAlert(title: "無法匯出", message: "沒有資料可匯出，請先匯入或掃描資料。")
        return
    }
    
    // 顯示操作選項
    let alert = UIAlertController(title: "選擇操作", 
                                message: "請選擇要執行的操作", 
                                preferredStyle: .actionSheet)
    
    // 匯出到伺服器選項
    let exportAction = UIAlertAction(title: "匯出到伺服器", style: .default) { [weak self] _ in
        // 檢查是否有匯入的資料並決定要顯示哪個棟別的選項
        let hasABData = self?.scannedItems.contains { item in
            if let building = item.building {
                return building.contains("A") || building.contains("B")
            }
            return false
        } ?? false
        
        let hasCDEData = self?.scannedItems.contains { item in
            if let building = item.building {
                return building.contains("C") || building.contains("D") || building.contains("E")
            }
            return false
        } ?? false
        
        // 如果只有一種棟別的資料，直接匯出那種棟別
        if hasABData && !hasCDEData {
            self?.exportCSVForBuilding(.buildingAB)
        } else if !hasABData && hasCDEData {
            self?.exportCSVForBuilding(.buildingCDE)
        } else {
            // 兩種都有或都沒有，顯示選擇對話框
            self?.showBuildingSelectionAlert(sender)
        }
    }
    
    // 發送電子郵件選項（修改為直接發送所有資料）
    let emailAction = UIAlertAction(title: "發送電子郵件", style: .default) { [weak self] _ in
        guard let self = self else { return }
        
        // 確認是否要發送所有資料
        let confirmAlert = UIAlertController(title: "確認發送",
                                           message: "您確定要發送所有 \(self.scannedItems.count) 筆資料嗎？",
                                           preferredStyle: .alert)
        
        let confirmAction = UIAlertAction(title: "確定", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            // 使用 EmailManager 顯示發送所有資料對話框
            EmailManager.shared.showSendAllDataDialog(on: self, allItems: self.scannedItems) { success, message in
                if success {
                    self.showAlert(title: "成功", message: message ?? "郵件發送成功")
                } else {
                    self.showAlert(title: "發送失敗", message: message ?? "郵件發送失敗")
                }
            }
        }
        
        let cancelConfirmAction = UIAlertAction(title: "取消", style: .cancel)
        
        confirmAlert.addAction(confirmAction)
        confirmAlert.addAction(cancelConfirmAction)
        
        self.present(confirmAlert, animated: true)
    }
    
    let cancelAction = UIAlertAction(title: "取消", style: .cancel)
    
    alert.addAction(exportAction)
    alert.addAction(emailAction)
    alert.addAction(cancelAction)
    
    // iPad 需要設置 popoverPresentationController
    if let popover = alert.popoverPresentationController {
        popover.sourceView = sender
        popover.sourceRect = sender.bounds
    }
    
    present(alert, animated: true)
    
    // 保留長按手勢
    let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
    longPress.minimumPressDuration = 1.5
    exportButton?.addGestureRecognizer(longPress)
}
// 添加一個時間戳屬性用於雙擊檢測
private var lastTapTime: TimeInterval = 0

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
    // 先過濾該棟別的資料
    let filteredItems = scannedItems.filter { item in
        if let itemBuilding = item.building {
            // 店面資料應該包含在兩個檔案中
            if itemBuilding.contains("店面") {
                return true
            }
            
            switch building {
            case .buildingAB:
                return itemBuilding.contains("A") || itemBuilding.contains("B")
            case .buildingCDE:
                return itemBuilding.contains("C") || itemBuilding.contains("D") || itemBuilding.contains("E")
            }
        }
        return false
    }
    
    // 檢查過濾後是否有資料
    if filteredItems.isEmpty {
        showAlert(title: "無法匯出", message: "\(building.rawValue)沒有資料可匯出。")
        return
    }
    
    // 不再需要加入時間戳，伺服器會自動加上
    // 直接使用簡單的檔名
    let fileName = "ETC_\(building.filenameSuffix)棟資料.csv"
    
    // 記錄最終使用的檔案名稱
    
    // 生成 CSV 內容
    let csvContent = generateCSVContent(for: building)
    
    // 上傳內容
    uploadWithSimpleFileName(content: csvContent, fileName: fileName, for: building)
}

// 使用非常簡單明確的上傳方法，專注於檔案名稱問題
private func uploadWithSimpleFileName(content: String, fileName: String, for building: Building) {

    showLoadingAlert(message: "正在上傳中...")
    
    // 使用原始中文檔名
    let originalFileName = "ETC_\(building.filenameSuffix)棟資料.csv"
    
    
    // 使用 NetworkManager 的方法獲取 URL
    guard let url = NetworkManager.shared.getUploadURL() else {
        self.dismissLoadingAlert()
        self.showAlert(title: "錯誤", message: "無效的上傳 URL")
        return
    }
    
    // 建立正確的 multipart/form-data 請求
    let boundary = "Boundary-\(UUID().uuidString)"
    var request = URLRequest(url: url)
    
    request.httpMethod = "POST"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    request.setValue(NetworkManager.shared.apiKey, forHTTPHeaderField: "x-api-key")
    
    // 建立正確格式的 multipart/form-data 內容
    var data = Data()
    data.append("--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"file\"; filename=\"ETC_\(building.filenameSuffix)棟資料.csv\"\r\n".data(using: .utf8)!)
    data.append("Content-Type: text/csv\r\n\r\n".data(using: .utf8)!)
    data.append(content.data(using: .utf8)!)
    data.append("\r\n".data(using: .utf8)!)

    // 添加一個額外的欄位表示原始檔名（如果伺服器 API 支援）
    data.append("--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"originalFilename\"\r\n\r\n".data(using: .utf8)!)
    data.append("ETC_\(building.filenameSuffix)棟資料.csv".data(using: .utf8)!)
    data.append("\r\n".data(using: .utf8)!)

    data.append("--\(boundary)--\r\n".data(using: .utf8)!)
    
    // 執行上傳任務
    let task = NetworkManager.shared.optimizedSession.uploadTask(with: request, from: data) { [weak self] responseData, response, error in
        DispatchQueue.main.async {
            guard let self = self else { return }
            self.dismissLoadingAlert()
            
            if let error = error {
                self.showUploadResultAlert(success: false, message: error.localizedDescription)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                
                // 嘗試解析伺服器回應
                if let responseData = responseData, let responseString = String(data: responseData, encoding: .utf8) {
                }
                
                let success = (200...299).contains(httpResponse.statusCode)
                if success {
                    // 使用新的方法顯示上傳成功提示
                    self.showUploadResultAlert(success: true, message: "\(building.rawValue)的資料已成功上傳到伺服器")
                } else {
                    self.showUploadResultAlert(success: false, message: "伺服器回應代碼 \(httpResponse.statusCode)")
                }
            } else {
                self.showUploadResultAlert(success: false, message: "無法獲取HTTP回應")
            }
        }
    }
    
    task.resume()
}

// 新增一個專門用於顯示上傳結果的提示框方法
private func showUploadResultAlert(success: Bool, message: String) {
    // 確保在主線程執行
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        
        // 先關閉任何可能正在顯示的警告框
        if let presentedVC = self.presentedViewController {
            presentedVC.dismiss(animated: false) {
                self.showUploadResultAlertImpl(success: success, message: message)
            }
        } else {
            self.showUploadResultAlertImpl(success: success, message: message)
        }
    }
}

private func showUploadResultAlertImpl(success: Bool, message: String) {
    // 建立提示框
    let title = success ? "上傳完成" : "上傳失敗"
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    
    // 添加確認按鈕
    let okAction = UIAlertAction(title: "確定", style: .default)
    alert.addAction(okAction)
    
    // 添加震動反饋
    if success {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    } else {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    // 顯示提示框
    self.present(alert, animated: true) {
        // 確保提示框顯示後的回調
    }
}

// 新增：直接上傳方法（基於測試程式碼）
private func uploadFileDirectly(_ fileURL: URL, completion: @escaping (Bool, Error?) -> Void) {
    // 準備上傳請求
    let boundary = "Boundary-\(UUID().uuidString)"
    
    // 使用 NetworkManager 的方法獲取 URL
    guard let url = NetworkManager.shared.getUploadURL() else {
        completion(false, NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無效的URL"]))
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    // 添加 API 金鑰認證
    request.setValue(NetworkManager.shared.apiKey, forHTTPHeaderField: "x-api-key")
    
    // 創建 multipart/form-data 內容
    var data = Data()
    data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
    data.append("Content-Type: text/csv\r\n\r\n".data(using: .utf8)!)
    
    // 添加檔案內容
    do {
        let fileData = try Data(contentsOf: fileURL)
        
        if fileData.isEmpty {
            completion(false, NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "文件內容為空"]))
            return
        }
        
        data.append(fileData)
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        // 創建上傳任務
        let task = URLSession.shared.uploadTask(with: request, from: data) { data, response, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                
                // 嘗試解析伺服器回應
                if let responseData = data, let responseString = String(data: responseData, encoding: .utf8) {
                }
                
                completion(httpResponse.statusCode >= 200 && httpResponse.statusCode < 300, nil)
            } else {
                completion(false, NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "未收到HTTP回應"]))
            }
        }
        
        task.resume()
        
    } catch {
        completion(false, error)
    }
}
    
    // 新增顯示設定伺服器的彈出視窗方法
    private func showServerSettingsAlert() {
        let alert = UIAlertController(title: "Sui-Yao API 設定", 
                                  message: "請輸入管理員密碼",
                                  preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "******"
            textField.isSecureTextEntry = true
        }

        let confirmAction = UIAlertAction(title: "確認", style: .default) { [weak self] _ in
            guard let password = alert.textFields?[0].text else { return }
            
            // 只檢查密碼是否正確，不再提供URL和API金鑰的編輯功能
            if password == "123456" { // 使用原本設定的管理員密碼
                // 顯示設定已啟用的提示
                self?.showAlert(title: "成功", message: "已啟用管理員權限")
                
                // 觸覺反饋
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
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
        // 確保在主線程執行
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 如果已經顯示了一個警告框，則不再顯示新的警告框
            if self.presentedViewController is UIAlertController {
                return
            }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "確定", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    // 檢查檔案大小的輔助方法
    private func checkFileSize(at url: URL) -> (isValid: Bool, size: Int64) {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let maxSize: Int64 = 50 * 1024 * 1024 // 50MB 限制
            
            return (fileSize <= maxSize, fileSize)
        } catch {
            print("無法獲取檔案大小: \(error)")
            return (false, 0)
        }
    }
    
    private func parseCSV(from url: URL) {
    // 先檢查檔案大小
    let fileSizeCheck = checkFileSize(at: url)
    
    if !fileSizeCheck.isValid {
        let sizeMB = Double(fileSizeCheck.size) / (1024 * 1024)
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "檔案過大",
                message: String(format: "檔案大小為 %.2f MB，超過 50MB 限制。處理大檔案可能導致應用程式當機。是否繼續？", sizeMB),
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            alert.addAction(UIAlertAction(title: "使用串流處理（推薦）", style: .default) { _ in
                self?.parseCSVWithStreamReader(from: url)
            })
            alert.addAction(UIAlertAction(title: "強制載入全部（可能當機）", style: .destructive) { _ in
                self?.performCSVParsing(from: url)
            })
            
            self?.present(alert, animated: true)
        }
        return
    }
    
    // 檔案大小正常，直接處理
    performCSVParsing(from: url)
    }
    
    // 使用串流讀取器處理大型 CSV 檔案
    private func parseCSVWithStreamReader(from url: URL) {
        showLoadingAlert(message: "正在使用串流方式處理檔案...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 記錄檔案資訊
            do {
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = fileAttributes[.size] as? Int64 ?? 0
                print("📊 [CSV串流] 開始串流處理檔案: \(url.lastPathComponent)")
                print("📊 [CSV串流] 檔案大小: \(fileSize) bytes (\(fileSize/1024/1024) MB)")
            } catch {
                print("❌ [CSV串流] 無法獲取檔案資訊: \(error)")
            }
            
            var allNewItems: [ScanItem] = []
            var processedCount = 0
            var duplicateCount = 0
            let batchSize = 100
            
            // 使用串流讀取器批次處理
            CSVStreamReader.processCSVInBatches(
                url: url,
                batchSize: batchSize
            ) { batchItems in
                // 過濾重複項目
                let existingCodes = self.scannedItems.map { $0.code }
                let newCodes = allNewItems.map { $0.code }
                let allExistingCodes = existingCodes + newCodes
                
                let filteredBatchItems = batchItems.filter { item in
                    let isDuplicate = allExistingCodes.contains(item.code)
                    if isDuplicate {
                        duplicateCount += 1
                        print("📊 [CSV串流] 跳過重複條碼: \(item.code)")
                    }
                    return !isDuplicate
                }
                
                allNewItems.append(contentsOf: filteredBatchItems)
                processedCount += batchItems.count
                
                // 更新進度
                DispatchQueue.main.async { [weak self] in
                    let message = duplicateCount > 0 ? 
                        "正在處理檔案... 已處理 \(processedCount) 筆，跳過 \(duplicateCount) 筆重複" :
                        "正在處理檔案... 已處理 \(processedCount) 筆資料"
                    self?.showLoadingAlert(message: message)
                }
            }
            
            // 完成處理，更新 UI
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.dismissLoadingAlert()
                
                if !allNewItems.isEmpty {
                    self.scannedItems.insert(contentsOf: allNewItems, at: 0)
                    
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    self.tableView?.reloadData()
                    CATransaction.commit()
                    
                    // 建立匯入報告
                    var reportMessage = "📊 串流匯入報告\n\n"
                    reportMessage += "處理方式：串流處理\n"
                    reportMessage += "總處理數：\(processedCount) 筆\n"
                    reportMessage += "成功匯入：\(allNewItems.count) 筆\n"
                    if duplicateCount > 0 {
                        reportMessage += "重複跳過：\(duplicateCount) 筆\n"
                    }
                    
                    print("📊 [CSV串流] ========== 串流匯入統計 ==========")
                    print("📊 [CSV串流] 總處理數: \(processedCount) 筆")
                    print("📊 [CSV串流] 成功匯入: \(allNewItems.count) 筆")
                    print("📊 [CSV串流] 重複跳過: \(duplicateCount) 筆")
                    print("📊 [CSV串流] ===================================")
                    
                    let alertTitle = duplicateCount > 0 ? "匯入完成" : "匯入成功"
                    self.showAlert(title: alertTitle, message: reportMessage)
                } else {
                    self.showAlert(title: "提示", message: "未找到有效的數據記錄")
                }
            }
        }
    }
    
    private func performCSVParsing(from url: URL) {
    // 顯示加載中提示
    showLoadingAlert(message: "正在處理檔案...")
    
    // 移至背景線程處理
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        do {
            // 記錄檔案資訊
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            print("📊 [CSV匯入] 開始處理檔案: \(url.lastPathComponent)")
            print("📊 [CSV匯入] 檔案大小: \(fileSize) bytes (\(fileSize/1024) KB)")
            
            let csvContent = try String(contentsOf: url, encoding: .utf8)
            print("📊 [CSV匯入] 檔案內容長度: \(csvContent.count) 字元")
            
            let allLines = csvContent.components(separatedBy: .newlines)
            print("📊 [CSV匯入] 原始行數: \(allLines.count)")
            
            // 改進行分割邏輯，處理各種換行符和檔案末尾情況
            var rows = csvContent.components(separatedBy: .newlines)
            
            // 過濾空行
            let originalRowCount = rows.count
            rows = rows.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let emptyRowCount = originalRowCount - rows.count
            print("📊 [CSV匯入] 有效行數: \(rows.count) (移除 \(emptyRowCount) 空行)")
            
            // 檢查最後一行完整性
            if let lastRow = rows.last {
                let lastRowColumns = lastRow.components(separatedBy: ",").count
                print("📊 [CSV匯入] 最後一行欄位數: \(lastRowColumns)")
                if lastRowColumns < 7 {
                    print("⚠️ [CSV匯入] 警告：最後一行可能不完整，只有 \(lastRowColumns) 個欄位")
                }
            }
            
            // 用於記錄新添加的項目和統計
            var newItems: [ScanItem] = []
            var successCount = 0
            var failedCount = 0
            var duplicateCount = 0
            let batchSize = 100 // 每批處理 100 筆資料
            
            // 判斷檔案是 AB 棟還是 CDE 棟
            var isABBuilding = false
            var isCDEBuilding = false
            
            // 假設CSV的標題行為：條碼,棟別,戶別,車位號碼,車種,車牌,ETAG
            // 跳過標題行
            for (index, row) in rows.dropFirst().enumerated() {
                // 使用 autoreleasepool 確保每次迴圈的記憶體都被釋放
                autoreleasepool {
                    let actualRowNumber = index + 2  // +2 因為跳過標題行且從1開始計數
                    
                    
                    // 檢查當前線程是否應該取消操作 (如果 self 已被釋放)
                    guard self != nil else { 
                        return // 從 autoreleasepool 返回
                    }
                    
                    
                    // 移除多餘的空白
                    let trimmedRow = row.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    
                    guard !trimmedRow.isEmpty else { 
                        return // 從 autoreleasepool 返回
                    }
                    
                    
                    let columns = trimmedRow.components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                
                
                
                // 確保至少有ETC條碼欄位
                
                if columns.count >= 1 && !columns[0].isEmpty {
                    
                    // 檢查是否為重複條碼
                    let isDuplicate = self?.scannedItems.contains { $0.code == columns[0] } ?? false
                    if isDuplicate {
                        duplicateCount += 1
                        print("📊 [CSV匯入] 跳過重複條碼: \(columns[0]) (第 \(actualRowNumber) 行)")
                        return // 跳過重複項目
                    }
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
                    let timeString = dateFormatter.string(from: Date())
                    
                    // 檢查是否有ETC條碼（第10列，索引為9）
                    let hasETCCode = columns.count > 9 && !columns[9].isEmpty
                    
                    // 判斷棟別
                    let building = columns.count > 1 ? columns[1] : ""
                    if building.contains("A") || building.contains("B") {
                        isABBuilding = true
                    }
                    if building.contains("C") || building.contains("D") || building.contains("E") {
                        isCDEBuilding = true
                    }
                    
                    
                    let newItem = ScanItem(
                        code: columns[0],  // 序號
                        time: timeString,
                        building: columns.count > 1 ? columns[1] : nil,      // 棟別
                        household: columns.count > 2 ? columns[2] : nil,     // 戶別
                        parkingNumber: columns.count > 6 ? columns[6] : nil, // 車位號碼
                        carType: columns.count > 7 ? columns[7] : nil,       // 車種
                        carNumber: columns.count > 8 ? columns[8] : nil,     // 車牌
                        etagNumber: columns.count > 9 ? columns[9] : nil,    // ETAG
                        isEdited: hasETCCode,  // 如果有ETC條碼，則標記為已編輯
                        isSelected: false,
                        owner: columns.count > 3 ? columns[3] : nil,         // 所有權人
                        tenant: columns.count > 4 ? columns[4] : nil,        // 承租人
                        phone: columns.count > 5 ? columns[5] : nil          // 電話
                    )
                    
                    newItems.append(newItem)
                    successCount += 1
                    
                    // 每處理 batchSize 筆資料，更新一次進度
                    if newItems.count % batchSize == 0 {
                        let processedCount = newItems.count
                        DispatchQueue.main.async { [weak self] in
                            self?.showLoadingAlert(message: "正在處理檔案... 已處理 \(processedCount) 筆資料")
                        }
                    }
                    
                    } else {
                    failedCount += 1
                    print("📊 [CSV匯入] 無效資料行: 第 \(actualRowNumber) 行，欄位數: \(columns.count)")
                }
                } // autoreleasepool 結束
            }
            
            // 打印匯入統計
            print("📊 [CSV匯入] ========== 匯入統計 ==========")
            print("📊 [CSV匯入] 總行數: \(rows.count) (含標題)")
            print("📊 [CSV匯入] 成功匯入: \(successCount) 筆")
            print("📊 [CSV匯入] 失敗: \(failedCount) 筆")
            print("📊 [CSV匯入] 重複跳過: \(duplicateCount) 筆")
            print("📊 [CSV匯入] ==============================")
            
            // 如果解析到的項目數量與預期不符，顯示詳細資訊
            let expectedCount = rows.count - 1 // 減去標題行
            if newItems.count != expectedCount {
                print("⚠️ [CSV匯入] 警告：預期匯入 \(expectedCount) 筆，實際匯入 \(newItems.count) 筆")
                let missingCount = expectedCount - newItems.count
                if missingCount > 0 {
                    print("⚠️ [CSV匯入] 可能有 \(missingCount) 筆資料未成功匯入或被截斷")
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
                    
                    var buildingType = ""
                    if isABBuilding && !isCDEBuilding {
                        buildingType = "AB棟"
                    } else if !isABBuilding && isCDEBuilding {
                        buildingType = "CDE棟"
                    } else if isABBuilding && isCDEBuilding {
                        buildingType = "混合棟別"
                    }
                    
                    // 建立詳細的匯入報告
                    var reportMessage = "📊 匯入報告\n\n"
                    reportMessage += "檔案類型：\(buildingType)\n"
                    reportMessage += "總行數：\(rows.count) (含標題)\n"
                    reportMessage += "成功匯入：\(successCount) 筆\n"
                    
                    if failedCount > 0 {
                        reportMessage += "失敗：\(failedCount) 筆\n"
                    }
                    if duplicateCount > 0 {
                        reportMessage += "重複跳過：\(duplicateCount) 筆\n"
                    }
                    
                    // 檢查是否有資料截斷
                    if newItems.count != expectedCount {
                        reportMessage += "\n⚠️ 警告：可能存在資料截斷\n"
                        reportMessage += "預期匯入：\(expectedCount) 筆\n"
                        reportMessage += "實際匯入：\(newItems.count) 筆\n"
                        let missingCount = expectedCount - newItems.count - duplicateCount - failedCount
                        if missingCount > 0 {
                            reportMessage += "未知原因遺失：\(missingCount) 筆"
                        }
                    }
                    
                    // 根據結果決定標題
                    let alertTitle = (failedCount > 0 || newItems.count != expectedCount) ? "部分成功" : "匯入成功"
                    self.showAlert(title: alertTitle, message: reportMessage)
                } else {
                    self.showAlert(title: "提示", message: "未找到有效的數據記錄\n\n檔案共有\(rows.count)行（包含標題）")
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
        for (index, line) in lines.enumerated() {
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
        message: "1. APP使用前需先接上HID設備，編輯功能才能正常使用。\n\n2. 網路功能使用Sui-Yao API，請確保網路正常。",
        preferredStyle: .alert
    )
    
    let okAction = UIAlertAction(title: "確認", style: .default, handler: nil)
    alert.addAction(okAction)
    
    // 在主線程中顯示警告框
    DispatchQueue.main.async {
        self.present(alert, animated: true)
    }
}

// MARK: - UI Debugging
private func logViewHierarchy() {
    
    // 記錄主要UI元素的框架
    if let topImage = topBackgroundImage {
    }
    
    if let scanner = scannerImageView {
    }
    
    if let table = tableView {
    }
    
    // 記錄按鈕的位置
    let buttons = [importButton, searchButton, exportButton, deleteButton]
    for (index, button) in buttons.enumerated() {
        if let btn = button {
        }
    }
}
// 添加這個測試函數到 ViewController 類中
private func testFixedContentUpload() {
    // 創建一個有已知內容的 CSV 文件
    let csvContent = """
    序號,棟別,戶別,所有權人,承租人,電話,車位號碼,車種,車牌,ETAG
    1,第1棟,101,張三,李四,0912345678,A101,汽車,ABC-1234,E12345678
    2,第1棟,102,王五,趙六,0923456789,A102,機車,DEF-5678,E87654321
    """
    
    // 保存到臨時文件
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = "test_fixed_content.csv"
    let fileURL = tempDir.appendingPathComponent(fileName)
    
    do {
        try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        // 讀取文件內容確認
        let readContent = try String(contentsOf: fileURL, encoding: .utf8)
        
        // 使用與您測試軟體完全相同的方式上傳
        uploadTestFile(fileURL)
    } catch {
    }
}

private func uploadTestFile(_ fileURL: URL) {
    // 準備上傳請求
    let boundary = "Boundary-\(UUID().uuidString)"
    
    // 使用 NetworkManager 的方法獲取 URL
    guard let url = NetworkManager.shared.getUploadURL() else {
        showAlert(title: "測試上傳失敗", message: "無效的上傳 URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    // 添加 API 金鑰認證
    request.setValue(NetworkManager.shared.apiKey, forHTTPHeaderField: "x-api-key")
    
    // 創建 multipart/form-data 內容
    var data = Data()
    data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
    data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
    data.append("Content-Type: text/csv\r\n\r\n".data(using: .utf8)!)
    
    // 添加檔案內容
    do {
        let fileData = try Data(contentsOf: fileURL)
        
        data.append(fileData)
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        // 創建上傳任務
        let task = NetworkManager.shared.optimizedSession.uploadTask(with: request, from: data) { [weak self] responseData, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.showAlert(title: "測試上傳失敗", message: error.localizedDescription)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        self.showAlert(title: "測試上傳成功", message: "檔案已成功上傳到伺服器")
                    } else {
                        self.showAlert(title: "測試上傳失敗", message: "伺服器回應代碼: \(httpResponse.statusCode)")
                    }
                }
            }
        }
        
        task.resume()
        
    } catch {
    }
}

    private func debugScannedItems() {
        
        for (index, item) in scannedItems.enumerated() {
        }
        
        // 檢查每個棟別的過濾結果
        for building in Building.allCases {
            var count = 0
            switch building {
            case .buildingAB:
                count = scannedItems.filter {
                    if let b = $0.building {
                        return b.contains("A") || b.contains("B") || b.contains("店面")
                    }
                    return false
                }.count
            case .buildingCDE:
                count = scannedItems.filter {
                    if let b = $0.building {
                        return b.contains("C") || b.contains("D") || b.contains("E") || b.contains("店面")
                    }
                    return false
                }.count
            }
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

// 在 NetworkManager 類的末尾添加此擴展
//extension NetworkManager {
    // 使 getBaseURL 方法公開，讓 EmailManager 可以使用
  //  func getBaseURL() -> String {
    //    let url = serverURL.hasSuffix("/") ? String(serverURL.dropLast()) : serverURL
        //return url
    //}
//}




