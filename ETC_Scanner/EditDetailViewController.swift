//
//
//  ETC_Scanner
//
//  Created by 廖亞丞 on 2025/3/6.
//
import UIKit

protocol EditDetailViewControllerDelegate: AnyObject {
    func didUpdateDetails(
        building: String,
        household: String,
        parkingNumber: String,
        carType: String,
        carNumber: String,
        etagNumber: String,
        at index: Int
    )
}


class EditDetailViewController: UIViewController, UITextFieldDelegate {

    private struct KeyboardRules {
        unowned let viewController: EditDetailViewController
        
        init(_ viewController: EditDetailViewController) {
            self.viewController = viewController
        }
        
        func keyboardType(for textField: UITextField) -> UIKeyboardType {
            switch textField {
            case viewController.buildingTextField:
                return .default
            case viewController.householdTextField:
                return .numberPad
            case viewController.parkingNumberTextField:
                return .numberPad
            case viewController.carNumberTextField:
                return .asciiCapable
            case viewController.etagNumberTextField:
                return .asciiCapable
            default:
                return .default
            }
        }
        
        func capitalizationType(for textField: UITextField) -> UITextAutocapitalizationType {
            switch textField {
            case viewController.carNumberTextField:
                return .allCharacters
            default:
                return .none
            }
        }
        
        func shouldChangeCharacters(in textField: UITextField, range: NSRange, string: String) -> Bool {
            switch textField {
            case viewController.parkingNumberTextField:
                let allowedCharacters = CharacterSet.decimalDigits
                let characterSet = CharacterSet(charactersIn: string)
                return allowedCharacters.isSuperset(of: characterSet)
                
            case viewController.carNumberTextField:
                let allowedCharacters = CharacterSet.alphanumerics
                let characterSet = CharacterSet(charactersIn: string)
                return allowedCharacters.isSuperset(of: characterSet) || string.isEmpty
                
            default:
                return true
            }
        }
        
        func nextResponder(after textField: UITextField) -> UITextField? {
            switch textField {
            case viewController.buildingTextField:
                return viewController.householdTextField
            case viewController.householdTextField:
                return viewController.parkingNumberTextField
            case viewController.parkingNumberTextField:
                return viewController.carNumberTextField
            case viewController.carNumberTextField:
                return viewController.etagNumberTextField
            default:
                return nil
            }
        }
    }
    // 1. 在類的頂部添加車種選項數組
    private let carTypes = ["汽車", "機車"]
    // 添加 KeyboardRules 實例
    private lazy var keyboardRules: KeyboardRules = {
        return KeyboardRules(self)
    }()

    // MARK: - IBOutlets
    @IBOutlet weak var buildingTextField: UITextField!      // 棟別
    @IBOutlet weak var householdTextField: UITextField!     // 戶別
    @IBOutlet weak var parkingNumberTextField: UITextField! // 車位號碼
    @IBOutlet var carTypeSegmentControl: UISegmentedControl!
    @IBOutlet weak var carNumberTextField: UITextField!     // 車牌
    @IBOutlet weak var etagNumberTextField: UITextField!    // ETAG
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    // MARK: - Properties
    weak var delegate: EditDetailViewControllerDelegate?
    var itemIndex: Int = 0
    
    // 儲存當前資料
    var currentBuilding: String = ""
    var currentHousehold: String = ""
    var currentParkingNumber: String = ""
    var currentCarType: String = ""
    var currentCarNumber: String = ""
    var currentEtagNumber: String = ""
    
    // 鍵盤狀態追蹤
    private var keyboardIsVisible = false
    private var activeTextField: UITextField?
    
    // 在 class 裡加一個 flag
    private var hasAutoFocused = false
    
    private var customKeyboard: CustomAlphaNumKeyboard!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("EditDetailViewController viewDidLoad 開始")

        // 強制使用淺色模式（與主畫面一致）
        overrideUserInterfaceStyle = .light
        // 加入這行以顯示標題
        title = "編輯住戶資料"

         // 添加點擊手勢識別器
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false  // 讓其他觸摸事件仍然有效
        view.addGestureRecognizer(tapGesture)

        setupUI()
        loadCurrentData()
        setupTextFields() 

        customKeyboard = CustomAlphaNumKeyboard()
        buildingTextField.inputView = customKeyboard
        householdTextField.inputView = customKeyboard
        parkingNumberTextField.inputView = customKeyboard
        carNumberTextField.inputView = customKeyboard

