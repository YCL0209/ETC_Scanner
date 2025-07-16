# ETC Scanner 應用程式改善計劃

## 📌 專案概述

ETC Scanner 是一款專為停車場管理設計的 iOS 應用程式，整合了藍牙條碼掃描、資料管理和雲端同步功能。本改善計劃旨在提升應用程式的架構、效能、安全性和使用者體驗。

---

## 🏗️ 一、架構改進

### 1.1 實施 MVVM 架構模式

**現況問題：**
- ViewController 過於龐大（超過 2000 行）
- 業務邏輯與 UI 邏輯混雜
- 難以進行單元測試

**改進建議：**

#### A. 建立 ViewModel 層
```swift
// ScannerViewModel.swift
class ScannerViewModel {
    @Published var scanItems: [ScanItem] = []
    @Published var isScanning: Bool = false
    @Published var scanStatus: String = "待機中"
    
    private let repository: ScanItemRepository
    private let networkService: NetworkService
    
    func handleScanResult(_ code: String) { }
    func exportSelectedItems(_ items: [ScanItem]) { }
    func importCSVFile(_ url: URL) { }
}
```

#### B. 分離關注點
- **View (ViewController)**：只負責 UI 更新和使用者互動
- **ViewModel**：處理業務邏輯和資料轉換
- **Model**：純資料結構
- **Repository**：資料存取層

### 1.2 建立服務層架構

```
📁 Services/
├── 📄 NetworkService.swift      // 網路請求
├── 📄 BluetoothService.swift    // 藍牙掃描
├── 📄 CSVService.swift          // CSV 處理
├── 📄 EmailService.swift        // 郵件發送
└── 📄 StorageService.swift      // 本地儲存
```

### 1.3 依賴注入容器

```swift
// DependencyContainer.swift
class DependencyContainer {
    static let shared = DependencyContainer()
    
    lazy var networkService = NetworkService()
    lazy var storageService = StorageService()
    lazy var csvService = CSVService()
    
    func makeScannerViewModel() -> ScannerViewModel {
        return ScannerViewModel(
            repository: makeScanItemRepository(),
            networkService: networkService
        )
    }
}
```

---

## 🔧 二、程式碼品質提升

### 2.1 重構 ViewController

**將現有功能模組化：**

```swift
// ViewController+Scanner.swift
extension ViewController {
    func setupScanner() { }
    func handleScanCompletion(_ code: String) { }
}

// ViewController+TableView.swift
extension ViewController {
    func setupTableView() { }
    func configureCell(_ cell: ScanItemCell, with item: ScanItem) { }
}

// ViewController+Actions.swift
extension ViewController {
    @IBAction func importButtonTapped() { }
    @IBAction func exportButtonTapped() { }
}
```

### 2.2 改善錯誤處理

**建立統一的錯誤處理機制：**

```swift
enum AppError: LocalizedError {
    case networkError(String)
    case fileError(String)
    case bluetoothError(String)
    case validationError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "網路錯誤：\(message)"
        case .fileError(let message):
            return "檔案錯誤：\(message)"
        case .bluetoothError(let message):
            return "藍牙錯誤：\(message)"
        case .validationError(let message):
            return "驗證錯誤：\(message)"
        }
    }
}

// 統一的錯誤處理方法
func handleError(_ error: Error) {
    let alert = UIAlertController(
        title: "錯誤",
        message: error.localizedDescription,
        preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "確定", style: .default))
    present(alert, animated: true)
}
```

### 2.3 加入單元測試

```swift
// ScannerViewModelTests.swift
class ScannerViewModelTests: XCTestCase {
    func testHandleScanResult() {
        // Given
        let viewModel = ScannerViewModel()
        let testCode = "TEST123"
        
        // When
        viewModel.handleScanResult(testCode)
        
        // Then
        XCTAssertEqual(viewModel.scanItems.count, 1)
        XCTAssertEqual(viewModel.scanItems.first?.code, testCode)
    }
}
```

---

## 🎨 三、使用者體驗優化

### 3.1 載入狀態管理

```swift
// LoadingView.swift
class LoadingView: UIView {
    private let activityIndicator = UIActivityIndicatorView()
    private let messageLabel = UILabel()
    
    func show(message: String) {
        messageLabel.text = message
        activityIndicator.startAnimating()
        isHidden = false
    }
    
    func hide() {
        activityIndicator.stopAnimating()
        isHidden = true
    }
}
```

### 3.2 改善鍵盤處理

**問題：**
- 掃描器鍵盤與編輯鍵盤衝突
- 鍵盤切換時的焦點管理混亂

**解決方案：**

