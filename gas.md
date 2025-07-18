/**
 * ETC Scanner 電子郵件發送服務
 * 用於接收應用程式的郵件請求，發送郵件並記錄歷史
 */

// 設定全局變數
const SHEET_NAME = "社區郵件紀錄";  // 記錄郵件的工作表名稱
const API_KEY = "MasHsieh0817";  // 與應用程式中設定的API金鑰相同

/**
 * 處理 GET 請求 - 提供一個簡單的網頁介面，也可用於測試服務是否正常運行
 */
function doGet(e) {
  // 如果有 format=json 參數，則返回 JSON 格式的狀態信息
  if (e && e.parameter && e.parameter.format === 'json') {
    return createJsonResponse({
      success: true,
      status: "online",
      message: "服務正常運行中",
      timestamp: new Date().toISOString()
    });
  }
  
  // 否則返回 HTML 格式的狀態頁面
  return HtmlService.createHtmlOutput(`
    <h1>ETC Scanner 電子郵件服務</h1>
    <p>此服務用於處理 ETC Scanner 應用程式的郵件請求。</p>
    <p>服務狀態: 正常運行中</p>
    <p>更新時間: ${new Date().toLocaleString()}</p>
  `);
}

/**
 * 處理 POST 請求 - 處理電子郵件發送請求
 */
function doPost(e) {
  try {
    Logger.log('收到 POST 請求');
    Logger.log('收到請求 URL: ' + e.parameter);
    Logger.log('收到請求頭: ' + JSON.stringify(e.headers));
    Logger.log('收到請求內容: ' + (e.postData ? e.postData.contents : "無內容"));
    
    // 驗證請求
    if (!validateRequest(e)) {
      Logger.log('API金鑰驗證失敗');
      return createJsonResponse({
        success: false,
        error: "未授權的請求",
        message: "API金鑰無效或缺失"
      });
    }
    
    // 解析請求內容
    let requestData;
    if (e.postData && e.postData.contents) {
      try {
        requestData = JSON.parse(e.postData.contents);
        Logger.log('解析 JSON 請求數據: ' + JSON.stringify(requestData));
      } catch (parseError) {
        Logger.log('JSON 解析錯誤: ' + parseError.message);
        return createJsonResponse({
          success: false,
          error: "無效的 JSON 格式",
          message: "請求內容無法解析為 JSON: " + parseError.message
        });
      }
    } else if (e.parameter) {
      requestData = e.parameter;
      Logger.log('使用 URL 參數作為請求數據: ' + JSON.stringify(requestData));
    } else {
      Logger.log('無請求數據');
      return createJsonResponse({
        success: false,
        error: "無請求數據",
        message: "請求中沒有可用的數據"
      });
    }
    
    // 預設操作為 sendEmail（無需檢查路徑）
    if (!requestData.action) {
      requestData.action = "sendEmail";
    }
    
    // 根據 action 參數決定執行的操作
    const action = requestData.action || "";
    Logger.log('請求操作: ' + action);
    
    switch (action) {
      case 'sendEmail':
        return handleSendEmail(requestData);
      
      case 'status':
        return createJsonResponse({
          success: true,
          status: "online",
          message: "服務正常運行中",
          timestamp: new Date().toISOString()
        });
        
      default:
        Logger.log('未知操作: ' + action);
        return createJsonResponse({
          success: false,
          error: "未知的操作",
          message: "不支援的操作類型: " + action
        });
    }
    
  } catch (error) {
    Logger.log('doPost 處理錯誤：' + error.message);
    Logger.log('錯誤堆疊: ' + error.stack);
    
    return createJsonResponse({
      success: false,
      error: error.message,
      message: '請求處理失敗',
      stack: error.stack
    });
  }
}

/**
 * 驗證請求的API金鑰
 */
