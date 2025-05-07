import UIKit

class CustomAlphaNumKeyboard: UIView {
    weak var targetTextField: UITextField?

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
        let buttonHeight: CGFloat = 40
        let margin: CGFloat = 5

        for (index, key) in keys.enumerated() {
            let row = index / 10
            let col = index % 10
            let button = UIButton(type: .system)
            button.setTitle(key, for: .normal)
            button.frame = CGRect(
                x: CGFloat(col) * (buttonWidth + margin),
                y: CGFloat(row) * (buttonHeight + margin),
                width: buttonWidth,
                height: buttonHeight
            )
            button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
            self.addSubview(button)
        }

        // 刪除鍵
        let deleteButton = UIButton(type: .system)
        deleteButton.setTitle("⌫", for: .normal)
        deleteButton.frame = CGRect(x: 0, y: 4 * (buttonHeight + margin), width: buttonWidth * 2, height: buttonHeight)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        self.addSubview(deleteButton)

        // 完成鍵
        let doneButton = UIButton(type: .system)
        doneButton.setTitle("完成", for: .normal)
        doneButton.frame = CGRect(x: buttonWidth * 2 + margin * 2, y: 4 * (buttonHeight + margin), width: buttonWidth * 2, height: buttonHeight)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        self.addSubview(doneButton)

        // 設定鍵盤大小
        self.frame = CGRect(x: 0, y: 0, width: buttonWidth * 10 + margin * 9, height: buttonHeight * 5 + margin * 4)
        self.backgroundColor = UIColor.systemGray6
    }

    @objc private func keyTapped(_ sender: UIButton) {
        guard let key = sender.titleLabel?.text else { return }
        targetTextField?.insertText(key)
    }

    @objc private func deleteTapped() {
        targetTextField?.deleteBackward()
    }

    @objc private func doneTapped() {
        targetTextField?.resignFirstResponder()
    }
}
