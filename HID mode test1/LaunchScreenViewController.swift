//
//  LaunchScreenViewController.swift
//  HID mode test1
//
//  Created by 廖亞丞 on 2025/3/21.
//這是Ｃ版本
import UIKit

class LaunchScreenViewController: UIViewController {
    
    private let backgroundImageView = UIImageView()
    private let logoImageView = UIImageView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 設置背景顏色（以防圖片無法載入）
        view.backgroundColor = UIColor.white
        
        // 設置背景圖片
        backgroundImageView.frame = view.bounds
        backgroundImageView.image = UIImage(named: "LaunchBackground")
        backgroundImageView.contentMode = .scaleToFill
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backgroundImageView)
        
        // 設置 logo 圖片
        logoImageView.image = UIImage(named: "LaunchLogo")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)
        
        // 設置 logo 約束
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            logoImageView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.7),
            logoImageView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.3)
        ])
        
        // 打印調試信息
        print("LaunchScreenViewController viewDidLoad 完成")
        print("背景圖片: \(backgroundImageView.image != nil ? "已載入" : "未載入")")
        print("Logo 圖片: \(logoImageView.image != nil ? "已載入" : "未載入")")
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}