function validateRequest(e) {
  // 從請求頭或參數中獲取API金鑰
  let apiKey = "";
  
  // 嘗試從標頭中獲取，不區分大小寫
  if (e.headers) {
    for (const key in e.headers) {
      if (key.toLowerCase() === 'x-api-key') {
        apiKey = e.headers[key];
        Logger.log('從 Header 獲取 API 金鑰 (不區分大小寫): ' + apiKey);
        break;
      }
    }
  } 
  // 從參數中獲取
  else if (e.parameter && e.parameter.apiKey) {
    apiKey = e.parameter.apiKey;
    Logger.log('從 URL 參數獲取 API 金鑰: ' + apiKey);
  }
  // 從 JSON 中獲取
  else if (e.postData && e.postData.contents) {
    try {
      const jsonData = JSON.parse(e.postData.contents);
      if (jsonData.apiKey) {
        apiKey = jsonData.apiKey;
        Logger.log('從 JSON 內容獲取 API 金鑰: ' + apiKey);
      }
    } catch (error) {
      Logger.log('JSON 解析錯誤，無法獲取 API 金鑰: ' + error.message);
    }
  }
  
  // 記錄獲取到的 API 金鑰和預期金鑰
  Logger.log('獲取到的 API 金鑰: ' + apiKey);
  Logger.log('預期的 API 金鑰: ' + API_KEY);
  
  // 驗證 API 金鑰
  const isValid = apiKey === API_KEY;
  Logger.log('API 金鑰驗證結果: ' + isValid);
  return isValid;
}

/**
 * 處理寄信請求
 */
function handleSendEmail(requestData) {
  try {
    Logger.log('處理寄信請求');
    
    // 驗證必要參數
    if (!requestData.recipient) {
      throw new Error('未提供收件人');
    }
    
    if (!requestData.subject) {
      throw new Error('未提供郵件主旨');
    }
    
    if (!requestData.message) {
      throw new Error('未提供郵件內容');
    }
    
    // 處理收件人（可能是逗號分隔的多個郵件地址）
    const recipients = requestData.recipient.split(',').map(email => email.trim()).filter(email => email);
    
    if (recipients.length === 0) {
      throw new Error('未提供有效的收件人');
    }
    
    // 建立郵件內容
    const emailBody = requestData.message;
    const subject = requestData.subject;
    const senderName = requestData.senderName || "ETC Scanner App";
    const csvContent = requestData.csvContent || "";
    
    // 添加 CSV 附件（如果有）
    const options = {
      htmlBody: emailBody,
      name: senderName
    };
    
    // 如果有 CSV 內容，添加為附件
    if (csvContent) {
      // 創建一個臨時 Blob 對象作為附件
      const csvBlob = Utilities.newBlob(csvContent, 'text/csv', 'ETC資料.csv');
      options.attachments = [csvBlob];
    }
    
    // 寄送郵件
    GmailApp.sendEmail(recipients.join(','), subject, "請使用支援 HTML 的郵件客戶端查看此郵件", options);
    
    // 記錄到試算表
    recordEmailSent({
      recipients: recipients.join(', '),
      subject: subject,
      message: emailBody,
      csvContent: csvContent ? "已附加 CSV 資料" : "無",
      status: "成功"
    });
    
    // 返回成功回應
    const response = {
      success: true,
      message: '郵件已成功寄送',
      recipients: recipients
    };
    
    Logger.log('寄信成功：' + JSON.stringify(response));
    
    return createJsonResponse(response);
      
  } catch (error) {
    Logger.log('寄信處理錯誤：' + error.message);
    
    // 記錄失敗到試算表
    recordEmailSent({
      recipients: requestData.recipient || "未知",
      subject: requestData.subject || "未知",
      message: requestData.message ? "長度: " + requestData.message.length : "未知",
      csvContent: requestData.csvContent ? "已提供 CSV 資料" : "無",
      status: "失敗: " + error.message
    });
    
    const errorResponse = {
      success: false,
      error: error.message,
      message: '郵件寄送失敗'
    };
    
    return createJsonResponse(errorResponse);
  }
}

/**
 * 記錄郵件發送到試算表
 */
