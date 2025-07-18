//
//  ScanItemCell.swift
//  ETC_Scanner
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
        imageView.tintColor = UIColor.systemTeal
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
    
    // 添加左側彩色邊條
    let editedSideBar: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemTeal
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // 改善編輯圖示
    let editedBadgeView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemTeal
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let editedIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark.circle.fill")
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
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
        contentView.addSubview(editedSideBar)
        contentView.addSubview(editedBadgeView)
        editedBadgeView.addSubview(editedIconImageView)
        
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
            detailsLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            // 左側彩色邊條
            editedSideBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            editedSideBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            editedSideBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            editedSideBar.widthAnchor.constraint(equalToConstant: 4),
            
            // 編輯徽章
            editedBadgeView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            editedBadgeView.trailingAnchor.constraint(equalTo: dateLabel.leadingAnchor, constant: -8),
            editedBadgeView.widthAnchor.constraint(equalToConstant: 24),
            editedBadgeView.heightAnchor.constraint(equalToConstant: 24),
            
            // 編輯圖示
            editedIconImageView.centerXAnchor.constraint(equalTo: editedBadgeView.centerXAnchor),
            editedIconImageView.centerYAnchor.constraint(equalTo: editedBadgeView.centerYAnchor),
            editedIconImageView.widthAnchor.constraint(equalToConstant: 16),
            editedIconImageView.heightAnchor.constraint(equalToConstant: 16)
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
        
        // 重置視覺狀態
        backgroundColor = .white
        contentView.backgroundColor = .white
        layer.borderWidth = 0
        layer.cornerRadius = 0
        codeLabel.textColor = .label
        codeLabel.font = .systemFont(ofSize: 16)
        checkboxButton.tintColor = .systemGray3
        checkboxButton.transform = .identity
    }
    
    func configure(with item: ScanItem) {
        // 顯示戶別為主標題（如果有的話），否則顯示「未設置戶別」
        codeLabel.text = item.household?.isEmpty == false ? item.household : "未設置戶別"
        
        // 顯示ETC條碼為副標題，如果有更新的 etagNumber 則顯示 etagNumber
        if let etagNumber = item.etagNumber, !etagNumber.isEmpty {
            carLabel.text = "ETC: \(etagNumber)"
        } else {
            carLabel.text = "ETC: \(item.code)"
        }
        
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
        
        // 設置選擇狀態的視覺效果
        if item.isSelected {
            // 選中狀態：淺藍色背景
            backgroundColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
            contentView.backgroundColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
            
            // 添加藍色邊框
            layer.borderColor = UIColor.systemBlue.cgColor
            layer.borderWidth = 2.0
            layer.cornerRadius = 8.0
            
            // 讓主標題文字更突出
            codeLabel.textColor = UIColor.systemBlue
            codeLabel.font = .boldSystemFont(ofSize: 16)
            
            // 讓勾選框更明顯
            checkboxButton.tintColor = UIColor.systemBlue
            checkboxButton.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            
        } else {
            // 未選中狀態：白色背景
            backgroundColor = .white
            contentView.backgroundColor = .white
            
            // 移除邊框
            layer.borderWidth = 0
            layer.cornerRadius = 0
            
            // 恢復原始文字樣式
            codeLabel.textColor = .label
            codeLabel.font = .systemFont(ofSize: 16)
            
            // 恢復勾選框原始樣式
            checkboxButton.tintColor = .systemGray3
            checkboxButton.transform = .identity
        }
        
        checkboxButton.isSelected = item.isSelected
        // 設置編輯狀態
        editedStatusImageView.isHidden = !item.isEdited
        
        // 設置編輯狀態視覺效果
        if item.isEdited {
            editedSideBar.isHidden = false
            editedBadgeView.isHidden = false
            editedIconImageView.isHidden = false
            editedStatusImageView.isHidden = true
            
            // 讓整個 cell 有輕微的藍綠色調
            if !item.isSelected {
                backgroundColor = UIColor(red: 0.9, green: 1.0, blue: 1.0, alpha: 1.0)
                contentView.backgroundColor = UIColor(red: 0.9, green: 1.0, blue: 1.0, alpha: 1.0)
            }
        } else {
            editedSideBar.isHidden = true
            editedBadgeView.isHidden = true
            editedIconImageView.isHidden = true
            editedStatusImageView.isHidden = true
        }
    }
    
    @objc private func editButtonTapped() {
        onEditButtonTapped?()
    }
}
