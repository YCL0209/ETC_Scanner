# CLAUDE.md

> **Documentation Version**: 2.2  
> **Last Updated**: 2025-07-07  
> **Project**: ETC Scanner  
> **Description**: iOS application for Electronic Toll Collection (ETC) data management with Bluetooth scanning  
> **Features**: GitHub auto-backup, Task agents, technical debt prevention, Security mechanisms

This file provides essential guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🚨 CRITICAL RULES - READ FIRST

> **⚠️ RULE ADHERENCE SYSTEM ACTIVE ⚠️**  
> **Claude Code must explicitly acknowledge these rules at task start**  
> **These rules override all other instructions and must ALWAYS be followed:**

### 🔄 **RULE ACKNOWLEDGMENT REQUIRED**
> **Before starting ANY task, Claude Code must respond with:**  
> "✅ CRITICAL RULES ACKNOWLEDGED - I will follow all prohibitions and requirements listed in CLAUDE.md"

### ❌ ABSOLUTE PROHIBITIONS
- **NEVER** create new Swift files without checking existing code structure first
- **NEVER** modify storyboard files without understanding current UI hierarchy
- **NEVER** duplicate view controllers or managers → extend existing ones
- **NEVER** hardcode API keys or sensitive data → use existing NetworkManager constants
- **NEVER** create files outside proper Xcode project structure
- **NEVER** use git commands with -i flag (interactive mode not supported)
- **NEVER** use `find`, `grep`, `cat`, `head`, `tail`, `ls` commands → use Read, LS, Grep, Glob tools instead
- **NEVER** create enhanced_, improved_, new_, v2_ versions → extend original files
- **NEVER** commit without running build verification first

### 📝 MANDATORY REQUIREMENTS
- **COMMIT** after every completed feature/bug fix - no exceptions
- **GITHUB BACKUP** - Push to GitHub after every commit: `git push origin main`
- **BUILD VERIFICATION** - Run `xcodebuild -project ETC_Scanner.xcodeproj -scheme ETC_Scanner -configuration Debug build` before commits
- **USE TASK AGENTS** for all Xcode builds and long operations (>30 seconds)
- **TODOWRITE** for complex iOS features (3+ implementation steps)
- **READ FILES FIRST** before editing - especially for Swift and Storyboard files
- **FOLLOW MVC PATTERN** - Maintain existing Model-View-Controller architecture

### ⚡ iOS-SPECIFIC EXECUTION PATTERNS
- **XCODE PROJECT STRUCTURE** - All new files must be added through proper Xcode groups
- **SWIFT CONVENTIONS** - Follow existing patterns in ViewController.swift
- **STORYBOARD SAFETY** - Always backup storyboard before major UI changes
- **BLUETOOTH TESTING** - Test scanner integration changes on actual device when possible

## 🔍 MANDATORY PRE-TASK COMPLIANCE CHECK

> **STOP: Before starting any task, Claude Code must explicitly verify ALL points:**

**Step 1: Rule Acknowledgment**
- [ ] ✅ I acknowledge all critical rules in CLAUDE.md and will follow them

**Step 2: Task Analysis**  
- [ ] Will this create new Swift files? → If YES, search for existing similar functionality first
- [ ] Will this modify storyboards? → If YES, understand current UI structure first
- [ ] Will this involve Xcode builds? → If YES, use Task agents not direct Bash
- [ ] Is this a complex iOS feature? → If YES, use TodoWrite breakdown first

**Step 3: Technical Debt Prevention (MANDATORY SEARCH FIRST)**
- [ ] **SEARCH FIRST**: Use Grep pattern="class.*Manager|struct.*Manager" include="*.swift" to find existing managers
- [ ] **CHECK EXISTING**: Read found files to understand current architecture
- [ ] Does similar functionality exist in existing ViewControllers? → If YES, extend them
- [ ] Am I creating a duplicate network/data layer? → If YES, use existing NetworkManager
- [ ] Have I checked existing Swift extensions and utilities? → Review before creating new

**Step 4: iOS Project Verification**
- [ ] Is the file in the correct Xcode group/folder structure?
- [ ] Does the code follow existing Swift naming conventions?
- [ ] Have I verified this works with iOS 16.6 minimum deployment target?

