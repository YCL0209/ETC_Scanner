//
//
//  HID mode test1
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

class EditDetailViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var buildingTextField: UITextField!      // 棟別
    @IBOutlet weak var householdTextField: UITextField!     // 戶別
    @IBOutlet weak var parkingNumberTextField: UITextField! // 車位號碼
    @IBOutlet weak var carTypeTextField: UITextField!       // 車種
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


        // 自動聚焦到第一個輸入欄位
        buildingTextField.becomeFirstResponder()


        print("EditDetailViewController viewDidLoad 完成")
         
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
        carTypeTextField.text = currentCarType
        carNumberTextField.text = currentCarNumber
        etagNumberTextField.text = currentEtagNumber
    }
    
    private func setupTextFields() {
    let textFields = [
        buildingTextField,
        householdTextField,
        parkingNumberTextField,
        carTypeTextField,
        carNumberTextField,
        etagNumberTextField
    ]
    
    // 設定所有輸入框的基本樣式
    textFields.forEach { textField in
        textField?.delegate = self
        textField?.backgroundColor = .white
        textField?.borderStyle = .roundedRect
        textField?.layer.cornerRadius = 8
        textField?.font = .systemFont(ofSize: 16)
        textField?.isEnabled = true
        textField?.isUserInteractionEnabled = true
        textField?.returnKeyType = .next
        textField?.layer.borderColor = UIColor.systemGray4.cgColor
        textField?.layer.borderWidth = 1
    }
    
    // 特殊設定 - 醒目的戶別輸入框
    householdTextField.backgroundColor = UIColor(red: 240/255, green: 248/255, blue: 255/255, alpha: 1.0)
    householdTextField.placeholder = "請輸入戶別（主要識別資訊）"
    
    // 其他欄位設定
    etagNumberTextField.returnKeyType = .done
    etagNumberTextField.isEnabled = false  // 禁止直接編輯ETAG，只能通過掃描更新
    etagNumberTextField.backgroundColor = UIColor.systemGray6
    
    carNumberTextField.autocapitalizationType = .allCharacters  // 自動轉大寫
    carNumberTextField.keyboardType = .asciiCapable  // 英數鍵盤
    carNumberTextField.placeholder = "請輸入車牌號碼"  // 提示文字
    
    parkingNumberTextField.keyboardType = .numberPad
    
    // 添加工具列（針對數字鍵盤）
    let toolbar = UIToolbar()
    toolbar.sizeToFit()
    let doneButton = UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(doneButtonTapped))
    let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    toolbar.items = [flexSpace, doneButton]
    parkingNumberTextField.inputAccessoryView = toolbar
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
    // 添加手勢識別器的動作方法
    @objc private func dismissKeyboard() {
    view.endEditing(true)  // 收起鍵盤
}      
    

     // MARK: - IBActions
    @IBAction func saveButtonTapped(_ sender: Any) {
        // 驗證必填欄位
        guard let carNumber = carNumberTextField.text, !carNumber.isEmpty else {
            showAlert(message: "請輸入車牌號碼")
            return
        }
        
        // 通知代理更新資料
        delegate?.didUpdateDetails(
            building: buildingTextField.text ?? "",
            household: householdTextField.text ?? "",
            parkingNumber: parkingNumberTextField.text ?? "",
            carType: carTypeTextField.text ?? "",
            carNumber: carNumber,
            etagNumber: etagNumberTextField.text ?? "",
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
}
   // MARK: - UITextFieldDelegate
    extension EditDetailViewController: UITextFieldDelegate {
         func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case buildingTextField:
            householdTextField.becomeFirstResponder()
        case householdTextField:
            parkingNumberTextField.becomeFirstResponder()
        case parkingNumberTextField:
            carTypeTextField.becomeFirstResponder()
        case carTypeTextField:
            carNumberTextField.becomeFirstResponder()
        case carNumberTextField:
            etagNumberTextField.becomeFirstResponder()
        case etagNumberTextField:
            textField.resignFirstResponder()  // 收起鍵盤
        default:
            textField.resignFirstResponder()  // 確保所有其他可能的輸入框也能收起鍵盤
        }
        return true
    }
    
     // 新增：限制車位數量只能輸入數字
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    if textField == parkingNumberTextField {  // 改為新的變數名稱
        // 車位號碼只能輸入數字
        let allowedCharacters = CharacterSet.decimalDigits
        let characterSet = CharacterSet(charactersIn: string)
        return allowedCharacters.isSuperset(of: characterSet)
    } else if textField == carNumberTextField {
        // 車牌號碼只能輸入英文和數字
        let allowedCharacters = CharacterSet.alphanumerics
        let characterSet = CharacterSet(charactersIn: string)
        return allowedCharacters.isSuperset(of: characterSet) || string.isEmpty
    }
    return true
    }
    }
