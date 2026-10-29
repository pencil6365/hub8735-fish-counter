# crimson typhoon manual

HUB8735 Ultra 智慧魚缸｜從 GitHub 下載到攝影機串流燒錄完成｜2026/10/29

## 這份手冊要完成什麼

這次的方式是：**8735 鏡頭拍魚缸 → Wi-Fi 傳送 RTSP 影像 → 筆電載入 `.pt` 辨識魚。**

燒進板子的是 `HUB8735_RTSP_Basic.ino` 編譯後的韌體；`.pt` 留在電腦，不上傳到 Arduino，也不用改成 `.nb`。

本手冊到「VLC 能看到攝影機畫面」為止。電腦 AI 辨識環境另需準備，串流成功不等於已經會框魚。未取得官方魚 `.nb` 前，不能聲稱 8735 已可獨立辨識。

**如果板子現有程式已能正常提供 RTSP，且現場 Wi-Fi 設定不用改，可以直接跳到步驟 8，不必覆寫板子。**

## 1. 從 GitHub 下載

[開啟專案下載頁](https://github.com/pencil6365/hub8735-fish-counter/releases/tag/v0.1.0-transfer)

第一次使用請下載 **`HUB8735_Fish_Transfer_20261028.zip`，約 810 MB**。

不要選：

- `Ameba_Fish_Conversion_Kit_20261029.zip`：這是約 11 MB 的官網轉檔素材包。
- `HUB8735_Fish_Source_20261028.zip` 或 GitHub 自動產生的 `Source code`：沒有完整離線工具。

右鍵 ZIP →「全部解壓縮」，讓操作入口直接在 `C:\Fish\00_START.cmd`，不要多套一層很長的資料夾。

至少預留 3 GB 空間。已經解壓並修好環境的組員，**不用重下載或覆蓋現有 `C:\Fish`**。

## 2. 確認資料夾和準備條件

| 用途 | 完整路徑 |
|---|---|
| 這次使用的串流 Arduino 程式 | `C:\Fish\project\HUB8735_RTSP_Basic\HUB8735_RTSP_Basic.ino` |
| 之後供電腦載入的魚模型 | `C:\Fish\project\FishModel_Run_20261027\delivery\fish_reparam.pt` |
| 可攜 Arduino CLI | `C:\Fish\portable\arduino-cli.exe` |
| 初始化後的 CLI 設定 | `C:\Fish\portable\runtime\arduino-cli.yaml` |
| 本次串流編譯輸出 | `C:\Fish\portable\runtime\build-rtsp\` |
| 相同版本的開發板與工具 | `C:\Fish\portable\runtime\data\packages\ideasHatch\` |

本手冊的編譯指令適用於**已初始化成功的可攜環境**。組員已回報修正 Windows 無法解 `.bz2` 的初始化方式，並離線安裝套件、成功編譯串流版；這是組員回報，仍以他電腦當前檔案為準。

第一次拿到套件的人，先使用 `00_START.cmd` 選 1 準備環境。若出現 `.bz2` 解壓失敗，先找已修好版本的組員協助，不能假設原始選單在每台 Windows 都正常。

另外準備：Arduino IDE（編輯及序列監控）、VLC（看 RTSP）、正常資料線、穩定供電。缺 USB 驅動時先依裝置管理員硬體 ID 確認型號，不猜測驅動種類。

## 3. 填入現場 Wi-Fi

Arduino IDE 選「檔案 → 開啟」，開啟：

```text
C:\Fish\project\HUB8735_RTSP_Basic\HUB8735_RTSP_Basic.ino
```

找到 `ssid` 與 `pass` 兩行，改成現場熱點／Wi-Fi 的真實資料，例如：

```cpp
char ssid[] = "YOUR_WIFI_SSID";
char pass[] = "YOUR_WIFI_PASSWORD";
```

以上是占位文字，必須自行替換。儲存後，讓筆電也連到能和板子互通的同一個網路。熱點名稱、密碼及用哪一支設備開熱點，出門前先決定。

不要把密碼提交到 GitHub 或放進公開截圖。如果名稱或密碼含雙引號或反斜線，請由熟悉 C++ 的人處理字串轉義，不要亂刪符號。

**這次不要開 `HUB8735_FishCounter_V7.ino`，也不要使用根選單的 3／4；那些是尚待 `.nb` 的魚模型流程。**

## 4. 開啟 PowerShell，核對可攜環境

Arduino IDE 在這次用於編輯和監控；編譯與上傳用組員已準備好的可攜 CLI。這樣不必把相同套件再裝進 IDE 的另一套環境。

在 Windows 開啟 PowerShell，貼上下列內容。後續指令都在**同一個 PowerShell 視窗**執行。

```powershell
Set-Location C:\Fish

$fishCli = 'C:\Fish\portable\arduino-cli.exe'
$fishConfig = 'C:\Fish\portable\runtime\arduino-cli.yaml'
$fishSketch = 'C:\Fish\project\HUB8735_RTSP_Basic'
$fishBuild = 'C:\Fish\portable\runtime\build-rtsp'
$fishBoard = 'ideasHatch:AmebaPro2:Ameba_HUB-8735_ultra:01_AutoUploadMode=Disable,02_UploadBaudrate=1M,03_EraseFlash=Disable,04_CameraOption=f37,05_FCSMode=Disable,06_LoadNNModelSource=flash,07_SHOWNNLOGS=Enable,08_OTAMode=Disable,09_StdLibInit=Enable'
$fishRtspCompiled = $false

if (!(Test-Path -LiteralPath $fishCli) -or !(Test-Path -LiteralPath $fishConfig)) {
    throw '缺少工具或初始化設定，請先處理離線環境。'
}

& $fishCli --config-file $fishConfig core list
if ($LASTEXITCODE -ne 0) {
    throw '無法列出開發板套件，請先保留錯誤訊息。'
}
```

應看到 `ideasHatch:AmebaPro2` 與 `4.0.15-Release`（組員工具可能顯示為 4.0.15，請核對安裝版本）。若找不到檔案或版本不符，先停止，不要覆蓋已修好的環境。

程式設定的意思：HUB-8735_ultra、JXF37、Auto Flash Disable、Erase Flash Disable、上傳 921600、FCS/OTA Disable。`NN Model Flash` 是套件選項，這份純串流程式沒有載入魚模型。

## 5. 編譯串流程式，不會改板子

在剛才同一個 PowerShell 貼上：

```powershell
$fishRtspCompiled = $false
$fishIno = Join-Path $fishSketch 'HUB8735_RTSP_Basic.ino'
$fishSourceHash = (Get-FileHash -LiteralPath $fishIno -Algorithm SHA256).Hash

& $fishCli --config-file $fishConfig compile --fqbn $fishBoard --build-path $fishBuild $fishSketch

if ($LASTEXITCODE -ne 0) {
    throw '編譯失敗，不要繼續燒錄。請保留完整錯誤。'
}

$fishBin = Join-Path $fishBuild 'flash_ntz.bin'
if (!(Test-Path -LiteralPath $fishBin)) {
    throw '沒有產生 flash_ntz.bin，不要繼續燒錄。'
}
if ((Get-FileHash -LiteralPath $fishIno -Algorithm SHA256).Hash -ne $fishSourceHash) {
    throw '編譯期間程式有改動，請重新編譯。'
}

$fishBinaryHash = (Get-FileHash -LiteralPath $fishBin -Algorithm SHA256).Hash
$fishRtspCompiled = $true
Write-Host '串流版編譯成功，尚未燒錄。'
```

成功後應有：

```text
C:\Fish\portable\runtime\build-rtsp\flash_ntz.bin
```

編譯失敗，即使資料夾殘留舊 `.bin` 也不能直接使用。若修改 Wi-Fi 或程式，請重做步驟 5。以上核對適用於原本單一 `.ino` 純串流專案；若另外新增頭檔或改動工具，請重新評估，不依此核對冒充完整驗證。

## 6. 接板子與進入下載模式

1. 使用已確認正常的右側 USB 接口與可傳資料線。接口方向依先前鏡頭朝上、USB 朝下的照片；其他硬體修訂先看板上標示。
2. 裝置管理員 → 連接埠（COM 和 LPT），確認實際 COM。組員先前回報 COM3，換機或換孔後仍需再確認。
3. 關閉 Arduino IDE 序列監控及其他占用該埠的工具。
4. 明確確認願意覆寫板上現有程式，才往下做。
5. 按住左側較小的下載／功能按鈕 → 短按右側較大的 Reset → 放開左小按鈕。

不要靠燈色或長按秒數猜下載模式。不要選全片清除 Flash，也不要通電時拔接相機排線。

## 7. 上傳／燒錄

**這一步會覆寫板子。必須已完成這次編譯，且取得板子負責人的確認。**

仍在同一個 PowerShell 視窗貼上：

```powershell
if ($fishRtspCompiled -ne $true) {
    throw '請在同一視窗先完成步驟 4、5，不能直接上傳舊成品。'
}
if ((Get-FileHash -LiteralPath $fishIno -Algorithm SHA256).Hash -ne $fishSourceHash) {
    throw '程式或 Wi-Fi 設定已改，請先重新編譯。'
}
if ((Get-FileHash -LiteralPath $fishBin -Algorithm SHA256).Hash -ne $fishBinaryHash) {
    throw '編譯成品已變更，請重新編譯。'
}

$fishPort = (Read-Host '輸入板子實際序列埠，例如 COM3').Trim().ToUpper()
if ($fishPort -notmatch '^COM[1-9][0-9]*$') {
    throw 'COM 埠格式錯誤。'
}
if ((Read-Host '確認覆寫且已進入下載模式，請輸入 FLASH') -cne 'FLASH') {
    throw '已取消燒錄。'
}

$fishToolBin = 'C:\Fish\portable\runtime\data\packages\ideasHatch\tools\ameba_pro2_tools\1.4.1\flash_ntz.bin'
if (!(Test-Path -LiteralPath (Split-Path $fishToolBin -Parent))) {
    throw '工具路徑與預期不同，請先核對安裝位置。'
}
Copy-Item -LiteralPath $fishBin -Destination $fishToolBin -Force -ErrorAction Stop

& $fishCli --config-file $fishConfig upload --fqbn $fishBoard --port $fishPort --input-dir $fishBuild $fishSketch

if ($LASTEXITCODE -ne 0) {
    throw '上傳工具回報失敗，請保留完整訊息，不視為燒錄完成。'
}
Write-Host '上傳工具回報成功；接著按 Reset 並檢查影像。'
```

複製到固定工具目錄，是因為廠商上傳器會從該目錄取用韌體。請勿同時開另一份專案使用相同工具目錄編譯／上傳。

上傳中不要拔線或斷電。若等待逾時，先看 COM、下載模式、線材與電源，不要立即清 Flash。

## 8. 重新啟動，取得 RTSP 網址

1. 上傳工具回報成功後，開 Arduino IDE，選實際 COM 埠。
2. 工具 → 序列監控視窗，鮑率設 **115200**。
3. 只短按一下板子的 Reset，不按下載按鈕。
4. 等 Wi-Fi 連線，找印出的完整 `rtsp://...` 網址。

```text
rtsp://實際IP位址:實際埠號
```

網址由板子連線後的 IP 與 RTSP 埠組成，不是寫死。不要套用其他人的 IP，也不要省略實際印出的埠或路徑。

一直出現 `Attempting to connect...` 時，先確認熱點有開、Wi-Fi 名稱密碼正確。這份原純串流程式會一直等待連線，因此沒有 Wi-Fi 時不會啟動攝影機串流；不要套用新版 AI 草稿的無 Wi-Fi 行為。

## 9. 用 VLC 驗證串流

筆電與板子在可互通的同一區域網路。VLC：

**媒體 → 開啟網路串流 → 貼上實際 RTSP 網址 → 播放**

看到鏡頭畫面，才確認這次串流韌體能運作。只有上傳成功或看到網址，都不等於畫面已驗證。

接著可測拔電後重新供電，Wi-Fi 開著時能否自行恢復串流。記錄實際結果，不要未測就寫通過。

## 10. 電腦如何辨識魚

模型放在：

```text
C:\Fish\project\FishModel_Run_20261027\delivery\fish_reparam.pt
```

下一階段在筆電準備 Python／PyTorch／影像讀取等相容環境，再讓電腦辨識程式讀取 RTSP 並載入 `.pt`，顯示魚框和計數。電腦需要持續開著；不需要等官方 `.nb`。

**不要直接執行舊 `03_PreviewOnComputer.cmd` 並假設會成功**：它指向原有 Python 虛擬環境，而該環境未包含在搬機 ZIP。電腦辨識環境未完成時，燒錄成功仍只會有攝影機畫面。

日後若要 8735 自己辨識、不靠筆電跑 AI，才需官方魚 `.nb`，完成新 AI 專案的安裝、編譯、確認後燒錄及實測。不能把 `.pt` 改副檔名當 `.nb`。

## 遇到問題先看這張表

| 現象 | 先檢查 |
|---|---|
| 找不到 CLI 或 YAML | 是否完整解壓、初始化；是否多套資料夾；不要覆蓋組員修正版 |
| Windows 解不開 `.bz2` | 使用組員已修好的離線安裝流程，保留原版備份 |
| `locale::facet...` / C.UTF-8 錯誤 | 若有繼承的 locale，在本 PowerShell 程序暫設 `$env:LANG='C'; $env:LC_ALL='C'; $env:LC_CTYPE='C'` 再重編譯，不改 Windows 全域設定 |
| 長路徑找不到檔案／工具出錯 | 使用 `C:\Fish` 短英文路徑 |
| 編譯失敗 | 保留完整錯誤；不得只憑舊 bin 繼續燒錄 |
| COM 不見／黃色驚嘆號 | 正確 USB 孔、資料線、裝置管理員與對應官方驅動 |
| Access denied／COM busy | 關閉序列監控與占用同一 COM 的工具 |
| Upload timeout | 核對實際 COM、下載模式、線材和電源；不要先清 Flash |
| 監控亂碼 | 核對 115200、COM 與重啟日誌 |
| 一直連 Wi-Fi | 熱點名稱密碼、熱點是否開啟、訊號與網路相容性 |
| 有 RTSP 網址但 VLC 沒畫面 | 實際網址、網路互通、隔離設定、相機與串流日誌；不要任意關閉防火牆 |
| 有畫面但沒有魚框 | 這份韌體只有串流；還需啟動筆電辨識程式 |

## 給下一個協助者

先確認目前 `C:\Fish` 的實際設定、組員修正版環境及 COM，不要重新覆蓋安裝；不要把這份操作手冊當作已實際燒錄或驗收的紀錄。

使用者要求：**真正覆寫板子前必須取得明確確認；不修改原始照片或其他專案資料；Wi-Fi、登入憑證與驗證資料不得上傳公開 GitHub。**
