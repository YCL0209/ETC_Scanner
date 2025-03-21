//
//
//  HID mode test1
//
//  Created by 廖亞丞 on 2025/3/6.
//
import UIKit

protocol EditDetailViewControllerDelegate: AnyObject {
    func didUpdateDetails(carNumber: String, residentNumber: String, parkingCount: String, at index: Int)
}

class EditDetailViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var carNumberLabel: UILabel!
    @IBOutlet weak var carNumberTextField: UITextField!
    @IBOutlet weak var residentNumberLabel: UILabel!
    @IBOutlet weak var residentNumberTextField: UITextField!
    @IBOutlet weak var parkingCountLabel: UILabel!
    @IBOutlet weak var parkingCountTextField: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    // MARK: - Properties
    weak var delegate: EditDetailViewControllerDelegate?
    var itemIndex: Int = 0
    var currentCarNumber: String = ""
    var currentResidentNumber: String = ""
    var currentParkingCount: String = ""

    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("EditDetailViewController viewDidLoad 開始")
        setupUI()
        loadCurrentData()
        print("EditDetailViewController viewDidLoad 完成")
        setupTextFields() 
    }
    
    
    private func setupUI() {
        // 設置標籤
        carNumberLabel.text = "車牌號碼:"
        residentNumberLabel.text = "住戶號:"
        parkingCountLabel.text = "車位數量:"
        
        // 設置文字欄位
        carNumberTextField.placeholder = "輸入車牌"
        residentNumberTextField.placeholder = "輸入住戶號"
        parkingCountTextField.placeholder = "輸入車位數量"
        
        // 設置數字鍵盤
        parkingCountTextField.keyboardType = .numberPad
        
        // 設置按鈕
        saveButton.setTitle("儲存", for: .normal)
        saveButton.backgroundColor = .systemTeal
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 5
        
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.backgroundColor = .systemTeal
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.layer.cornerRadius = 5
    }
    
     private func loadCurrentData() {
        // 如果有現有的資料，就填入對應的欄位
        carNumberTextField.text = currentCarNumber
        residentNumberTextField.text = currentResidentNumber
        parkingCountTextField.text = currentParkingCount
    }

    private func setupTextFields() {
        // 確保文字欄位可以編輯
        carNumberTextField.isEnabled = true
        carNumberTextField.isUserInteractionEnabled = true
        
        residentNumberTextField.isEnabled = true
        residentNumberTextField.isUserInteractionEnabled = true
        
        parkingCountTextField.isEnabled = true
        parkingCountTextField.isUserInteractionEnabled = true
        
        // 設置代理
        carNumberTextField.delegate = self
        residentNumberTextField.delegate = self
        parkingCountTextField.delegate = self
        
        // 設置鍵盤類型
        carNumberTextField.keyboardType = .default
        residentNumberTextField.keyboardType = .default
        parkingCountTextField.keyboardType = .numberPad
        
        // 設置返回鍵類型
        carNumberTextField.returnKeyType = .next
        residentNumberTextField.returnKeyType = .next
        parkingCountTextField.returnKeyType = .done
        
        // 設置背景和邊框
        [carNumberTextField, residentNumberTextField, parkingCountTextField].forEach { textField in
            textField?.backgroundColor = .systemBackground
            textField?.borderStyle = .roundedRect
            textField?.layer.borderColor = UIColor.systemGray4.cgColor
            textField?.layer.borderWidth = 1
            textField?.layer.cornerRadius = 5
        }
    }
    
    // MARK: - Actions
    @IBAction func saveTapped(_ sender: UIButton) {
        let carNumber = carNumberTextField.text ?? ""
        let residentNumber = residentNumberTextField.text ?? ""
        let parkingCount = parkingCountTextField.text ?? ""
        
        // 驗證輸入
        guard !carNumber.isEmpty else {
            showAlert(message: "請輸入車牌號碼")
            return
        }
        
        // 通知委派並關閉頁面
        // 修改這裡，加入 itemIndex
        delegate?.didUpdateDetails(
            carNumber: carNumber,
            residentNumber: residentNumber,
            parkingCount: parkingCount,
            at: itemIndex
        )
        
        dismiss(animated: true)
    }
    
    @IBAction func cancelTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }
}
// 添加 UITextFieldDelegate 擴展
extension EditDetailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case carNumberTextField:
            residentNumberTextField.becomeFirstResponder()
        case residentNumberTextField:
            parkingCountTextField.becomeFirstResponder()
        case parkingCountTextField:
            textField.resignFirstResponder()
        default:
            break
        }
        return true
    }
}