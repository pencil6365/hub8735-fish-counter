param([switch]$CheckOnly,[switch]$PrepareOnly,[switch]$CompileOnly)
$ErrorActionPreference='Stop'$env:LANG='C'; $env:LC_ALL='C'; $env:LC_CTYPE='C'
$root=Split-Path $PSScriptRoot -Parent
$script:data=Join-Path $root 'portable\runtime\data'
$script:cli=Join-Path $PSScriptRoot 'arduino-cli.exe'
$script:cfg=Join-Path $PSScriptRoot 'runtime\arduino-cli.yaml'
$script:sketch=Join-Path $root 'project\FishModel_Run_20261027\delivery\HUB8735_FishCounter_V7'
$script:fqbn='ideasHatch:AmebaPro2:Ameba_HUB-8735_ultra:01_AutoUploadMode=Disable,02_UploadBaudrate=1M,03_EraseFlash=Disable,04_CameraOption=f37,05_FCSMode=Disable,06_LoadNNModelSource=flash,07_SHOWNNLOGS=Enable,08_OTAMode=Disable,09_StdLibInit=Enable'
$script:build=Join-Path $root 'portable\runtime\build'
function Write-Utf8($p,$s) { [IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false))) }
function Invoke-Cli([string[]]$Arguments) {
    & $script:cli --config-file $script:cfg @Arguments
    if($LASTEXITCODE -ne 0) { throw "Arduino 工具回報失敗，代碼 $LASTEXITCODE。不要繼續燒錄。" }
}
function Initialize-Environment {    if ($root.Length -gt 30 -or $root -match '[^\x20-\x7E]') { throw '請把整個套件解壓至 C:\Fish 等短英文路徑再開啟。' }
    if (-not (Get-Command tar.exe -ErrorAction SilentlyContinue)) { throw '需要 Windows 10/11 內建 tar.exe。請使用 Windows 11 64 位元電腦。' }
    $runtime=Join-Path $PSScriptRoot 'runtime'
    New-Item -ItemType Directory -Force $runtime,$script:data,(Join-Path $runtime 'user'),(Join-Path $runtime 'downloads') | Out-Null
    $marker=Join-Path $runtime 'environment-ready.json'
    if (-not (Test-Path -LiteralPath $marker)) {
        Write-Host '首次準備離線編譯環境，約需 1.5 GB 空間及數分鐘，請等候。'
        $base=Join-Path $script:data 'packages\ideasHatch'
        $jobs=@(
            @('4.0.15-build20250402_HUB8735.tar.gz','hardware\AmebaPro2\4.0.15-Release'),
            @('ameba_pro2_toolchain_windows-1.0.1-p1.tar.bz2','tools\ameba_pro2_toolchain\1.0.1-p1'),
            @('ameba_pro2_toolchain_windows-1.0.1-p2.tar.bz2','tools\ameba_pro2_toolchain2\1.0.1-p2'),
            @('ameba_pro2_tools_windows-1.4.1.tar.gz','tools\ameba_pro2_tools\1.4.1'),
            @('ameba_pro2_nn_models-1.0.2.tar.gz','tools\ameba_pro2_nn_models\1.0.2'))
        foreach($job in $jobs) {
            $dest=Join-Path $base $job[1]
            New-Item -ItemType Directory -Force $dest | Out-Null
            Write-Host ('解開：'+$job[0])
            & tar.exe -xf (Join-Path $PSScriptRoot ('assets\'+$job[0])) -C $dest --strip-components 1
            if($LASTEXITCODE -ne 0) { throw ('解壓失敗：'+$job[0]) }
        }
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'builtin') -Destination (Join-Path $script:data 'packages\builtin') -Recurse -Force
        Copy-Item -Path (Join-Path $PSScriptRoot 'assets\*.json') -Destination $script:data -Force        Copy-Item -Path (Join-Path $PSScriptRoot 'assets\*.sig') -Destination $script:data -Force
        Write-Utf8 $marker '{"board_package":"4.0.15-Release","initialized":true}'
    }
    $pathData=$script:data.Replace('\','/')
    $pathDownloads=(Join-Path $runtime 'downloads').Replace('\','/')
    $pathUser=(Join-Path $runtime 'user').Replace('\','/')
    $pathCache=(Join-Path $runtime 'cache').Replace('\','/')
    Write-Utf8 $script:cfg "directories:`n  data: '$pathData'`n  downloads: '$pathDownloads'`n  user: '$pathUser'`nbuild_cache:`n  path: '$pathCache'`n"
}
function Test-Model {
    $model=Join-Path $script:sketch 'yolov7_tiny.nb'
    $config=Get-Content -Raw -LiteralPath (Join-Path $script:sketch 'FishConfig.h')
    $install=Join-Path $script:sketch 'model-install.json'
    if(!(Test-Path -LiteralPath $model) -or !(Test-Path -LiteralPath $install) -or $config -notmatch '#define FISH_MODEL_READY 1' -or $config -notmatch '#define FISH_MODEL_STAGED 1') {
        throw '還沒有安裝官方 .nb 魚模型。請先選 2；目前不能編譯/燒錄魚隻 AI。'
    }
    $record=Get-Content -Raw -LiteralPath $install | ConvertFrom-Json
    if((Get-FileHash -LiteralPath $model -Algorithm SHA256).Hash.ToLower() -ne $record.sha256) { throw '模型與安裝記錄不同，請重新核對。' }
}
function Install-Model {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog=New-Object Windows.Forms.OpenFileDialog
    $dialog.Title='選擇 Ameba 官方轉換完成的魚模型（.nb）'
    $dialog.Filter='NB model (*.nb)|*.nb'
    if($dialog.ShowDialog() -ne 'OK') { return }
    $source=Get-Item -LiteralPath $dialog.FileName
    if($source.Length -le 100000 -or $source.Length -ge 35000000) { throw '模型大小不符合預期。請核對官方下載的檔案。' }
    Write-Host '請確認這是 fish 單類別、YOLOv7-tiny、RGB 416x416、UINT8 官方轉換的模型。'
    if((Read-Host '確認設定正確請輸入 YES') -cne 'YES') { return }
    $dest=Join-Path $script:sketch 'yolov7_tiny.nb'
    $sha=(Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash.ToLower()
    if(Test-Path -LiteralPath $dest) {
        if((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLower() -ne $sha) { throw '已有不同模型，沒有覆寫；請先保留舊模型並確認。' }
    } else { Copy-Item -LiteralPath $source.FullName -Destination $dest }
    $ino=Join-Path $script:sketch 'HUB8735_FishCounter_V7.ino'
    $text=[IO.File]::ReadAllText($ino).Replace('selectFishModel(detector);','detector.modelSelect(OBJECT_DETECTION, CUSTOMIZED_YOLOV7TINY, NA_MODEL, NA_MODEL);')
    Write-Utf8 $ino $text
    $header=Join-Path $script:sketch 'FishConfig.h'
    Write-Utf8 $header ([IO.File]::ReadAllText($header).Replace('#define FISH_MODEL_READY 0','#define FISH_MODEL_READY 1').Replace('#define FISH_MODEL_STAGED 0','#define FISH_MODEL_STAGED 1'))
    Write-Utf8 (Join-Path $script:sketch 'model-install.json') (@{file='yolov7_tiny.nb';sha256=$sha;bytes=$source.Length;settings_confirmed_by_user=$true;semantic_validity_verified=$false;compiled=$false;flashed=$false} | ConvertTo-Json)
    Write-Host '模型已放入專案；尚未編譯、尚未燒錄。'
}
function Compile-Fish {
    Test-Model
    Initialize-Environment
    New-Item -ItemType Directory -Force $script:build | Out-Null
    $stamp=Join-Path $script:build 'verified-compile.json'
    if(Test-Path -LiteralPath $stamp) { Remove-Item -LiteralPath $stamp }
    Invoke-Cli @('compile','--fqbn',$script:fqbn,'--build-path',$script:build,$script:sketch)
    $bin=Join-Path $script:build 'flash_ntz.bin'
    if(!(Test-Path -LiteralPath $bin)) { throw '沒有產生 flash_ntz.bin，不能燒錄。' }
    $inputs=@{}; Get-ChildItem -LiteralPath $script:sketch -File | Where-Object Extension -In '.ino','.h','.nb' | ForEach-Object { $inputs[$_.Name]=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    Write-Utf8 $stamp (@{fqbn=$script:fqbn;inputs=$inputs;sha256=(Get-FileHash -LiteralPath $bin -Algorithm SHA256).Hash;flashed=$false} | ConvertTo-Json -Depth 5)
    Write-Host '編譯成功，尚未燒錄。'
}
function Upload-Fish {
    Test-Model
    Initialize-Environment
    $stamp=Join-Path $script:build 'verified-compile.json'
    if(!(Test-Path -LiteralPath $stamp)) { throw '請先選 3 完成編譯。' }
    $record=Get-Content -Raw -LiteralPath $stamp | ConvertFrom-Json
    $bin=Join-Path $script:build 'flash_ntz.bin'
    if((Get-FileHash -LiteralPath $bin -Algorithm SHA256).Hash -ne $record.sha256) { throw '編譯成品已變更，請重新編譯。' }
    $current=Get-ChildItem -LiteralPath $script:sketch -File | Where-Object Extension -In '.ino','.h','.nb'
    if($current.Count -ne @($record.inputs.PSObject.Properties).Count) { throw '專案檔案已變動，請重新編譯。' }
    foreach($file in $current) {
        if((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne $record.inputs.($file.Name)) { throw '程式或模型已變更，請先重新編譯。' }
    }
    Write-Host '目前 Windows 序列埠：'
    [IO.Ports.SerialPort]::GetPortNames() | ForEach-Object { Write-Host $_ }
    $port=(Read-Host '輸入板子的序列埠，例如 COM3（請以這台電腦實際顯示為準）').Trim().ToUpper()
    if($port -notmatch '^COM[1-9][0-9]*$') { throw '序列埠格式錯誤。' }
    Write-Host '此步驟將覆寫板上現有程式。請先關閉 Arduino 序列監控與其他占用此埠的程式。'
    Write-Host '鏡頭朝上、USB 朝下：按住左小按鈕，點一下右大 Reset，再放開左小按鈕。'
    if((Read-Host '同意覆寫且已進入下載模式，請輸入 FLASH') -cne 'FLASH') { return }
    # The vendor uploader uses a fixed tool-directory image. Always refresh from the verified build.
    $tool=Join-Path $script:data 'packages\ideasHatch\tools\ameba_pro2_tools\1.4.1'
    Copy-Item -LiteralPath $bin -Destination (Join-Path $tool 'flash_ntz.bin') -Force
    Invoke-Cli @('upload','--fqbn',$script:fqbn,'--port',$port,'--input-dir',$script:build,$script:sketch)
    Write-Host '上傳工具回報成功。按一下右大 Reset 啟動，仍需用魚缸實測辨識。'
}
try {
    if($PrepareOnly) { Initialize-Environment; Invoke-Cli @('core','list'); exit 0 }
    if($CompileOnly) { Compile-Fish; exit 0 }
    if($CheckOnly) { Write-Host ('專案位置：'+$root); Test-Model; exit 0 }
    while($true) {
        Write-Host "`n=== HUB8735 魚隻辨識搬機套件 ==="
        Write-Host '1 準備離線編譯環境（首次執行）'
        Write-Host '2 選擇官方轉檔 .nb 模型並放入專案'
        Write-Host '3 編譯魚隻 AI（不燒錄）'
        Write-Host '4 燒錄魚隻 AI（必須再次輸入 FLASH 確認）'
        Write-Host '5 開啟 Wi-Fi 設定檔（改後需重新編譯）'
        Write-Host '6 閱讀操作說明'
        Write-Host '0 結束'
        $choice=Read-Host '請輸入數字'
        try {
            switch($choice) {
                '1' { Initialize-Environment; Invoke-Cli @('core','list') }
                '2' { Install-Model }
                '3' { Compile-Fish }
                '4' { Upload-Fish }
                '5' { Start-Process notepad.exe -ArgumentList ('"'+(Join-Path $script:sketch 'WifiCredentials.h')+'"') }
                '6' { Start-Process notepad.exe -ArgumentList ('"'+(Join-Path $root '先讀我.txt')+'"') }
                '0' { exit 0 }
                default { Write-Host '請輸入 0 到 6。' }
            }
        } catch { Write-Host ('未完成：'+$_.Exception.Message) -ForegroundColor Yellow }
    }
} catch { Write-Host ('未完成：'+$_.Exception.Message) -ForegroundColor Red; exit 1 }