```swift
// KeyboardManager.swift
class KeyboardManager {
    enum KeyboardMode {
        case scanner
        case editing
        case search
    }
    
    private var currentMode: KeyboardMode = .scanner
    
    func switchToMode(_ mode: KeyboardMode) {
        // 先清理當前狀態
        cleanupCurrentMode()
        
        // 切換到新模式
        currentMode = mode
        setupNewMode()
    }
}
```

### 3.3 搜尋功能優化

```swift
// SearchManager.swift
class SearchManager {
    private let searchQueue = DispatchQueue(label: "search.queue")
    private var searchWorkItem: DispatchWorkItem?
    
    func search(query: String, in items: [ScanItem], completion: @escaping ([ScanItem]) -> Void) {
        // 取消之前的搜尋
        searchWorkItem?.cancel()
        
        // 延遲搜尋（防抖動）
        searchWorkItem = DispatchWorkItem { [weak self] in
            let results = self?.performSearch(query: query, in: items) ?? []
            DispatchQueue.main.async {
                completion(results)
            }
        }
        
        searchQueue.asyncAfter(deadline: .now() + 0.3, execute: searchWorkItem!)
    }
}
```

---

## 💾 四、資料管理增強

### 4.1 實施 Core Data

```swift
// ScanItem+CoreData.swift
@objc(ScanItemEntity)
public class ScanItemEntity: NSManagedObject {
    @NSManaged public var code: String
    @NSManaged public var timestamp: Date
    @NSManaged public var building: String?
    @NSManaged public var household: String?
    @NSManaged public var parkingNumber: String?
    @NSManaged public var carType: String?
    @NSManaged public var carNumber: String?
    @NSManaged public var etagNumber: String?
    @NSManaged public var isEdited: Bool
    @NSManaged public var isSynced: Bool
}
```

### 4.2 資料同步機制

```swift
// SyncManager.swift
class SyncManager {
    func syncPendingItems() {
        // 1. 獲取未同步的項目
        let unsyncedItems = fetchUnsyncedItems()
        
        // 2. 批次上傳
        networkService.uploadBatch(unsyncedItems) { result in
            switch result {
            case .success(let syncedIds):
                // 3. 標記已同步
                self.markItemsAsSynced(syncedIds)
            case .failure(let error):
                // 4. 記錄錯誤，稍後重試
                self.scheduleRetry(error)
            }
        }
    }
}
```

### 4.3 改善 CSV 處理

```swift
// CSVProcessor.swift
class CSVProcessor {
    struct CSVValidationResult {
        let isValid: Bool
        let errors: [String]
        let warnings: [String]
    }
    
    func validateCSV(_ url: URL) -> CSVValidationResult {
        // 檢查檔案格式
        // 驗證必要欄位
        // 檢查資料完整性
    }
    
    func processCSVInBatches(_ url: URL, batchSize: Int = 100) {
        // 分批處理大檔案
    }
}
```

---

## 🔒 五、安全性強化

### 5.1 API 金鑰安全儲存

```swift
// KeychainManager.swift
class KeychainManager {
    static func saveAPIKey(_ key: String) {
        let data = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "APIKey",
            kSecValueData as String: data
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func getAPIKey() -> String? {
        // 從 Keychain 讀取
    }
}
```

### 5.2 網路安全增強

```swift
// NetworkSecurityManager.swift
class NetworkSecurityManager {
    // 憑證釘選
    func pinCertificate(for session: URLSession) {
        // 實施憑證釘選邏輯
    }
    
    // 請求簽名
    func signRequest(_ request: URLRequest) -> URLRequest {
        var signedRequest = request
        let timestamp = String(Date().timeIntervalSince1970)
        let signature = generateSignature(for: request, timestamp: timestamp)
        signedRequest.setValue(signature, forHTTPHeaderField: "X-Signature")
        signedRequest.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
        return signedRequest
    }
}
```

### 5.3 資料驗證

```swift
// DataValidator.swift
struct DataValidator {
    static func validateETAGCode(_ code: String) -> Bool {
        // ETAG 格式驗證
        let pattern = "^[A-Z0-9]{10,20}$"
        return code.range(of: pattern, options: .regularExpression) != nil
    }
    
    static func validateCarNumber(_ number: String) -> Bool {
        // 車牌格式驗證
        let patterns = [
            "^[A-Z]{3}-[0-9]{4}$",  // ABC-1234
            "^[0-9]{4}-[A-Z]{2}$",  // 1234-AB
            "^[A-Z]{2}-[0-9]{4}$"   // AB-1234
        ]
        return patterns.contains { pattern in
            number.range(of: pattern, options: .regularExpression) != nil
        }
    }
}
```

---

## ⚡ 六、效能優化

### 6.1 TableView 效能改善

