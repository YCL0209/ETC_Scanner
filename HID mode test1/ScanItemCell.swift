//
//  ScanItemCell.swift
//  HID mode test1
//
//  Created by 廖亞丞 on 2025/3/4.
//


import UIKit

class ScanItemCell: UITableViewCell {
    static let identifier = "ScanItemCell"
    
    // MARK: - UI Elements
    let checkboxButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(systemName: "square"), for: .normal)
        button.setImage(UIImage(systemName: "checkmark.square.fill"), for: .selected)
        button.tintColor = .systemGray3
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    // 添加編輯按鈕回調
    var onEditButtonTapped: (() -> Void)?

    let codeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let carLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .systemGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let editButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "pencil"), for: .normal)
        button.tintColor = .systemGray
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemGray
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemGray
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let editedStatusImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemGreen
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .white
        selectionStyle = .none
        
        // 為編輯按鈕添加點擊事件
        editButton.addTarget(self, action: #selector(editButtonTapped), for: .touchUpInside)
        
        // 添加所有子視圖
        contentView.addSubview(checkboxButton)
        contentView.addSubview(codeLabel)
        contentView.addSubview(carLabel)
        contentView.addSubview(editButton)
        contentView.addSubview(dateLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(editedStatusImageView)
        contentView.addSubview(detailsLabel)
        
        NSLayoutConstraint.activate([
            // 勾選框
            checkboxButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            checkboxButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkboxButton.widthAnchor.constraint(equalToConstant: 24),
            checkboxButton.heightAnchor.constraint(equalToConstant: 24),
            
            // 條碼標籤
            codeLabel.leadingAnchor.constraint(equalTo: checkboxButton.trailingAnchor, constant: 12),
            codeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            codeLabel.trailingAnchor.constraint(lessThanOrEqualTo: dateLabel.leadingAnchor, constant: -8),
            
            // 車牌標籤
            carLabel.leadingAnchor.constraint(equalTo: codeLabel.leadingAnchor),
            carLabel.topAnchor.constraint(equalTo: codeLabel.bottomAnchor, constant: 8),
            
            // 編輯按鈕
            editButton.leadingAnchor.constraint(equalTo: carLabel.trailingAnchor, constant: 8),
            editButton.centerYAnchor.constraint(equalTo: carLabel.centerYAnchor),
            editButton.widthAnchor.constraint(equalToConstant: 20),
            editButton.heightAnchor.constraint(equalToConstant: 20),
            
            // 日期標籤
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            dateLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            dateLabel.widthAnchor.constraint(equalToConstant: 80),
            
            // 時間標籤
            timeLabel.trailingAnchor.constraint(equalTo: dateLabel.trailingAnchor),
            timeLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            timeLabel.widthAnchor.constraint(equalToConstant: 80),
            
            // 編輯狀態圖示
            editedStatusImageView.centerYAnchor.constraint(equalTo: carLabel.centerYAnchor),
            editedStatusImageView.leadingAnchor.constraint(equalTo: editButton.trailingAnchor, constant: 8),
            editedStatusImageView.widthAnchor.constraint(equalToConstant: 16),
            editedStatusImageView.heightAnchor.constraint(equalToConstant: 16),
            
            // 詳細資訊標籤
            detailsLabel.leadingAnchor.constraint(equalTo: carLabel.leadingAnchor),
            detailsLabel.topAnchor.constraint(equalTo: carLabel.bottomAnchor, constant: 8),
            detailsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            detailsLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
        // 加入這兩行來確保標籤可見
            codeLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            codeLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        codeLabel.text = nil
        carLabel.text = nil
        dateLabel.text = nil
        timeLabel.text = nil
        detailsLabel.text = nil
        checkboxButton.isSelected = false
        editedStatusImageView.isHidden = true
    }
    
    func configure(with item: ScanItem) {
    // 顯示戶別為主標題（如果有的話），否則顯示「未設置戶別」
    codeLabel.text = item.household?.isEmpty == false ? item.household : "未設置戶別"
    
    // 顯示ETC條碼為副標題
    carLabel.text = "ETC: \(item.code)"
    
    // 分割時間字串
    let timeComponents = item.time.split(separator: " ")
    if timeComponents.count == 2 {
        dateLabel.text = String(timeComponents[0])
        timeLabel.text = String(timeComponents[1])
    }
    
    if item.isEdited {
        editedStatusImageView.image = UIImage(systemName: "checkmark.circle.fill")
        editedStatusImageView.isHidden = false
    } else {
        editedStatusImageView.isHidden = true
    }
    
    var details: [String] = []
    if let building = item.building, !building.isEmpty {
        details.append("棟別: \(building)")
    }
    if let parkingNumber = item.parkingNumber, !parkingNumber.isEmpty {
        details.append("車位: \(parkingNumber)")
    }
    if let carNumber = item.carNumber, !carNumber.isEmpty {
        details.append("車牌: \(carNumber)")
    }
    
    detailsLabel.text = details.joined(separator: " | ")
    detailsLabel.isHidden = details.isEmpty
    
    checkboxButton.isSelected = item.isSelected
    // 設置編輯狀態
    editedStatusImageView.isHidden = !item.isEdited

}
    @objc private func editButtonTapped() {
        onEditButtonTapped?()
    }
}