//
//  CustomAlphaNumKeyboard.swift
//  ETC_Scanner
//
//  Created by 廖亞丞 on 2025/5/4.
//

import UIKit

protocol CustomAlphaNumKeyboardDelegate: AnyObject {
    func keyboardDidTapDone(text: String?)
}

class CustomAlphaNumKeyboard: UIView {
    weak var targetTextField: UITextField?
    weak var delegate: CustomAlphaNumKeyboardDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupKeys()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupKeys()
    }
    
    private func setupKeys() {
        let keys = [
            "1","2","3","4","5","6","7","8","9","0",
            "Q","W","E","R","T","Y","U","I","O","P",
            "A","S","D","F","G","H","J","K","L",
            "Z","X","C","V","B","N","M"
        ]
        let buttonWidth: CGFloat = 35
        let buttonHeight: CGFloat = 50
        let margin: CGFloat = 5
        
        // 移除所有現有的子視圖
        for subview in self.subviews {
            subview.removeFromSuperview()
        }
        
        // 添加按鍵
        for (index, key) in keys.enumerated() {
            let row = index / 10
            let col = index % 10
            let button = createButton(title: key)
            button.frame = CGRect(
                x: CGFloat(col) * (buttonWidth + margin),
                y: CGFloat(row) * (buttonHeight + margin),
                width: buttonWidth,
                height: buttonHeight
            )
            self.addSubview(button)
        }
        
        // 計算底部按鈕的尺寸和位置
        let bottomButtonWidth = (buttonWidth * 10 + margin * 9) / 2 - margin
        let bottomButtonHeight = buttonHeight
        let bottomButtonY = 4 * (buttonHeight + margin)
        
        // 刪除鍵 - 放在左側
        let deleteButton = UIButton(type: .system)
        deleteButton.setTitle("⌫", for: .normal)
        deleteButton.backgroundColor = UIColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 1.0)
        deleteButton.layer.cornerRadius = 5
        deleteButton.layer.shadowColor = UIColor.black.cgColor
        deleteButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        deleteButton.layer.shadowRadius = 1
        deleteButton.layer.shadowOpacity = 0.2
        deleteButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        deleteButton.frame = CGRect(
            x: 0,
            y: bottomButtonY,
            width: bottomButtonWidth,
            height: bottomButtonHeight
        )
        deleteButton.addTarget(self, action: #selector(deleteBackward), for: .touchUpInside)
        self.addSubview(deleteButton)
        
        // 完成鍵 - 放在右側
        let doneButton = UIButton(type: .system)
        doneButton.setTitle("完成", for: .normal)
        doneButton.backgroundColor = UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1.0)
        doneButton.setTitleColor(.white, for: .normal)
        doneButton.layer.cornerRadius = 5
        doneButton.layer.shadowColor = UIColor.black.cgColor
        doneButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        doneButton.layer.shadowRadius = 1
        doneButton.layer.shadowOpacity = 0.2
        doneButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        doneButton.frame = CGRect(
            x: bottomButtonWidth + margin,
            y: bottomButtonY,
            width: bottomButtonWidth,
            height: bottomButtonHeight
        )
        doneButton.addTarget(self, action: #selector(dismissKeyboard), for: .touchUpInside)
        self.addSubview(doneButton)
        
        // 設定鍵盤大小
        self.frame = CGRect(
            x: 0,
            y: -20,
            width: buttonWidth * 10 + margin * 9,
            height: bottomButtonY + bottomButtonHeight + margin + 20
        )
        self.backgroundColor = UIColor.systemGray6
    }
    
    private func createButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = .white
        button.layer.cornerRadius = 5
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowRadius = 1
        button.layer.shadowOpacity = 0.2
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        button.tag = title.hash
        button.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchUpInside)
        return button
    }
    
    @objc private func buttonPressed(_ sender: UIButton) {
        guard let title = sender.titleLabel?.text else { return }
        insertText(title)
        vibrateButton()
    }
    
    @objc private func deleteBackward() {
        guard let textField = targetTextField else { return }
        let currentText = textField.text ?? ""
        if !currentText.isEmpty {
            textField.text = String(currentText.dropLast())
            // 讓 UITextField 發送 textDidChange 通知
            textField.sendActions(for: .editingChanged)
        }
        vibrateButton()
    }
    
    @objc private func dismissKeyboard() {
        guard let textField = targetTextField else { return }
        
        // 獲取輸入的文字
        let text = textField.text
        
        // 讓文字欄位失去焦點
        textField.resignFirstResponder()
        
        // 觸發代理方法
        delegate?.keyboardDidTapDone(text: text)
        
        vibrateButton()
        
        // 如果在 UIAlertController 中，嘗試關閉 alert
        if let viewController = textField.findViewController(),
           let alertController = viewController.presentedViewController as? UIAlertController {
            alertController.dismiss(animated: true, completion: nil)
        }
    }
    
    private func insertText(_ text: String) {
        guard let textField = targetTextField else { return }
        
        // 直接修改 text 屬性
        textField.text = (textField.text ?? "") + text
        
        // 讓 UITextField 發送 textDidChange 通知
        textField.sendActions(for: .editingChanged)
    }
    
    private func vibrateButton() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// 擴展 UITextField 以便於找到其 ViewController
extension UIView {
    func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
}