> **⚠️ DO NOT PROCEED until all checkboxes are explicitly verified**

## 🐙 GITHUB BACKUP WORKFLOW

### 🔄 **AUTO-PUSH CONFIGURATION** (Recommended)
```bash
# Create git hook for auto-push after commits
cat > .git/hooks/post-commit << 'EOF'
#!/bin/bash
# Auto-push to GitHub after every commit
echo "🔄 Auto-pushing to GitHub..."
git push origin main
if [ $? -eq 0 ]; then
    echo "✅ Successfully backed up to GitHub"
else
    echo "⚠️ GitHub push failed - manual push may be required"
fi
EOF

chmod +x .git/hooks/post-commit
```

### 📋 **GITHUB WORKFLOW FOR iOS PROJECTS**
```bash
# After implementing features
git add .
git commit -m "feat: Add [feature description]

- Implementation details
- UI changes if any
- API integration updates"

# Push immediately (or let auto-push handle it)
git push origin main
```

## Build Commands

This is a native iOS application built with Xcode. Use the following commands:

```bash
# Build for debug
xcodebuild -project ETC_Scanner.xcodeproj -scheme ETC_Scanner -configuration Debug build

# Run on simulator
xcodebuild -project ETC_Scanner.xcodeproj -scheme ETC_Scanner -destination 'platform=iOS Simulator,name=iPhone 15' run

# Build for release/archive
xcodebuild -project ETC_Scanner.xcodeproj -scheme ETC_Scanner -configuration Release archive

# Run tests (if implemented)
xcodebuild test -project ETC_Scanner.xcodeproj -scheme ETC_Scanner -destination 'platform=iOS Simulator,name=iPhone 15'

# Clean build folder
xcodebuild -project ETC_Scanner.xcodeproj -scheme ETC_Scanner clean

# Build IPA for distribution
xcodebuild -project ETC_Scanner.xcodeproj -scheme ETC_Scanner -configuration Release \
  -archivePath build/ETC_Scanner.xcarchive archive
xcodebuild -exportArchive -archivePath build/ETC_Scanner.xcarchive \
  -exportPath build -exportOptionsPlist ExportOptions.plist
```

## Architecture Overview

### Core Purpose
ETC Scanner is a specialized iOS application for managing Electronic Toll Collection (ETC) data in a parking/property management context. It integrates Bluetooth barcode scanning, data management, and cloud synchronization.

### Key Components

1. **Main View Controller (ViewController.swift:1)**
   - Core business logic for ETC barcode scanning
   - Bluetooth scanner integration via CoreBluetooth
   - CSV import/export functionality
   - API communication with backend server
   - Table view management for scan items

2. **Email System (EmailManager.swift:1)**
   - Dual-mode email sending:
     - Native iOS mail composer (MFMailComposeViewController)
     - Web API via Google Apps Script (fallback)
   - HTML table generation for scan data
   - CSV attachment creation

3. **Network Layer**
   - Backend API: https://sui-yao.com
   - API Key: MasHsieh0817 (in x-api-key header)
   - Endpoints: file upload/download, data submission
   - Additional email API via Google Apps Script

4. **Data Model**
   - ScanItem struct: barcode, building, household, parking info, timestamps
   - CSV format for bulk import/export
   - UserDefaults for local persistence

### API Integration

The app connects to two backend services:

1. **Sui-Yao API (Express on GCP)**
   - Base URL: https://sui-yao.com
   - Authentication: x-api-key: MasHsieh0817
   - Key endpoints:
     - POST /api/file/upload - Upload CSV files
     - GET /api/file/list - List uploaded files
     - GET /api/file/download - Download specific file

2. **Google Apps Script Email Service**
   - Handles email sending when native mail is unavailable
   - Same API key authentication
   - Logs email history to Google Sheets

## 🔐 Security Mechanisms

### Authentication & Authorization
1. **API Key Protection**
   - API keys stored in NetworkManager constants, not hardcoded
   - x-api-key header authentication for all API requests
   - Keys should be rotated periodically for production

