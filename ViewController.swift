// 修改 viewDidLoad 方法
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
    
    // 顯示首次啟動說明
    showFirstTimeInstructions()
    
    print("viewDidLoad 完成")
}

// 修改 setupTextField 方法
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
    
    // 關鍵改動：不要自動顯示鍵盤，無論連接狀態如何
    // 移除下面的代碼:
    // DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
    //     self.scannerTextField.becomeFirstResponder()
    // }
}

// 修改 viewWillAppear 方法
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // 確保方向鎖定在直向
    AppDelegate.AppUtility.lockOrientation(.portrait)
    
    // 延遲執行以確保視圖已加載
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        // 重新設置掃描器，但不要使其成為第一響應者
        self.setupTextField()
    }
}

// 添加一個常量作為 UserDefaults 的鍵
private let firstLaunchKey = "ETC_Scanner_FirstLaunch"

// 添加顯示首次啟動說明的方法
private func showFirstTimeInstructions() {
    // 檢查是否是首次啟動
    if UserDefaults.standard.bool(forKey: firstLaunchKey) == false {
        // 是首次啟動，顯示說明
        let alert = UIAlertController(
            title: "使用說明",
            message: "此APP需要連接上HID設備以及WiFi才能正確使用。請確保您的設備已正確連接，並且網絡可用。",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "確認", style: .default) { _ in
            // 設置首次啟動標誌
            UserDefaults.standard.set(true, forKey: self.firstLaunchKey)
            UserDefaults.standard.synchronize()
        }
        
        alert.addAction(okAction)
        
        // 確保在主線程中顯示警告框
        DispatchQueue.main.async {
            self.present(alert, animated: true)
        }
    }
}

// 移除 ensureTextFieldIsFocused 方法中的自動聚焦
private func ensureTextFieldIsFocused() {
    // 移除下面的代碼:
    // if !scannerTextField.isFirstResponder {
    //     scannerTextField.becomeFirstResponder()
    // }
}

// 修改 applicationWillEnterForeground 方法
@objc private func applicationWillEnterForeground() {
    // 移除下面的代碼:
    // DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    //     if !self.scannerTextField.isFirstResponder {
    //         self.scannerTextField.becomeFirstResponder()
    //     }
    // }
}

// 在 viewDidDisappear 方法中添加以下代碼
override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    
    // 確保離開主頁面時，scannerTextField 不再是第一響應者
    if scannerTextField.isFirstResponder {
        scannerTextField.resignFirstResponder()
    }
    
    // 移除可能的通知觀察者，避免記憶體洩漏
    NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
}

// 新增確保掃描器焦點的統一方法
private func ensureScannerFocus() {
    // 確保掃描器是第一響應者，但只有在沒有顯示其他視圖控制器的情況下
    if !scannerTextField.isFirstResponder && presentedViewController == nil {
        DispatchQueue.main.async {
            self.scannerTextField.becomeFirstResponder()
        }
    }
}

private func updateStatusLabel() {
// ... existing code ...
}

// 完全重置掃描器狀態的方法
private func completelyResetScannerState() {
    print("完全重置掃描器狀態")
    
    // 強制釋放焦點
    scannerTextField.resignFirstResponder()
    
    // 清空文本
    scannerTextField.text = ""
    scanTextLabel?.text = "等待掃描..."
    
    // 延遲一段時間後重新獲取焦點
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        // 檢查是否仍在主頁面
        if self.presentedViewController == nil {
            print("重新啟用掃描器")
            self.scannerTextField.becomeFirstResponder()
        }
    }
}

// 在 ViewController 類的宣告中添加協議
class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIDocumentPickerDelegate, EditDetailViewControllerDelegate, CustomAlphaNumKeyboardDelegate {
    
    // ... 其他代碼 ...
    
    // 2. 實現協議要求的方法
    func keyboardDidTapDone(text: String?) {
        // 處理完成按鈕點擊事件
        if let searchText = text, !searchText.isEmpty {
            performSearch(searchText)
        }
    }
    
    // 修改 showSearchDialog 方法
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
            customKeyboard.delegate = self
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
    
    // ... 其他代碼 ...
}

// 可以添加一個方法用於重置首次啟動標誌（測試用）
func resetFirstLaunchFlag() {
    UserDefaults.standard.set(false, forKey: firstLaunchKey)
    UserDefaults.standard.synchronize()
}

// 添加設備連接狀態檢測方法
private func checkDeviceConnection() {
    // 這裡實現您的設備連接檢測邏輯
    // 例如：檢查藍牙連接、USB連接等
    
    let isConnected = false // 替換為實際的檢測邏輯
    
    // 更新 UI 以反映連接狀態
    updateConnectionStatus(connected: isConnected)
}

// 更新連接狀態的方法
private func updateConnectionStatus(connected: Bool) {
    statusLabel?.text = connected ? "已連接設備" : "未連接設備"
    statusLabel?.textColor = connected ? .systemGreen : .red
} 