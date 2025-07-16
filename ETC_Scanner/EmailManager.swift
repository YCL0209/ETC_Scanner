//
//  EmailManager.swift
//  ETC_Scanner
//
//  Created by 廖亞丞 on 2025/2/16.
//

import Foundation
import UIKit
import MessageUI  // 引入 MessageUI 框架

class EmailManager: NSObject, MFMailComposeViewControllerDelegate {
    
    static let shared = EmailManager()
    
    // 使用者的電子郵件服務選擇
    enum EmailServiceType {
        case system      // 使用系統郵件應用
        case apiService  // 使用 Google Apps Script API
    }
    
    // 預設使用系統郵件
    private var emailServiceType: EmailServiceType = .system
    
    // 完成回調
    private var completionHandler: ((Bool, String?) -> Void)?
    
    private override init() {
        super.init()
    }
    
    // 設定使用的郵件服務類型
    func setEmailServiceType(_ type: EmailServiceType) {
        emailServiceType = type
    }
    
    // 檢查系統郵件功能是否可用
    func canSendMail() -> Bool {
        return MFMailComposeViewController.canSendMail()
    }
    
    // 顯示發送電子郵件對話框
    func showSendEmailDialog(on viewController: UIViewController, selectedItems: [ScanItem], completion: @escaping (Bool, String?) -> Void) {
        if selectedItems.isEmpty {
            let alert = UIAlertController(title: "提示", message: "請先選擇要發送的項目", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "確定", style: .default))
            viewController.present(alert, animated: true)
            return
        }
        
        // 檢查是否可以使用系統郵件
        if emailServiceType == .system && !canSendMail() {
            // 如果系統郵件不可用，顯示提示
            let alert = UIAlertController(
                title: "無法使用系統郵件",
                message: "您的設備未設定郵件帳號或不支援郵件功能。請設定一個郵件帳號或改用 API 服務。",
                preferredStyle: .alert
            )
            
            // 添加切換到 API 服務的選項
            alert.addAction(UIAlertAction(title: "使用 API 服務", style: .default, handler: { [weak self] _ in
                self?.emailServiceType = .apiService
                self?.showSendEmailDialog(on: viewController, selectedItems: selectedItems, completion: completion)
            }))
            
            alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            viewController.present(alert, animated: true)
            return
        }
        