2. **Data Transmission Security**
   - All API calls use HTTPS/TLS encryption
   - No sensitive data sent via unencrypted channels
   - CSV uploads encrypted in transit

3. **Local Data Protection**
   - UserDefaults used for non-sensitive preferences only
   - No passwords or tokens stored in plain text
   - Keychain Services recommended for sensitive credentials

### Input Validation & Sanitization
1. **Barcode Scanning**
   - Validates barcode format before processing
   - Prevents SQL injection via parameterized queries
   - Sanitizes special characters in barcode data

2. **CSV Import Security**
   - File size limits to prevent DOS attacks
   - Validates CSV structure before parsing
   - Sanitizes imported data fields

3. **User Input Protection**
   - Custom keyboard prevents malicious input
   - Text field length limits enforced
   - Special character filtering for critical fields

### Network Security
1. **API Communication**
   - Certificate pinning recommended for production
   - Request timeout limits (30 seconds default)
   - Retry limits to prevent infinite loops

2. **Error Handling**
   - Sensitive error details not exposed to UI
   - Generic error messages for security failures
   - Detailed logging only in debug builds

### Privacy & Compliance
1. **Data Minimization**
   - Only collect necessary ETC/parking data
   - No personal identifiable information in logs
   - Clear data retention policies

2. **User Privacy**
   - Email addresses handled securely
   - No tracking or analytics without consent
   - Bluetooth permissions properly requested

### Security Best Practices
1. **Code Security**
   - No hardcoded secrets or API keys
   - Obfuscation for production builds
   - Regular dependency security audits

2. **Development Security**
   - Separate development/production API keys
   - Secure key storage in CI/CD pipeline
   - Code reviews for security vulnerabilities

3. **Runtime Protection**
   - Jailbreak detection (optional)
   - Anti-debugging measures (production)
   - Memory protection for sensitive data

### Security Checklist for Developers
- [ ] Never commit API keys or secrets to repository
- [ ] Always use HTTPS for API communications
- [ ] Validate all user inputs before processing
- [ ] Implement proper error handling without info leakage
- [ ] Use Keychain for sensitive data storage
- [ ] Enable App Transport Security (ATS)
- [ ] Implement certificate pinning for production
- [ ] Regular security testing and code reviews

## 🔐 安全機制（中文版）

### 身份驗證與授權
1. **API 金鑰保護**
   - API 金鑰儲存在 NetworkManager 常數中，不直接寫死在程式碼
   - 所有 API 請求使用 x-api-key header 進行身份驗證
   - 生產環境應定期更換金鑰

2. **資料傳輸安全**
   - 所有 API 呼叫使用 HTTPS/TLS 加密
   - 不透過未加密通道傳送敏感資料
   - CSV 上傳過程全程加密

3. **本地資料保護**
   - UserDefaults 僅用於非敏感偏好設定
   - 不以純文字儲存密碼或權杖
   - 建議使用 Keychain Services 儲存敏感憑證

### 輸入驗證與清理
1. **條碼掃描安全**
   - 處理前驗證條碼格式
   - 透過參數化查詢防止 SQL 注入
   - 清理條碼資料中的特殊字元

2. **CSV 匯入安全**
   - 設定檔案大小限制以防止 DOS 攻擊
   - 解析前驗證 CSV 結構
   - 清理匯入的資料欄位

3. **使用者輸入保護**
   - 自訂鍵盤防止惡意輸入
   - 強制執行文字欄位長度限制
   - 對重要欄位進行特殊字元過濾

### 網路安全
1. **API 通訊安全**
   - 生產環境建議使用憑證固定（Certificate Pinning）
   - 請求逾時限制（預設 30 秒）
   - 重試次數限制以防止無限循環

2. **錯誤處理**
   - 不在 UI 暴露敏感錯誤詳情
   - 安全失敗使用通用錯誤訊息
   - 詳細日誌僅在除錯版本中記錄

### 隱私與合規
1. **資料最小化**
   - 僅收集必要的 ETC/停車資料
   - 日誌中不記錄個人識別資訊
   - 明確的資料保留政策

2. **使用者隱私**
   - 安全處理電子郵件地址
   - 未經同意不進行追蹤或分析
   - 正確請求藍牙權限