```swift
// 實施差異化更新
func updateTableView(with newItems: [ScanItem]) {
    let diff = newItems.difference(from: currentItems)
    
    tableView.performBatchUpdates({
        for change in diff {
            switch change {
            case .insert(let offset, _, _):
                tableView.insertRows(at: [IndexPath(row: offset, section: 0)], with: .automatic)
            case .remove(let offset, _, _):
                tableView.deleteRows(at: [IndexPath(row: offset, section: 0)], with: .automatic)
            }
        }
    })
}

// 實施預載入
func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
    // 預載入即將顯示的資料
}
```

### 6.2 記憶體優化

```swift
// MemoryManager.swift
class MemoryManager {
    static func optimizeImageLoading() {
        // 使用 thumbnail 而非原圖
        // 實施圖片快取上限
        // 在記憶體警告時清理快取
    }
    
    static func setupMemoryWarningHandler() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
}
```

### 6.3 背景任務優化

```swift
// BackgroundTaskManager.swift
class BackgroundTaskManager {
    func scheduleBackgroundSync() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.etcscanner.sync",
            using: nil
        ) { task in
            self.handleBackgroundSync(task: task as! BGProcessingTask)
        }
    }
}
```

---

## 🚀 七、功能擴展建議

### 7.1 批次編輯功能

```swift
// BatchEditViewController.swift
class BatchEditViewController: UIViewController {
    // 選擇多個項目
    // 套用相同的屬性變更
    // 支援復原操作
}
```

### 7.2 資料統計與報表

```swift
// StatisticsManager.swift
class StatisticsManager {
    func generateDailyReport() -> Report {
        // 每日掃描數量
        // 各棟別統計
        // 編輯率分析
    }
    
    func exportReport(format: ExportFormat) {
        // PDF 報表
        // Excel 報表
        // 圖表視覺化
    }
}
```

### 7.3 離線模式

```swift
// OfflineManager.swift
class OfflineManager {
    private let offlineQueue = OperationQueue()
    
    func enableOfflineMode() {
        // 快取必要資料
        // 啟用離線操作佇列
        // 顯示離線狀態
    }
    
    func syncWhenOnline() {
        // 監聽網路狀態
        // 自動同步離線資料
    }
}
```

---

## 📊 八、實施優先順序

### 第一階段（1-2 週）
1. ✅ 重構 ViewController，分離關注點
2. ✅ 實施基本的 MVVM 架構
3. ✅ 改善錯誤處理機制
4. ✅ 優化 TableView 效能

### 第二階段（2-3 週）
1. ⏳ 實施 Core Data 本地儲存
2. ⏳ 加入資料同步機制
3. ⏳ 改善鍵盤處理邏輯
4. ⏳ 加入載入狀態指示器

### 第三階段（3-4 週）
1. ⏳ 強化安全性措施
2. ⏳ 實施單元測試
3. ⏳ 加入批次編輯功能
4. ⏳ 優化記憶體使用

### 第四階段（4-5 週）
1. ⏳ 實施離線模式
2. ⏳ 加入資料統計功能
3. ⏳ 完善文件和註解
4. ⏳ 效能測試和優化

---

## 🛠️ 九、開發工具建議

### 9.1 程式碼品質工具
- **SwiftLint**：程式碼風格檢查
- **SwiftFormat**：程式碼格式化
- **Periphery**：未使用程式碼檢測

### 9.2 測試工具
- **XCTest**：單元測試
- **XCUITest**：UI 測試
- **Quick/Nimble**：BDD 測試框架

### 9.3 效能分析
- **Instruments**：效能分析
- **Memory Graph Debugger**：記憶體洩漏檢測
- **Network Link Conditioner**：網路狀況模擬

---

## 📝 十、維護建議

### 10.1 程式碼審查清單
- [ ] 符合 MVVM 架構原則
- [ ] 有適當的錯誤處理
- [ ] 包含單元測試
- [ ] 沒有記憶體洩漏
- [ ] UI 響應流暢

### 10.2 版本發布流程
1. 功能分支開發
2. Pull Request 審查
3. 自動化測試
4. Beta 測試
5. 正式發布

### 10.3 監控與分析
- 崩潰報告追蹤
- 使用者行為分析
- 效能監控
- 錯誤日誌收集

---

## 🎯 結論

此改善計劃涵蓋了 ETC Scanner 應用程式的各個層面，從架構重構到功能擴展。建議按照優先順序逐步實施，確保每個階段都有明確的目標和可衡量的成果。

透過這些改進，應用程式將獲得：
- 🏗️ 更清晰的架構
- 🔧 更高的程式碼品質
- 🎨 更好的使用者體驗
- 🔒 更強的安全性
- ⚡ 更優的效能表現

定期檢視和更新此計劃，確保改善方向與業務需求保持一致。