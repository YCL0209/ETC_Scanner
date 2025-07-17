# ETC Scanner 架構說明文件

## 📱 應用程式概述

ETC Scanner 是一款專為停車場管理設計的 iOS 應用程式，整合了藍牙條碼掃描、資料管理和雲端同步功能。本文件詳細說明應用程式的架構設計和實作細節。

## 🏗️ 架構模式

### MVVM (Model-View-ViewModel) 架構

應用程式採用 MVVM 架構模式，具有以下優點：
- **關注點分離**：將業務邏輯從視圖層分離
- **可測試性**：ViewModel 可以獨立測試
- **可維護性**：程式碼組織清晰，易於維護
- **可擴展性**：新功能可以輕鬆加入

### 架構層級

```
┌─────────────────────────────────────────────────────┐
│                    View Layer                       │
│  (ViewControllers, Extensions, Custom Views)        │
├─────────────────────────────────────────────────────┤
│                  ViewModel Layer                    │
│         (Business Logic, State Management)          │
├─────────────────────────────────────────────────────┤
│                  Service Layer                      │
│    (Network, Email, Download, CSV Processing)       │
├─────────────────────────────────────────────────────┤
│                   Model Layer                       │
│           (Data Models, Persistence)                │
└─────────────────────────────────────────────────────┘
```

## 📁 專案結構詳解

### 1. View Layer (視圖層)

#### ViewControllers
- **ViewController.swift**
  - 主要視圖控制器（透過 Extensions 分解功能）
  - 負責 UI 更新和使用者互動
  - 管理掃描器狀態和表格顯示

- **EditDetailViewController.swift**
  - 處理掃描項目的詳細編輯
  - 提供表單介面修改項目屬性

- **LaunchScreenViewController.swift**
  - 應用程式啟動畫面控制

#### Extensions (ViewController 功能分解)
- **ViewController+Scanner.swift**
  - 掃描器設置和管理
  - 處理掃描完成邏輯
  - 重複條碼檢測

- **ViewController+TableView.swift**
  - TableView 資料源和委託方法
  - Cell 配置和更新
  - 選擇狀態管理

- **ViewController+Actions.swift**
  - 按鈕動作處理（匯入、匯出、刪除）
  - 使用者互動回應
  - 警告對話框顯示

- **ViewController+Search.swift**
  - 搜尋功能實作
  - 過濾邏輯處理
  - 搜尋狀態管理

#### Custom Views
- **ScanItemCell.swift**
  - 自訂表格單元格
  - 顯示掃描項目資訊
  - 編輯按鈕處理

- **CustomAlphaNumKeyboard.swift**
  - 自訂英數字鍵盤
  - 支援掃描器輸入
  - 特殊字元處理

### 2. ViewModel Layer (視圖模型層)

- **ScannerViewModel.swift**
  - 掃描業務邏輯
  - 資料狀態管理
  - 搜尋和過濾功能
  - 資料持久化協調

### 3. Service Layer (服務層)

- **NetworkManager.swift**
  - API 通訊管理
  - 檔案上傳/下載
  - 網路請求配置
  - 錯誤處理

- **EmailManager.swift**
  - 雙模式郵件發送
  - CSV 附件生成
  - HTML 表格格式化
  - 郵件服務切換

- **DownloadManager.swift**
  - 背景下載支援
  - 進度追蹤
  - 重試機制
  - 檔案完整性檢查

- **ServiceProtocols.swift**
  - 服務介面定義
  - 協議導向設計
  - 依賴注入支援

### 4. Model Layer (模型層)

- **ScanItem**
  - 核心資料模型
  - Codable 協議支援
  - 包含所有掃描資訊

### 5. Utilities (工具類)

- **CSVStreamReader.swift**
  - 串流式 CSV 讀取
  - 記憶體優化處理
  - 大檔案支援

- **AppError.swift**
  - 統一錯誤處理
  - 本地化錯誤訊息
  - 錯誤恢復建議

- **DependencyContainer.swift**
  - 依賴注入容器
  - 服務單例管理
  - 工廠方法模式

## 🔄 資料流程

### 掃描流程
```
使用者掃描 → ViewController → ScannerViewModel → 資料驗證 → 
更新 Model → 通知 View 更新 → TableView 顯示
```

### 網路請求流程
```
ViewModel 發起請求 → NetworkManager → API 呼叫 → 
回應處理 → 更新 ViewModel → 通知 View 更新
```

## 🛠️ 技術特點

### 1. 記憶體優化
- CSV 串流處理避免大檔案記憶體溢出
- FileHandle 寫入避免記憶體累積
- 批次處理提升效能

### 2. 錯誤處理
- 統一的 AppError 系統
- 完整的錯誤恢復機制
- 使用者友善的錯誤提示

### 3. 背景處理
- 支援背景下載
- 藍牙背景掃描
- 檔案處理進度回報

### 4. 安全性
- API 金鑰保護
- HTTPS 加密傳輸
- 輸入驗證和清理

## 🚀 未來改進方向

1. **完整實施 ViewModel 綁定**
   - 目前 ViewController 仍保留部分業務邏輯
   - 逐步遷移至 ViewModel

2. **加入單元測試**
   - ViewModel 單元測試
   - Service 層測試
   - UI 測試

3. **實施 Combine/RxSwift**
   - 響應式程式設計
   - 資料綁定自動化
   - 減少樣板程式碼

4. **Core Data 整合**
   - 本地資料庫支援
   - 離線功能增強
   - 資料同步機制

## 📝 開發指南

### 新增功能時的步驟
1. 評估是否可加入現有 ViewModel
2. 如需新 ViewModel，遵循現有模式
3. 服務層保持單一職責
4. 使用 Extensions 避免檔案過大
5. 遵循錯誤處理規範

### 程式碼規範
- Swift 命名慣例
- MVVM 分層原則
- 協議導向程式設計
- 依賴注入模式

---

最後更新：2025-07-17
架構版本：3.0 (MVVM Refactoring)