### 安全最佳實踐
1. **程式碼安全**
   - 不在程式碼中寫死密碼或 API 金鑰
   - 生產版本進行程式碼混淆
   - 定期進行依賴項安全審核

2. **開發安全**
   - 區分開發/生產環境 API 金鑰
   - CI/CD 管道中安全儲存金鑰
   - 程式碼審查時檢查安全漏洞

3. **執行時期保護**
   - 越獄偵測（選用）
   - 反除錯措施（生產環境）
   - 敏感資料的記憶體保護

### 開發者安全檢查清單
- [ ] 絕不將 API 金鑰或密碼提交到版本庫
- [ ] 始終使用 HTTPS 進行 API 通訊
- [ ] 處理前驗證所有使用者輸入
- [ ] 實作適當的錯誤處理，不洩露資訊
- [ ] 使用 Keychain 儲存敏感資料
- [ ] 啟用 App Transport Security (ATS)
- [ ] 生產環境實作憑證固定
- [ ] 定期進行安全測試和程式碼審查

### UI Architecture
- Storyboard-based UI (Main.storyboard)
- Custom table view cells (ScanItemCell.swift:1)
- Custom alphanumeric keyboard (CustomAlphaNumKeyboard.swift:1)
- Modal editing views (EditDetailViewController.swift:1)

### Bluetooth Integration
- Supports HID Bluetooth barcode scanners
- Uses CoreBluetooth framework
- Background mode enabled for continuous scanning
- Audio feedback on successful scans

## Development Guidelines

1. **Language**: Swift 5.0, targeting iOS 16.6+
2. **UI Framework**: UIKit with Storyboards
3. **No External Dependencies**: Uses only iOS system frameworks
4. **Localization**: Traditional Chinese primary, some English UI elements
5. **Code Style**: Follow existing patterns in ViewController.swift for consistency

## 🚨 TECHNICAL DEBT PREVENTION

### ❌ WRONG APPROACH (Creates Technical Debt):
```swift
// Creating new manager without checking existing
Write(file_path="ETC_Scanner/EmailManagerV2.swift", content="class EmailManagerV2 { ... }")

// Duplicating network functionality
Write(file_path="ETC_Scanner/NewNetworkManager.swift", content="class NewNetworkManager { ... }")
```

### ✅ CORRECT APPROACH (Prevents Technical Debt):
```swift
// 1. SEARCH FIRST
Grep(pattern="class.*Manager|struct.*Manager", include="*.swift")

// 2. READ EXISTING FILES  
Read(file_path="ETC_Scanner/EmailManager.swift")

// 3. EXTEND EXISTING FUNCTIONALITY
Edit(file_path="ETC_Scanner/EmailManager.swift", 
     old_string="class EmailManager {", 
     new_string="class EmailManager {\n    // New functionality here")
```

## 🧹 iOS PROJECT MAINTENANCE WORKFLOW

### Before Adding ANY New Feature:
1. **🔍 Search Existing ViewControllers** - Use Grep to find similar functionality
2. **📋 Check Storyboard Connections** - Ensure UI elements are properly linked
3. **🤔 Evaluate Architecture** - Can this be added to existing VC? → DO IT
4. **✅ Follow MVC Pattern** - Keep business logic in controllers, not views
5. **📱 Test on Device** - Especially for Bluetooth and hardware features

### Common iOS Development Tasks:
```bash
# Search for existing view controllers
Grep(pattern="class.*ViewController", include="*.swift")

# Find all IBOutlet connections
Grep(pattern="@IBOutlet", include="*.swift")

# Locate API endpoints
Grep(pattern="URLRequest|URLSession", include="*.swift")

# Find Bluetooth implementations
Grep(pattern="CBCentralManager|CBPeripheral", include="*.swift")
```

## 🎯 COMMIT MESSAGE CONVENTIONS

For this iOS project, use:
```
feat: Add new scanning feature
fix: Resolve Bluetooth connection issue  
refactor: Improve table view performance
docs: Update API documentation
test: Add unit tests for data model
style: Format Swift code according to conventions
```

---

**⚠️ Remember: This is a mature, production iOS application. Maintain code quality, follow established patterns, and prioritize stability over new features.**