        buildingTextField.delegate = self
        householdTextField.delegate = self
        parkingNumberTextField.delegate = self
        carNumberTextField.delegate = self

        // 註冊鍵盤通知
        NotificationCenter.default.addObserver(self, 
                                              selector: #selector(keyboardWillShow(_:)), 
                                              name: UIResponder.keyboardWillShowNotification, 
                                              object: nil)
        NotificationCenter.default.addObserver(self, 
                                              selector: #selector(keyboardWillHide(_:)), 
                                              name: UIResponder.keyboardWillHideNotification, 
                                              object: nil)

        print("EditDetailViewController viewDidLoad 完成")
        // 設置車種分段控制器
        setupCarTypeSegmentControl()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 確保我們的視圖在顯示時能接收鍵盤事件
        setupKeyboardDismissGesture()
    }

   override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    if !hasAutoFocused {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.buildingTextField.becomeFirstResponder()
        }
        hasAutoFocused = true
    }
}

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 強制關閉鍵盤，避免鍵盤在視圖關閉後仍然顯示
        view.endEditing(true)
        
        // 確保所有文字欄位都失去焦點
        activeTextField?.resignFirstResponder()
        activeTextField = nil
        
        // 取消訂閱通知
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Keyboard Handling
    @objc func keyboardWillShow(_ notification: Notification) {
        keyboardIsVisible = true
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        keyboardIsVisible = false
    }
    
    private func setupKeyboardDismissGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    /// 重新整理文字欄位的輸入視圖以強制系統重新評估是否應該顯示鍵盤
    private func refreshTextFieldInputView() {
        guard let activeField = activeTextField ?? buildingTextField else { return }
        
        // 暫時禁用輸入視圖
        let originalInputView = activeField.inputView
        activeField.inputView = UIView()
        
        // 重新啟用原來的輸入視圖
        activeField.inputView = originalInputView
        
        // 強制更新
        activeField.reloadInputViews()
    }
    
    private func setupUI() {
       
        
        // 設定儲存按鈕 - 明亮的藍綠色
    saveButton.backgroundColor = UIColor(red: 0/255, green: 163/255, blue: 196/255, alpha: 1.0)
    saveButton.setTitleColor(.white, for: .normal)
    saveButton.layer.cornerRadius = 8
    saveButton.clipsToBounds = true
    
    // 設定取消按鈕 - 暗藍灰色
    cancelButton.backgroundColor = UIColor(red: 112/255, green: 128/255, blue: 144/255, alpha: 1.0)
    cancelButton.setTitleColor(.white, for: .normal)
    cancelButton.layer.cornerRadius = 8
    cancelButton.clipsToBounds = true
    
    // 為按鈕添加陰影以增強視覺效果
    [saveButton, cancelButton].forEach { button in
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 3
        button.layer.shadowOpacity = 0.2
        button.layer.masksToBounds = false
    }
    }
    
    private func loadCurrentData() {
        // 載入現有資料
        buildingTextField.text = currentBuilding
        householdTextField.text = currentHousehold
        parkingNumberTextField.text = currentParkingNumber
        carNumberTextField.text = currentCarNumber
        etagNumberTextField.text = currentEtagNumber
    }
    
     private func setupTextFields() {
        let textFields = [
            buildingTextField,
            householdTextField,
            parkingNumberTextField,
            carNumberTextField,
            etagNumberTextField
        ]
        
        textFields.forEach { textField in
            guard let textField = textField else { return }
            
            // 基本設定
            textField.delegate = self
            textField.backgroundColor = .white
            textField.borderStyle = .roundedRect
            textField.layer.cornerRadius = 8
            textField.font = .systemFont(ofSize: 16)
            textField.isEnabled = true
            textField.isUserInteractionEnabled = true
            textField.returnKeyType = .next
            textField.layer.borderColor = UIColor.systemGray4.cgColor
            textField.layer.borderWidth = 1
            
            // 套用鍵盤規則
            textField.keyboardType = keyboardRules.keyboardType(for: textField)
            textField.autocapitalizationType = keyboardRules.capitalizationType(for: textField)
            
            // 添加文字變更通知
            textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        }
    
            // 特殊設定
            householdTextField.backgroundColor = UIColor(red: 240/255, green: 248/255, blue: 255/255, alpha: 1.0)
            householdTextField.placeholder = "請輸入戶別（主要識別資訊）"
    
            etagNumberTextField.returnKeyType = .done
            etagNumberTextField.isEnabled = false
            etagNumberTextField.backgroundColor = UIColor.systemGray6
    
             // 為數字鍵盤添加工具列
            let toolbar = UIToolbar()
             toolbar.sizeToFit()
            let doneButton = UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(doneButtonTapped))
            let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
             toolbar.items = [flexSpace, doneButton]
    
           [householdTextField, parkingNumberTextField].forEach { textField in
            textField?.inputAccessoryView = toolbar
    }
}
    
    // 新增：處理數字鍵盤的完成按鈕
    @objc private func doneButtonTapped() {
       view.endEditing(true)  // 改為關閉所有鍵盤
    }
    // 新增：處理點擊背景關閉鍵盤
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
         super.touchesBegan(touches, with: event)
    view.endEditing(true)  // 強制結束編輯狀態，收起鍵盤
}
    
    // MARK: - IBActions
    @IBAction func saveButtonTapped(_ sender: Any) {
        // 驗證必填欄位
        guard !currentCarNumber.isEmpty else {
            showAlert(message: "請輸入車牌號碼")
            return
        }
        // 從文本字段獲取最新值
         currentBuilding = buildingTextField.text ?? ""
         currentHousehold = householdTextField.text ?? ""
         currentParkingNumber = parkingNumberTextField.text ?? ""
         currentCarNumber = carNumberTextField.text ?? ""
         currentEtagNumber = etagNumberTextField.text ?? ""
    
    // 從分段控制器獲取車種值
         let selectedIndex = carTypeSegmentControl.selectedSegmentIndex
         currentCarType = selectedIndex >= 0 ? carTypes[selectedIndex] : "汽車"
        
        // 通知代理更新資料
        delegate?.didUpdateDetails(
            building: currentBuilding,
            household: currentHousehold,
            parkingNumber: currentParkingNumber,
            carType: currentCarType,
            carNumber: currentCarNumber,
            etagNumber: currentEtagNumber,
            at: itemIndex
        )
        
        dismiss(animated: true)
    }
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        dismiss(animated: true)
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - UITextFieldDelegate
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return keyboardRules.shouldChangeCharacters(in: textField, range: range, string: string)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let nextField = keyboardRules.nextResponder(after: textField) {
            nextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        customKeyboard.targetTextField = textField
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        // 文字欄位編輯結束時更新相應的變數
        textFieldDidChange(textField)
        
        // 清除目前活動的文字欄位記錄
        if activeTextField == textField {
            activeTextField = nil
        }
    }
    @objc func textFieldDidChange(_ textField: UITextField) {
        switch textField {
        case buildingTextField:
            currentBuilding = textField.text ?? ""
        case householdTextField:
            currentHousehold = textField.text ?? ""
        case parkingNumberTextField:
            currentParkingNumber = textField.text ?? ""
        case carNumberTextField:
            currentCarNumber = textField.text ?? ""
        case etagNumberTextField:
            currentEtagNumber = textField.text ?? ""
        default:
            break
        }
    }

    private func ensureTextFieldIsFocused() {
        if !buildingTextField.isFirstResponder {
            buildingTextField.becomeFirstResponder()
        }
    }

    @objc func applicationWillEnterForeground() {
        ensureTextFieldIsFocused()
    }

    private func startFocusCheck() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.ensureTextFieldIsFocused()
        }
    }
   // 3. 添加設置分段控制器的方法
    private func setupCarTypeSegmentControl() {
    // 設置初始選中項
    if currentCarType == "機車" {
        carTypeSegmentControl.selectedSegmentIndex = 1
    } else {
        // 預設為汽車
        carTypeSegmentControl.selectedSegmentIndex = 0
        
        // 如果當前值不是「汽車」也不是空值，記錄日誌
        if !currentCarType.isEmpty && currentCarType != "汽車" {
            print("注意：當前車種「\(currentCarType)」不是標準值，已設置為「汽車」")
            currentCarType = "汽車"
        } else if currentCarType.isEmpty {
            // 如果為空，設為汽車
            currentCarType = "汽車"
        }
    }
    
    // 添加值變更事件
    carTypeSegmentControl.addTarget(self, action: #selector(carTypeChanged), for: .valueChanged)
}

// 4. 添加處理車種變更的方法
    @objc private func carTypeChanged() {
    let selectedIndex = carTypeSegmentControl.selectedSegmentIndex
    currentCarType = carTypes[selectedIndex]
    
    // 可選：添加觸覺反饋
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
}
}
    


 
