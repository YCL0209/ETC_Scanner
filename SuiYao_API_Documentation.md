# Sui-Yao API 使用說明

本專案為部署於 GCP VM 的 Express API，提供 HTTPS 通訊、API 金鑰驗證機制、檔案上傳與下載、JSON 資料接收等基本功能。

## 🔐 認證方式

所有 API 路由需透過 `x-api-key` 標頭傳入正確金鑰：

```
x-api-key: MasHsieh0817
```

---

## 📑 API 路由總覽

### ✅ GET `/api/status`

伺服器健康檢查。

```bash
curl -H "x-api-key: MasHsieh0817" https://sui-yao.com/api/status
```

---

### ✅ GET `/api/test`

測試伺服器運作與 Node.js 環境資訊。

```bash
curl -H "x-api-key: MasHsieh0817" https://sui-yao.com/api/test
```

---

### ✅ POST `/api/data`

傳送 JSON 資料到伺服器。

```bash
curl -H "x-api-key: MasHsieh0817" \
     -H "Content-Type: application/json" \
     -d '{"name":"Linh","message":"Hello World"}' \
     https://sui-yao.com/api/data
```

---

### ✅ POST `/api/file/upload`

上傳單一檔案至伺服器（建議為 .csv）。

```bash
curl -H "x-api-key: MasHsieh0817" \
     -F "file=@test.csv" \
     https://sui-yao.com/api/file/upload
```

> 請將 `test.csv` 換成你實際欲上傳的檔案名稱。

---

### ✅ GET `/api/file/list`

取得所有已上傳的 `.csv` 檔案清單。

```bash
curl -H "x-api-key: MasHsieh0817" https://sui-yao.com/api/file/list
```

---

### ✅ GET `/api/file/download?fileName=xxx.csv`

下載指定檔案。

```bash
curl -H "x-api-key: MasHsieh0817" \
     -OJ "https://sui-yao.com/api/file/download?fileName=1684493209123_test.csv"
```

> 替換 `fileName` 為實際存在的檔案名稱。

---

## ⚠️ 注意事項

- 所有 API 均需透過 HTTPS 存取。
- 金鑰為固定字串，請勿洩漏。
- 上傳的檔案儲存在伺服器 `/uploads` 目錄下。
- 目前僅支援單檔上傳，不支援批量。

---

## 👨‍💻 維護者

API Maintained by Mas Hsieh  
部署主機：https://sui-yao.com