        // 根據服務類型顯示不同的郵件發送界面
        if emailServiceType == .system {
            showSystemMailComposer(on: viewController, selectedItems: selectedItems, completion: completion)
        } else {
            showApiMailDialog(on: viewController, selectedItems: selectedItems, completion: completion)
        }
    }
    
    // 顯示發送電子郵件對話框 (發送所有資料)
    func showSendAllDataDialog(on viewController: UIViewController, allItems: [ScanItem], completion: @escaping (Bool, String?) -> Void) {
        if allItems.isEmpty {
            let alert = UIAlertController(title: "提示", message: "目前沒有任何資料可發送", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "確定", style: .default))
            viewController.present(alert, animated: true)
            return
        }
        
        // 檢查是否可以使用系統郵件
        if emailServiceType == .system && !canSendMail() {
            // 如果系統郵件不可用，顯示提示
            let alert = UIAlertController(
                title: "無法使用系統郵件",
                message: "您的設備未設定郵件帳號或不支援郵件功能。請設定一個郵件帳號或改用 API 服務。",
                preferredStyle: .alert
            )
            
            // 添加切換到 API 服務的選項
            alert.addAction(UIAlertAction(title: "使用 API 服務", style: .default, handler: { [weak self] _ in
                self?.emailServiceType = .apiService
                self?.showSendAllDataDialog(on: viewController, allItems: allItems, completion: completion)
            }))
            
            alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            viewController.present(alert, animated: true)
            return
        }
        
        // 根據服務類型顯示不同的郵件發送界面
        if emailServiceType == .system {
            // 使用系統郵件
            showSystemMailComposer(on: viewController, selectedItems: allItems, completion: completion)
        } else {
            // 使用 API 服務
            showApiMailDialog(on: viewController, selectedItems: allItems, completion: completion)
        }
    }
    
    // 顯示系統郵件編輯器
    private func showSystemMailComposer(on viewController: UIViewController, selectedItems: [ScanItem], completion: @escaping (Bool, String?) -> Void) {
        // 保存完成回調
        self.completionHandler = completion
        
        // 創建郵件編輯器
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        
        // 設定郵件主旨
        mailComposer.setSubject("ETC 資料分享")
        
        // 生成 HTML 表格和 CSV 內容
        let htmlContent = generateHTMLTable(items: selectedItems, message: "以下是選中的 ETC 資料：")
        let csvContent = generateCSV(items: selectedItems)
        
        // 設定郵件內容
        mailComposer.setMessageBody(htmlContent, isHTML: true)
        
        // 添加 CSV 附件
        if let csvData = csvContent.data(using: .utf8) {
            let fileName = "ETC資料_\(Date().timeIntervalSince1970).csv"
            mailComposer.addAttachmentData(csvData, mimeType: "text/csv", fileName: fileName)
        }
        
        // 顯示郵件編輯器
        viewController.present(mailComposer, animated: true)
    }
    
    // 郵件編輯器代理方法
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        // 關閉郵件編輯器
        controller.dismiss(animated: true) {
            // 根據結果回調
            switch result {
            case .cancelled:
                self.completionHandler?(false, "郵件發送已取消")
            case .saved:
                self.completionHandler?(true, "郵件已保存為草稿")
            case .sent:
                self.completionHandler?(true, "郵件發送成功")
            case .failed:
                self.completionHandler?(false, "郵件發送失敗: \(error?.localizedDescription ?? "未知錯誤")")
            @unknown default:
                self.completionHandler?(false, "未知結果")
            }
            
            // 清除回調
            self.completionHandler = nil
        }
    }
    
    // 顯示 API 郵件對話框 (與原來的 showSendEmailDialog 方法類似)
    private func showApiMailDialog(on viewController: UIViewController, selectedItems: [ScanItem], completion: @escaping (Bool, String?) -> Void) {
        // 創建警告控制器
        let alert = UIAlertController(title: "發送電子郵件", message: "請輸入收件人和郵件內容", preferredStyle: .alert)
        
        // 添加收件人輸入框
        alert.addTextField { textField in
            textField.placeholder = "收件人（多個收件人請用逗號分隔）"
            textField.keyboardType = .emailAddress
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
        
        // 添加主旨輸入框
        alert.addTextField { textField in
            textField.placeholder = "郵件主旨"
        }
        
        // 添加郵件內容輸入框
        alert.addTextField { textField in
            textField.placeholder = "郵件內容"
        }
        
        // 添加取消按鈕
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        alert.addAction(cancelAction)
        
        // 添加發送按鈕
        let sendAction = UIAlertAction(title: "發送", style: .default) { [weak self] _ in
            guard let self = self,
                  let recipientsText = alert.textFields?[0].text,
                  let subject = alert.textFields?[1].text,
                  let message = alert.textFields?[2].text else {
                completion(false, "無法獲取輸入內容")
                return
            }
            
            // 分割收件人
            let recipients = recipientsText.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            if recipients.isEmpty {
                let errorAlert = UIAlertController(title: "錯誤", message: "請輸入至少一個有效的收件人", preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "確定", style: .default))
                viewController.present(errorAlert, animated: true)
                return
            }
            
            // 顯示加載中提示
            self.showLoadingAlert(on: viewController, message: "正在發送郵件...")
            
            // 生成 CSV 和 HTML 內容
            let csvContent = self.generateCSV(items: selectedItems)
            let htmlContent = self.generateHTMLTable(items: selectedItems, message: message)
            
            // 發送電子郵件
            self.sendEmail(
                recipients: recipients,
                subject: subject,
                message: htmlContent,
                csvContent: csvContent
            ) { success, message in
                DispatchQueue.main.async {
                    // 關閉加載提示
                    if let presentedVC = viewController.presentedViewController as? UIAlertController {
                        presentedVC.dismiss(animated: true) {
                            completion(success, message)
                        }
                    } else {
                        completion(success, message)
                    }
                }
            }
        }
        alert.addAction(sendAction)
        
        // 顯示對話框
        viewController.present(alert, animated: true)
    }
    
    // API 服務發送郵件方法 (保留原有方法)
    func sendEmail(recipients: [String], subject: String, message: String, csvContent: String, completion: @escaping (Bool, String?) -> Void) {
        // 使用完整的 GAS 部署 URL
        let emailServerURL = NetworkManager.shared.emailServerURL
        guard let url = URL(string: emailServerURL) else {
            completion(false, "無效的伺服器網址")
            return
        }
        
        // 建立請求資料
        let requestData: [String: Any] = [
            "action": "sendEmail",
            "recipient": recipients.joined(separator: ","),
            "subject": subject,
            "message": message,
            "csvContent": csvContent,
            "senderName": "ETC Scanner App"
        ]
        
        // 將請求資料轉換為 JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestData) else {
            completion(false, "無法序列化請求資料")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(NetworkManager.shared.apiKey, forHTTPHeaderField: "x-api-key")
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(false, "網路錯誤：\(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "未收到伺服器回應")
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(false, "伺服器回應異常：\(httpResponse.statusCode)")
                return
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("郵件發送回應：\(responseString)")
                
                // 嘗試解析回應
                if let responseData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = responseData["success"] as? Bool {
                    if success {
                        completion(true, "郵件發送成功")
                    } else {
                        let errorMessage = responseData["error"] as? String ?? "郵件發送失敗"
                        completion(false, errorMessage)
                    }
                } else {
                    completion(true, "郵件已發送")
                }
            } else {
                completion(true, "郵件已發送，但無法解析回應")
            }
        }
        
        task.resume()
    }
    
    // 完全重寫 generateHTMLTable 方法，將其分解為多個子方法
    func generateHTMLTable(items: [ScanItem], message: String) -> String {
        // 分解成幾個獨立的部分來組成最終的 HTML
        let header = generateHTMLHeader(message: message)
        let tableStart = generateTableStart()
        let tableHeader = generateTableHeader()
        let tableBody = generateTableBody(items: items)
        let tableEnd = generateTableEnd()
        let footer = generateHTMLFooter()
        
        // 組合所有部分
        return header + tableStart + tableHeader + tableBody + tableEnd + footer
    }
    
    // 生成 HTML 頭部
    private func generateHTMLHeader(message: String) -> String {
        let processedMessage = message.replacingOccurrences(of: "\n", with: "<br>")
        let header = "<div>\(processedMessage)</div><br><h3>ETC 資料：</h3>"
        return header
    }
    
    // 生成表格開始標籤
    private func generateTableStart() -> String {
        return "<table border=\"1\" cellpadding=\"5\" cellspacing=\"0\" style=\"border-collapse: collapse;\">"
    }
    
    // 生成表格頭部
    private func generateTableHeader() -> String {
        let headers = ["序號", "棟別", "戶別", "所有權人", "承租人", "電話", "車位號碼", "車種", "車牌", "ETAG"]
        var headerRow = "<tr style=\"background-color: #f2f2f2;\">"
        
        for header in headers {
            headerRow += "<th>\(header)</th>"
        }
        
        headerRow += "</tr>"
        return headerRow
    }
    
    // 生成表格主體
    private func generateTableBody(items: [ScanItem]) -> String {
        var tableBody = ""
        
        for (index, item) in items.enumerated() {
            tableBody += generateTableRow(index: index, item: item)
        }
        
        return tableBody
    }
    
    // 生成單行表格數據 - 極度簡化版
    private func generateTableRow(index: Int, item: ScanItem) -> String {
        // 預先創建每個單元格，而不是一次性創建整個陣列
        let cell1 = "<td>" + String(index + 1) + "</td>"
        let cell2 = "<td>" + (item.building ?? "") + "</td>"
        let cell3 = "<td>" + (item.household ?? "") + "</td>"
        let cell4 = "<td>" + (item.owner ?? "") + "</td>"
        let cell5 = "<td>" + (item.tenant ?? "") + "</td>"
        let cell6 = "<td>" + (item.phone ?? "") + "</td>"
        let cell7 = "<td>" + (item.parkingNumber ?? "") + "</td>"
        let cell8 = "<td>" + (item.carType ?? "") + "</td>"
        let cell9 = "<td>" + (item.carNumber ?? "") + "</td>"
        let cell10 = "<td>" + (item.etagNumber ?? "") + "</td>"
        
        // 合併所有單元格
        let rowContent = cell1 + cell2 + cell3 + cell4 + cell5 + cell6 + cell7 + cell8 + cell9 + cell10
        
        // 添加行標籤
        return "<tr>" + rowContent + "</tr>"
    }
    
    // 生成表格結束標籤
    private func generateTableEnd() -> String {
        return "</table>"
    }
    
    // 生成 HTML 頁尾
    private func generateHTMLFooter() -> String {
        return "<br><p style=\"color: gray; font-size: 12px;\">此郵件由 ETC Scanner 應用程式自動生成</p>"
    }
    
    // 重寫 CSV 生成方法
    func generateCSV(items: [ScanItem]) -> String {
        // 生成 CSV 頭部
        let csvHeader = "序號,棟別,戶別,所有權人,承租人,電話,車位號碼,車種,車牌,ETAG\n"
        
        // 生成 CSV 內容
        var csvRows = ""
        for (index, item) in items.enumerated() {
            csvRows += generateCSVRow(index: index, item: item) + "\n"
        }
        
        // 組合頭部和內容
        return csvHeader + csvRows
    }
    
    private func generateCSVRow(index: Int, item: ScanItem) -> String {
        // 預先創建每個欄位，而不是一次性創建整個陣列
        let field1 = String(index + 1)
        let field2 = item.building ?? ""
        let field3 = item.household ?? ""
        let field4 = item.owner ?? ""
        let field5 = item.tenant ?? ""
        let field6 = item.phone ?? ""
        let field7 = item.parkingNumber ?? ""
        let field8 = item.carType ?? ""
        let field9 = item.carNumber ?? ""
        let field10 = item.etagNumber ?? ""
        
        // 合併所有欄位
        return field1 + "," + field2 + "," + field3 + "," + field4 + "," + 
               field5 + "," + field6 + "," + field7 + "," + field8 + "," + 
               field9 + "," + field10
    }
    
    private func showLoadingAlert(on viewController: UIViewController, message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        
        alert.view.addSubview(loadingIndicator)
        viewController.present(alert, animated: true, completion: nil)
    }
}