function recordEmailSent(data) {
  try {
    Logger.log("開始記錄郵件發送信息...");
    
    // 替換為您的試算表 ID
    const spreadsheetId = "1yU9o41731JiKN9NxGD5WvKY-UQetHR9gDh1GDUV1-UE"; 
    const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
    
    // 檢查工作表是否存在
    let sheet = spreadsheet.getSheetByName(SHEET_NAME);
    
    // 如果工作表不存在，創建它
    if (!sheet) {
      Logger.log("找不到工作表「" + SHEET_NAME + "」，正在創建...");
      sheet = spreadsheet.insertSheet(SHEET_NAME);
      
      // 設置標題行
      sheet.appendRow([
        "時間", 
        "收件人", 
        "主旨", 
        "內容", 
        "附件", 
        "狀態"
      ]);
      
      // 設置標題行格式
      sheet.getRange(1, 1, 1, 6).setFontWeight("bold");
      
      Logger.log("已創建工作表：" + SHEET_NAME);
    } else {
      Logger.log("成功獲取工作表：" + SHEET_NAME);
    }
    
    // 添加一行新記錄
    sheet.appendRow([
      new Date(),                // 發送時間
      data.recipients,           // 收件人
      data.subject,              // 主旨
      data.message.substring(0, 1000),  // 內容 (限制長度)
      data.csvContent,           // 附件內容
      data.status                // 狀態
    ]);
    
    Logger.log("郵件記錄已添加到試算表");
  } catch (error) {
    Logger.log("記錄郵件時出錯：" + error.message);
    Logger.log("錯誤堆疊：" + error.stack);
  }
}

/**
 * 創建 JSON 回應 (修正 addHeader 問題)
 */
function createJsonResponse(data) {
  // 創建 ContentService 響應對象
  var response = ContentService.createTextOutput(JSON.stringify(data));
  response.setMimeType(ContentService.MimeType.JSON);
  
  // GAS 會自動處理跨域請求，所以我們不需要手動添加 CORS 標頭
  // ContentService 對象沒有 addHeader 方法，這會導致錯誤
  
  return response;
}

/**
 * 測試函數 - 可從編輯器中手動運行以測試功能
 */
function testSendEmail() {
  const testData = {
    recipient: Session.getActiveUser().getEmail(), // 發送給當前登入的用戶
    subject: "ETC Scanner 測試郵件",
    message: "<h1>這是一封測試郵件</h1><p>如果您收到此郵件，表示 Apps Script 郵件功能正常運作。</p>",
    csvContent: "序號,棟別,戶別,車位號碼\n1,A棟,101,A-001\n2,B棟,202,B-002",
    senderName: "ETC Scanner 測試",
    apiKey: API_KEY
  };
  
  const result = handleSendEmail(testData);
  Logger.log('測試結果: ' + result.getContent());
}

/**
 * 處理 OPTIONS 請求 - 用於 CORS 預檢請求
 */
function doOptions(e) {
  // 創建一個空的文本響應
  var response = ContentService.createTextOutput('');
  response.setMimeType(ContentService.MimeType.TEXT);
  
  // Google Apps Script 會自動處理 CORS 預檢請求
  // 注意：ContentService 對象沒有 addHeader 方法，所以我們不能手動添加 CORS 標頭
  
  return response;
}

/**
 * iOS 應用程式請求範例
 * 
 * 以下是 iOS 應用程式中使用的請求代碼，用於連接此 GAS 腳本：
 * 
 * // 從上傳 URL 構建電子郵件 API URL
 * let baseURLString = uploadURL.absoluteString.replacingOccurrences(of: "/api/file/upload", with: "")
 * guard let url = URL(string: "\(baseURLString)/api/email/send") else {
 *     completion(false, "無效的伺服器網址")
 *     return
 * }
 * 
 * // 建立請求資料
 * let requestData: [String: Any] = [
 *     "action": "sendEmail",
 *     "recipient": recipients.joined(separator: ","),
 *     "subject": subject,
 *     "message": message,
 *     "csvContent": csvContent,
 *     "senderName": "ETC Scanner App"
 * ]
 * 
 * // 添加 API 金鑰
 * request.setValue(NetworkManager.shared.apiKey, forHTTPHeaderField: "x-api-key")
 */

function testAuth() {
  // 模擬請求
  const e = {
    headers: {
      'x-api-key': 'MasHsieh0817'  // 使用正確的 API 金鑰
    },
    postData: {
      contents: JSON.stringify({
        action: 'sendEmail',
        recipient: Session.getActiveUser().getEmail(),
        subject: 'Test',
        message: 'Test message'
      })
    }
  };
  
  // 測試驗證
  const isValid = validateRequest(e);
  Logger.log('驗證結果: ' + isValid);
  
  // 測試完整請求處理
  const result = doPost(e);
  Logger.log('處理結果: ' + result.getContent());
}