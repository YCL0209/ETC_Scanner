import UIKit
import MessageUI

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
    
    // 顯示 API 郵件對話框
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
    
    // API 服務發送郵件方法
    func sendEmail(recipients: [String], subject: String, message: String, csvContent: String, completion: @escaping (Bool, String?) -> Void) {
        // 確保 URL 格式正確
        let baseURL = NetworkManager.shared.getBaseURL()
        
        guard let url = URL(string: "\(baseURL)/api/email/send") else {
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
            
            if let data = data {
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
    
    // 生成 HTML 表格
    func generateHTMLTable(items: [ScanItem], message: String) -> String {
        // 1. 創建開頭部分
        var htmlMessage = "<div>"
        htmlMessage += message.replacingOccurrences(of: "\n", with: "<br>")
        htmlMessage += "</div><br>"
        htmlMessage += "<h3>ETC 資料：</h3>"
        
        // 2. 添加表格開頭
        htmlMessage += "<table border=\"1\" cellpadding=\"5\" cellspacing=\"0\" style=\"border-collapse: collapse;\">"
        
        // 3. 添加表頭
        htmlMessage += "<tr style=\"background-color: #f2f2f2;\">"
        htmlMessage += "<th>序號</th>"
        htmlMessage += "<th>棟別</th>"
        htmlMessage += "<th>戶別</th>"
        htmlMessage += "<th>所有權人</th>"
        htmlMessage += "<th>承租人</th>"
        htmlMessage += "<th>電話</th>"
        htmlMessage += "<th>車位號碼</th>"
        htmlMessage += "<th>車種</th>"
        htmlMessage += "<th>車牌</th>"
        htmlMessage += "<th>ETAG</th>"
        htmlMessage += "</tr>"
        
        // 4. 逐行添加數據
        for (index, item) in items.enumerated() {
            htmlMessage += "<tr>"
            
            // 添加序號
            htmlMessage += "<td>"
            htmlMessage += String(index + 1)
            htmlMessage += "</td>"
            
            // 添加棟別
            htmlMessage += "<td>"
            htmlMessage += item.building ?? ""
            htmlMessage += "</td>"
            
            // 添加戶別
            htmlMessage += "<td>"
            htmlMessage += item.household ?? ""
            htmlMessage += "</td>"
            
            // 添加所有權人
            htmlMessage += "<td>"
            htmlMessage += item.owner ?? ""
            htmlMessage += "</td>"
            
            // 添加承租人
            htmlMessage += "<td>"
            htmlMessage += item.tenant ?? ""
            htmlMessage += "</td>"
            
            // 添加電話
            htmlMessage += "<td>"
            htmlMessage += item.phone ?? ""
            htmlMessage += "</td>"
            
            // 添加車位號碼
            htmlMessage += "<td>"
            htmlMessage += item.parkingNumber ?? ""
            htmlMessage += "</td>"
            
            // 添加車種
            htmlMessage += "<td>"
            htmlMessage += item.carType ?? ""
            htmlMessage += "</td>"
            
            // 添加車牌
            htmlMessage += "<td>"
            htmlMessage += item.carNumber ?? ""
            htmlMessage += "</td>"
            
            // 添加ETAG
            htmlMessage += "<td>"
            htmlMessage += item.etagNumber ?? ""
            htmlMessage += "</td>"
            
            htmlMessage += "</tr>"
        }
        
        // 5. 添加表格結尾
        htmlMessage += "</table>"
        
        // 6. 添加頁尾
        htmlMessage += "<br>"
        htmlMessage += "<p style=\"color: gray; font-size: 12px;\">此郵件由 ETC Scanner 應用程式自動生成</p>"
        
        return htmlMessage
    }
    
    // 生成 CSV 內容
    func generateCSV(items: [ScanItem]) -> String {
        var csvContent = "序號,棟別,戶別,所有權人,承租人,電話,車位號碼,車種,車牌,ETAG\n"
        
        for (index, item) in items.enumerated() {
            csvContent += generateCSVRow(index: index, item: item) + "\n"
        }
        
        return csvContent
    }
    
    // 生成 CSV 行
    private func generateCSVRow(index: Int, item: ScanItem) -> String {
        let fields = [
            String(index + 1),
            item.building ?? "",
            item.household ?? "",
            item.owner ?? "",
            item.tenant ?? "",
            item.phone ?? "",
            item.parkingNumber ?? "",
            item.carType ?? "",
            item.carNumber ?? "",
            item.etagNumber ?? ""
        ]
        
        return fields.joined(separator: ",")
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
    
    // 顯示發送所有資料對話框
    func showSendAllDataDialog(on viewController: UIViewController, allItems: [ScanItem], completion: @escaping (Bool, String?) -> Void) {
        if allItems.isEmpty {
            let alert = UIAlertController(title: "提示", message: "沒有可發送的資料", preferredStyle: .alert)
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
            showSystemMailComposerForAllData(on: viewController, allItems: allItems, completion: completion)
        } else {
            showApiMailDialogForAllData(on: viewController, allItems: allItems, completion: completion)
        }
    }
    
    // 顯示系統郵件編輯器 (用於所有資料)
    private func showSystemMailComposerForAllData(on viewController: UIViewController, allItems: [ScanItem], completion: @escaping (Bool, String?) -> Void) {
        // 保存完成回調
        self.completionHandler = completion
        
        // 創建郵件編輯器
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        
        // 設定郵件主旨
        mailComposer.setSubject("ETC 完整資料分享")
        
        // 生成 HTML 表格和 CSV 內容
        let htmlContent = generateHTMLTable(items: allItems, message: "以下是 ETC 完整資料：")
        let csvContent = generateCSV(items: allItems)
        
        // 設定郵件內容
        mailComposer.setMessageBody(htmlContent, isHTML: true)
        
        // 添加 CSV 附件
        if let csvData = csvContent.data(using: .utf8) {
            let fileName = "ETC完整資料_\(Date().timeIntervalSince1970).csv"
            mailComposer.addAttachmentData(csvData, mimeType: "text/csv", fileName: fileName)
        }
        
        // 顯示郵件編輯器
        viewController.present(mailComposer, animated: true)
    }
    
    // 顯示 API 郵件對話框 (用於所有資料)
    private func showApiMailDialogForAllData(on viewController: UIViewController, allItems: [ScanItem], completion: @escaping (Bool, String?) -> Void) {
        // 創建警告控制器
        let alert = UIAlertController(title: "發送完整 ETC 資料", message: "請輸入收件人和郵件內容", preferredStyle: .alert)
        
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
            textField.text = "ETC 完整資料分享"
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
            let csvContent = self.generateCSV(items: allItems)
            let htmlContent = self.generateHTMLTable(items: allItems, message: message)
            
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
} 