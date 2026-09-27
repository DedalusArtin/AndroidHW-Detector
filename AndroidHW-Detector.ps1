<#
.SYNOPSIS
    Android 手机硬件检测工具 v2.2 (ADB-based)
.DESCRIPTION
    采集硬件 -> SoC/厂商智能匹配 -> 终端美化展示 -> 报告导出
.PARAMETER Device    指定设备序列号
.PARAMETER Export    导出报告到 reports\
.PARAMETER Quiet     结束不暂停
#>
param(
    [string]$Device,
    [switch]$Export,
    [switch]$Quiet,
    [switch]$Wireless
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReportDir  = Join-Path $ScriptRoot 'reports'

# ===== 宽度对齐: 中文字符占2列 =====
function StrWidth($s) {
    $w = 0
    foreach ($c in $s.ToCharArray()) {
        if ([int]$c -gt 0x2E80) { $w += 2 } else { $w += 1 }
    }
    return $w
}
function PadRight2($s, $targetWidth) {
    $w = StrWidth $s
    $pad = $targetWidth - $w
    if ($pad -lt 0) { $pad = 0 }
    return $s + (' ' * $pad)
}

# ===== 颜色 =====
function C($t, $c = 'White') { Write-Host $t -ForegroundColor $c }

# ===== 框线 =====
$HL = [string]::new([char]0x2550, 58)
function Section($Title) {
    $tw = [math]::Max(4, 56 - (StrWidth $Title))
    Write-Host ""
    Write-Host ([char]0x2554 + [string]::new([char]0x2550, 2) + ' ' + $Title + ' ' + ([string]::new([char]0x2550, $tw)) + [char]0x2557) -ForegroundColor Cyan
}
function KV($Key, $Value, $Color = 'White') {
    $kp = PadRight2 $Key 16
    Write-Host ('  ' + [char]0x25B6 + ' ') -NoNewline -ForegroundColor DarkGray
    Write-Host ($kp) -NoNewline -ForegroundColor Cyan
    Write-Host (': ') -NoNewline -ForegroundColor DarkGray
    Write-Host $Value -ForegroundColor $Color
}
function Rating($Label, $Score, $Max = 10) {
    $filled = [int][math]::Round($Score / $Max * 10)
    $empty = 10 - $filled
    $bar = ([string]::new([char]0x25CF, $filled)) + ([string]::new([char]0x25CB, $empty))
    $color = if ($Score -ge 8) { 'Green' } elseif ($Score -ge 5) { 'Yellow' } else { 'Red' }
    $lp = PadRight2 $Label 10
    Write-Host ('  ' + $lp) -NoNewline
    Write-Host ("[$bar]") -NoNewline -ForegroundColor $color
    Write-Host (" $Score/$Max") -ForegroundColor $color
}

# ===== ADB =====
function Adb($Serial, $Cmd) {
    $r = (cmd /c "`"$adbCmd`" -s $Serial shell $Cmd 2>&1")
    return ($r -join "`n").Trim()
}
function Prop($Serial, $Name) {
    $v = Adb $Serial "getprop $Name"
    if ($v) { return $v.Trim() }
    return ''
}

# ================================================================
#  SoC 数据库 (PSCustomObject 防止扁平化)
# ================================================================
function New-SoC($Pattern, $Name, $Process, $GPU, $Bench, $Tier) {
    [PSCustomObject]@{ P=$Pattern; N=$Name; Proc=$Process; G=$GPU; B=$Bench; T=$Tier }
}

$SoC_DB = @(
    (New-SoC 'SM8850'  'Snapdragon 8 Elite Gen 5' '3nm' 'Adreno 840'       3200000 'S 旗舰')
    (New-SoC 'SM8750'  'Snapdragon 8 Elite'       '3nm' 'Adreno 830'       2900000 'S 旗舰')
    (New-SoC 'SM8650'  'Snapdragon 8 Gen 3'       '4nm' 'Adreno 750'       2100000 'S 旗舰')
    (New-SoC 'SM8550'  'Snapdragon 8 Gen 2'       '4nm' 'Adreno 740'       1600000 'S 旗舰')
    (New-SoC 'SM8475'  'Snapdragon 8+ Gen 1'      '4nm' 'Adreno 730'       1300000 'A 旗舰')
    (New-SoC 'SM8450'  'Snapdragon 8 Gen 1'       '4nm' 'Adreno 730'       1200000 'A 旗舰')
    (New-SoC 'SM8350'  'Snapdragon 888'           '5nm' 'Adreno 660'        950000 'A 旗舰')
    (New-SoC 'SM8250'  'Snapdragon 865'           '7nm' 'Adreno 650'        800000 'A 旗舰')
    (New-SoC 'SM8150'  'Snapdragon 855'           '7nm' 'Adreno 640'        650000 'B 次旗舰')
    (New-SoC 'SM7675'  'Snapdragon 7+ Gen 3'      '4nm' 'Adreno 732'       1100000 'B 次旗舰')
    (New-SoC 'SM7550'  'Snapdragon 7s Gen 3'      '4nm' 'Adreno 710'        700000 'B 中高端')
    (New-SoC 'SM7475'  'Snapdragon 7+ Gen 2'      '4nm' 'Adreno 725'       1000000 'B 次旗舰')
    (New-SoC 'SM7450'  'Snapdragon 7 Gen 1'       '4nm' 'Adreno 662'        650000 'B 中高端')
    (New-SoC 'SM7325'  'Snapdragon 778G'          '6nm' 'Adreno 642L'       600000 'B 中高端')
    (New-SoC 'SM7315'  'Snapdragon 750G'          '8nm' 'Adreno 619'        420000 'C 中端')
    (New-SoC 'SM7225'  'Snapdragon 730G'          '8nm' 'Adreno 618'        350000 'C 中端')
    (New-SoC 'SM6450'  'Snapdragon 6 Gen 1'       '4nm' 'Adreno 710'        520000 'C 中端')
    (New-SoC 'SM6375'  'Snapdragon 695'           '6nm' 'Adreno 619'        380000 'C 中端')
    (New-SoC 'SM6225'  'Snapdragon 680'           '6nm' 'Adreno 610'        280000 'D 入门')
    (New-SoC 'SM4450'  'Snapdragon 4 Gen 1'       '6nm' 'Adreno 619'        380000 'D 入门')
    (New-SoC 'SM4250'  'Snapdragon 460'          '11nm' 'Adreno 610'        180000 'D 入门')
    (New-SoC 'MT6991'  'Dimensity 9400+'          '3nm' 'Immortalis-G925'  3000000 'S 旗舰')
    (New-SoC 'MT6989'  'Dimensity 9300+'          '4nm' 'Immortalis-G720'  2200000 'S 旗舰')
    (New-SoC 'MT6985'  'Dimensity 9200+'          '4nm' 'Immortalis-G715'  1500000 'A 旗舰')
    (New-SoC 'MT6983'  'Dimensity 9000+'          '4nm' 'Mali-G710'        1200000 'A 旗舰')
    (New-SoC 'MT6897'  'Dimensity 8400'           '4nm' 'Mali-G720'        1300000 'B 次旗舰')
    (New-SoC 'MT6886'  'Dimensity 8300'           '4nm' 'Mali-G615'        1100000 'B 次旗舰')
    (New-SoC 'MT6877'  'Dimensity 7300'           '4nm' 'Mali-G615'         650000 'C 中端')
    (New-SoC 'MT6855'  'Dimensity 1050'           '6nm' 'Mali-G610'         520000 'C 中端')
    (New-SoC 'MT6833'  'Dimensity 700'            '6nm' 'Mali-G57'          350000 'D 入门')
    (New-SoC 'MT6768'  'Helio G85'               '12nm' 'Mali-G52'          220000 'D 入门')
    (New-SoC 'MT6765'  'Helio G35'               '12nm' 'PowerVR GE8320'    120000 'D 入门')
    (New-SoC 'EXYNOS2500' 'Exynos 2500'          '3nm' 'Xclipse 950'      2500000 'S 旗舰')
    (New-SoC 'EXYNOS2400' 'Exynos 2400'          '4nm' 'Xclipse 940'      1900000 'A 旗舰')
    (New-SoC 'EXYNOS2200' 'Exynos 2200'          '4nm' 'Xclipse 920'      1100000 'A 旗舰')
    (New-SoC 'EXYNOS2100' 'Exynos 2100'          '5nm' 'Mali-G78'          950000 'A 旗舰')
    (New-SoC 'EXYNOS1480' 'Exynos 1480'          '4nm' 'Xclipse 530'       750000 'B 中高端')
    (New-SoC 'EXYNOS1380' 'Exynos 1380'          '5nm' 'Mali-G68'          550000 'C 中端')
    (New-SoC 'EXYNOS1280' 'Exynos 1280'          '5nm' 'Mali-G68'          450000 'C 中端')
    (New-SoC 'TENSOR_G5' 'Google Tensor G5'      '3nm' 'PowerVR DXT-48'   1300000 'A 旗舰')
    (New-SoC 'TENSOR_G4' 'Google Tensor G4'      '4nm' 'Mali-G715'        1000000 'A 旗舰')
    (New-SoC 'TENSOR_G3' 'Google Tensor G3'      '4nm' 'Immortalis-G715'   900000 'A 旗舰')
    (New-SoC 'TENSOR_G2' 'Google Tensor G2'      '5nm' 'Mali-G710'         750000 'B 次旗舰')
    (New-SoC 'KIRIN9020'  'Kirin 9020'           '7nm' 'Maleoon 920'      1100000 'A 旗舰')
    (New-SoC 'KIRIN9010'  'Kirin 9010'           '7nm' 'Maleoon 910'       950000 'A 旗舰')
    (New-SoC 'KIRIN9000S' 'Kirin 9000S'          '7nm' 'Maleoon 910'       850000 'A 旗舰')
    (New-SoC 'KIRIN9000'  'Kirin 9000'           '5nm' 'Mali-G78'          800000 'A 旗舰')
)

$PlatformAlias = @{
    'kalama'='SM8550'; 'sun'='SM8750'; 'pineapple'='SM8650'; 'taro'='SM8450'
    'lahaina'='SM8350'; 'kona'='SM8250'; 'bengal'='SM6225'; 'holi'='SM6375'
    'tahiti'='SM7325'; 'yupik'='SM6450'; 'blair'='SM7225'; 'hawao'='SM7675'
    'crow'='SM7550'
}

$MfrDB = @{
    'Xiaomi'=@('小米 Xiaomi','中国','小米/Redmi/POCO')
    'HUAWEI'=@('华为 Huawei','中国','华为/nova/Mate/Pura')
    'HONOR'=@('荣耀 Honor','中国','荣耀/Magic/X系列')
    'OPPO'=@('OPPO','中国','OPPO/Find/Reno/A系列/K系列')
    'vivo'=@('vivo','中国','vivo/iQOO/X系列/S系列/Y系列')
    'OnePlus'=@('一加 OnePlus','中国','一加/Ace/Nord/数字系列')
    'realme'=@('真我 realme','中国','realme/GT/Neo')
    'samsung'=@('三星 Samsung','韩国','Galaxy S/Z/A/M/Note')
    'Google'=@('谷歌 Google','美国','Pixel')
    'Sony'=@('索尼 Sony','日本','Xperia')
    'Motorola'=@('摩托罗拉','美国','moto/edge/razr')
    'Nothing'=@('Nothing','英国','Phone/CMF')
    'ASUS'=@('华硕 ASUS','中国台湾','ROG Phone/Zenfone')
    'ZTE'=@('中兴 ZTE','中国','中兴/nubia/红魔')
    'Meizu'=@('魅族 Meizu','中国','魅族')
}

# ================================================================
#  1. 前置检测
# ================================================================
Clear-Host
$hline = [string]::new([char]0x2550, 60)
Write-Host ""
Write-Host ([char]0x2554 + $hline + [char]0x2557) -ForegroundColor Magenta
Write-Host ([char]0x2551 + (PadRight2 '  Android 硬件检测工具 v2.2' 60) + [char]0x2551) -ForegroundColor Magenta
Write-Host ([char]0x2551 + (PadRight2 '  ADB + SoC 数据库 + 智能分析 + 报告导出' 60) + [char]0x2551) -ForegroundColor Magenta
Write-Host ([char]0x255A + $hline + [char]0x255D) -ForegroundColor Magenta

# ADB - 优先用内置的，其次 PATH
Write-Host ""
Write-Host "  [1/4] 检测 ADB..." -ForegroundColor Yellow
$bundledAdb = Join-Path $ScriptRoot 'platform-tools\adb.exe'
$adbCmd = 'adb'
if (Test-Path $bundledAdb) {
    $adbCmd = $bundledAdb
    C "  [OK] 使用内置 ADB: $bundledAdb" 'Green'
} elseif (Get-Command adb -ErrorAction SilentlyContinue) {
    C "  [OK] 使用系统 ADB (PATH)" 'Green'
} else {
    C "  [!] 未找到 adb。请安装 Platform-Tools 或将 adb 放入 platform-tools\" 'Red'
    if (!$Quiet) { Read-Host "  回车退出" }
    exit 1
}

# 无线连接模式
if ($Wireless) {
    C ""
    C "  === 无线 ADB 连接 ===" 'Cyan'
    C ""
    C "  [1] Android 11+ 无线调试 (配对+连接)" 'White'
    C "  [2] USB 转无线 (tcpip 5555)" 'White'
    C ""
    $mode = Read-Host "  选择模式 (1/2)"
    if ($mode -eq '1') {
        $pairAddr = Read-Host "  输入配对地址 (IP:配对端口)"
        $pairCode = Read-Host "  输入配对码 (手机上显示的6位数字)"
        if ($pairAddr -and $pairCode) {
            C "  正在配对..." 'Yellow'
            $pairResult = (cmd /c "`"$adbCmd`" pair $pairAddr $pairCode 2>&1")
            $pairResult | ForEach-Object { C "    $_" 'DarkGray' }
            if ($pairResult -match 'Successfully') { C "  [OK] 配对成功" 'Green' }
            else { C "  [!] 配对失败，请检查地址和配对码" 'Red' }
        }
        $connAddr = Read-Host "  输入连接地址 (IP:连接端口)"
        if ($connAddr) {
            C "  正在连接..." 'Yellow'
            $connResult = (cmd /c "`"$adbCmd`" connect $connAddr 2>&1")
            $connResult | ForEach-Object { C "    $_" 'DarkGray' }
            if ($connResult -match 'connected') { C "  [OK] 无线连接成功" 'Green' }
            else { C "  [!] 连接失败，请检查 IP 和端口" 'Red' }
        }
    } elseif ($mode -eq '2') {
        C "  需要先用 USB 连接手机..." 'Yellow'
        $null = (cmd /c "`"$adbCmd`" tcpip 5555 2>&1")
        Start-Sleep -Seconds 2
        $wifiIP = Read-Host "  输入手机 WiFi IP 地址"
        if ($wifiIP) {
            C "  请拔掉 USB 线，正在无线连接..." 'Yellow'
            Start-Sleep -Seconds 3
            $connResult = (cmd /c "`"$adbCmd`" connect ${wifiIP}:5555 2>&1")
            $connResult | ForEach-Object { C "    $_" 'DarkGray' }
            if ($connResult -match 'connected') { C "  [OK] 无线连接成功" 'Green' }
            else { C "  [!] 连接失败" 'Red' }
        }
    }
    C ""
}

# 设备
Write-Host "  [2/4] 检测设备..." -ForegroundColor Yellow
$null = (cmd /c "`"$adbCmd`" kill-server 2>&1")
Start-Sleep -Milliseconds 500
$null = (cmd /c "`"$adbCmd`" start-server 2>&1")
Start-Sleep -Milliseconds 1000
$devRaw = (cmd /c "`"$adbCmd`" devices 2>&1")
$devLines = @($devRaw | Where-Object { $_ -match '\S+' -and $_ -notmatch 'List of' })
$devLines = @($devLines | Where-Object { $_ -match 'device' })
if ($devLines.Count -eq 0) {
    C "  [!] 无设备连接" 'Red'
    C ""
    C "  连接方式:" 'Yellow'
    C "  [USB]    连接数据线 + 开启 USB 调试" 'White'
    C "  [无线]   Android 11+: 设置→开发者→无线调试→配对" 'White'
    C "           adb pair <IP>:<配对端口>  然后  adb connect <IP>:<连接端口>" 'DarkGray'
    C "  [无线]   USB 先连后切: adb tcpip 5555 → adb connect <IP>:5555" 'DarkGray'
    C ""
    C "  调试: adb devices 原始输出:" 'DarkGray'
    $devRaw | ForEach-Object { C "    [$_]" 'DarkGray' }
    if (!$Quiet) { Read-Host "  回车退出" }
    exit 1
}
$serial = if ($Device) { $Device } else { ($devLines[0].ToString() -split '\s+')[0].Trim() }
C "  [OK] 设备: $serial" 'Green'
if ($devLines.Count -gt 1) { C "  [i] 检测到 $($devLines.Count) 台设备，使用第一台" 'Yellow' }

# ================================================================
#  2. 采集数据
# ================================================================
Write-Host "  [3/4] 采集硬件数据..." -ForegroundColor Yellow

$mfr    = Prop $serial 'ro.product.manufacturer'
$model  = Prop $serial 'ro.product.model'
$brand  = Prop $serial 'ro.product.brand'
$device = Prop $serial 'ro.product.device'
$android= Prop $serial 'ro.build.version.release'
$sdk    = Prop $serial 'ro.build.version.sdk'
$secP   = Prop $serial 'ro.build.version.security_patch'
$build  = Prop $serial 'ro.build.display.id'

# SoC 属性
$socModel = Prop $serial 'ro.soc.model'
$socMfr   = Prop $serial 'ro.soc.manufacturer'
$board    = Prop $serial 'ro.board.platform'
$chipname = Prop $serial 'ro.hardware.chipname'
$hardware = Prop $serial 'ro.hardware'

# 系统 UI
$osUI = ''
if ($mfr -match 'Xiaomi|Redmi') { $osUI = "MIUI/HyperOS $(Prop $serial 'ro.miui.ui.version.name')" }
elseif ($mfr -match 'OPPO')     { $osUI = "ColorOS $(Prop $serial 'ro.build.version.opporom')" }
elseif ($mfr -match 'vivo')     { $osUI = "FuntouchOS $(Prop $serial 'ro.vivo.os.version')" }
elseif ($mfr -match 'samsung')  { $osUI = "One UI $(Prop $serial 'ro.build.version.oneui')" }
elseif ($mfr -match 'HONOR')    { $osUI = "MagicOS $(Prop $serial 'ro.build.version.magic')" }
elseif ($mfr -match 'HUAWEI')   { $osUI = "EMUI $(Prop $serial 'ro.build.version.emui')" }
if (!$osUI -or $osUI -match '\(\s*\)') { $osUI = "Android $android" }

# CPU
$cpuinfo = Adb $serial 'cat /proc/cpuinfo'
$cpuCores = ([regex]::Matches($cpuinfo, 'processor\s*:')).Count
$cpuModel = ''
if ($cpuinfo -match 'model name\s*:\s*(.+)')  { $cpuModel = $matches[1].Trim() }
elseif ($cpuinfo -match 'Hardware\s*:\s*(.+)') { $cpuModel = $matches[1].Trim() }

# GPU
$gpuLine = Adb $serial 'dumpsys SurfaceFlinger | grep GLES'
$gpuName = ''
if ($gpuLine -match 'GLES:\s*(.+)') { $gpuName = $matches[1].Trim() }

# SoC 匹配
$matchedSoC = $null
$matchKey = "$socModel $chipname $hardware"
foreach ($entry in $SoC_DB) {
    if ($matchKey -match $entry.P) { $matchedSoC = $entry; break }
}
if (!$matchedSoC -and $board -and $PlatformAlias.ContainsKey($board)) {
    $ak = $PlatformAlias[$board]
    foreach ($entry in $SoC_DB) {
        if ($entry.P -eq $ak) { $matchedSoC = $entry; break }
    }
}
if (!$matchedSoC -and $board) {
    foreach ($entry in $SoC_DB) {
        if ($board -match $entry.P) { $matchedSoC = $entry; break }
    }
}
$socFallback = ''
if (!$matchedSoC) {
    $allSearch = "$socModel $socMfr $board $chipname $cpuModel $hardware $gpuName"
    if ($allSearch -match 'SM\d{4}|Snapdragon|Adreno|QTI|qcom') { $socFallback = '高通骁龙 (型号待确认)' }
    elseif ($allSearch -match 'MT\d{4}|Dimensity|Helio|mediatek|Mali') { $socFallback = '联发科 (型号待确认)' }
    elseif ($allSearch -match 'EXYNOS|exynos|Xclipse') { $socFallback = '三星 Exynos (型号待确认)' }
    elseif ($allSearch -match 'TENSOR|GS\d{3}') { $socFallback = 'Google Tensor (型号待确认)' }
    elseif ($allSearch -match 'KIRIN|kirin|Maleoon') { $socFallback = '华为麒麟 (型号待确认)' }
}

# 屏幕
$wmSize = Adb $serial 'wm size'
$wmDens = Adb $serial 'wm density'
$resW = 0; $resH = 0; $density = 0
if ($wmSize -match '(\d+)x(\d+)') { $resW = [int]$matches[1]; $resH = [int]$matches[2] }
if ($wmDens -match '(\d+)')       { $density = [int]$matches[1] }
$ppi = $density
$diagPx = 0; $screenInch = 0.0
if ($resW -gt 0 -and $resH -gt 0) { $diagPx = [math]::Sqrt($resW*$resW + $resH*$resH) }
if ($diagPx -gt 0 -and $density -gt 0) { $screenInch = [math]::Round($diagPx / $density, 1) }
$aspect = ''
if ($resW -gt 0 -and $resH -gt 0) {
    $a = $resW; $b = $resH
    while ($b -ne 0) { $t = $b; $b = $a % $b; $a = $t }
    if ($a -gt 0) {
        $aw = $resW / $a; $ah = $resH / $a
        if ($aw -le 2 -and $ah -ge 9) { $aspect = "1:$([math]::Round($ah/$aw,1))" }
        elseif ($ah -le 2 -and $aw -ge 9) { $aspect = "$([math]::Round($aw/$ah,1)):1" }
        else { $aspect = "${aw}:${ah}" }
    }
}
$screenScore = 0
if ($density -ge 560) { $screenScore = 10 } elseif ($density -ge 480) { $screenScore = 9 }
elseif ($density -ge 440) { $screenScore = 8 } elseif ($density -ge 400) { $screenScore = 7 }
elseif ($density -ge 320) { $screenScore = 6 } elseif ($density -ge 240) { $screenScore = 5 }
elseif ($density -gt 0) { $screenScore = 3 }

# 电池
$batteryRaw = Adb $serial 'dumpsys battery'
$batLevel = 0; $batTemp = 0; $batMV = 0; $batHealth = 'N/A'; $batStatus = 'N/A'
if ($batteryRaw -match 'level:\s*(\d+)')       { $batLevel = [int]$matches[1] }
if ($batteryRaw -match 'temperature:\s*(\d+)')  { $batTemp  = [math]::Round([int]$matches[1] / 10, 1) }
if ($batteryRaw -match 'voltage:\s*(\d+)')      { $batMV    = [int]$matches[1] }
$hMap = @{2='良好';3='过热';4='损坏';5='过压';6='未知';7='过冷'}
if ($batteryRaw -match 'health:\s*(\d+)') { $batHealth = $hMap[[int]$matches[1]] }
$sMap = @{1='未知';2='充电中';3='放电中';4='未充电';5='已充满'}
if ($batteryRaw -match 'status:\s*(\d+)') { $batStatus = $sMap[[int]$matches[1]] }
$batV = [math]::Round($batMV / 1000, 2)

$batScore = 0
if ($batTemp -ge 15 -and $batTemp -le 35) { $batScore += 4 }
elseif ($batTemp -le 42) { $batScore += 2 }
if ($batHealth -match '良好') { $batScore += 4 } elseif ($batHealth -match '未知') { $batScore += 2 }
if ($batLevel -ge 20 -and $batLevel -le 90) { $batScore += 2 } elseif ($batLevel -gt 0) { $batScore += 1 }

# 内存
$memRaw = Adb $serial 'cat /proc/meminfo'
$memTotal = 0; $memAvail = 0
if ($memRaw -match 'MemTotal:\s*(\d+)\s*kB')     { $memTotal = [math]::Round([int]$matches[1] / 1048576, 1) }
if ($memRaw -match 'MemAvailable:\s*(\d+)\s*kB') { $memAvail = [math]::Round([int]$matches[1] / 1048576, 1) }
$memScore = 0
if ($memTotal -ge 16) { $memScore = 10 } elseif ($memTotal -ge 12) { $memScore = 9 }
elseif ($memTotal -ge 8) { $memScore = 8 } elseif ($memTotal -ge 6) { $memScore = 6 }
elseif ($memTotal -ge 4) { $memScore = 4 } elseif ($memTotal -gt 0) { $memScore = 2 }

# 存储
$dfRaw = Adb $serial 'df -h /data'
$stoTotal = 'N/A'; $stoUsed = 'N/A'; $stoAvail = 'N/A'; $stoPct = 0
if ($dfRaw -match '/dev\S+\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)%') {
    $stoTotal = $matches[1]; $stoUsed = $matches[2]; $stoAvail = $matches[3]; $stoPct = [int]$matches[4]
}
$stoScore = 5
if ($stoPct -gt 0) {
    if ($stoPct -lt 70) { $stoScore = 9 } elseif ($stoPct -lt 85) { $stoScore = 7 }
    elseif ($stoPct -lt 95) { $stoScore = 4 } else { $stoScore = 2 }
}

# 传感器(只统计注册的sensor,非事件数)
$sensorRaw = Adb $serial 'dumpsys sensorservice | grep -c "0x"'
$sensorCount = 0
if ($sensorRaw -match '(\d+)') { $sensorCount = [int]$matches[1] }

# SoC 评分
$socScore = 5
if ($matchedSoC) {
    if ($matchedSoC.T -match 'S ') { $socScore = 10 }
    elseif ($matchedSoC.T -match 'A ') { $socScore = 9 }
    elseif ($matchedSoC.T -match 'B ') { $socScore = 7 }
    elseif ($matchedSoC.T -match 'C ') { $socScore = 5 }
    elseif ($matchedSoC.T -match 'D ') { $socScore = 3 }
}

# 厂商
$mfrInfo = @($mfr, '未知', '')
foreach ($key in $MfrDB.Keys) {
    if ($mfr -eq $key -or $brand -eq $key) { $mfrInfo = $MfrDB[$key]; break }
}

# ================================================================
#  3. 展示
# ================================================================
Write-Host "  [4/4] 分析完成，展示结果..." -ForegroundColor Yellow

Section '设备身份'
KV '厂商' "$($mfrInfo[0]) ($($mfrInfo[1]))" 'Green'
KV '品牌' $brand
KV '型号' $model 'White'
KV '设备代号' $device
KV 'Android' "$android (SDK $sdk)" 'Green'
KV '系统 UI' $osUI 'Yellow'
KV '安全补丁' $secP
KV 'Build' $build 'DarkGray'

Section '处理器 (SoC)'
if ($matchedSoC) {
    KV '芯片型号' $matchedSoC.N 'Green'
    KV '制程工艺' $matchedSoC.Proc
    KV 'GPU 图形' $matchedSoC.G 'Yellow'
    $tColor = if ($matchedSoC.T -match 'S|A') { 'Green' } elseif ($matchedSoC.T -match 'B') { 'Yellow' } else { 'White' }
    KV '性能定位' $matchedSoC.T $tColor
    KV '参考跑分' "安兔兔 ~$($matchedSoC.B.ToString('N0'))" 'DarkGray'
} elseif ($socFallback) {
    KV '系列' $socFallback 'Yellow'
    KV '检测属性' "$socModel / $board / $hardware" 'DarkGray'
} else {
    KV 'CPU' $cpuModel 'Yellow'
    KV '平台' "$socModel $board" 'DarkGray'
}
KV 'CPU 核心' "$cpuCores 核"
if ($gpuName) { KV 'GPU 渲染器' $gpuName 'DarkGray' }

Section '屏幕显示'
if ($resW -gt 0) { KV '分辨率' "${resW} x ${resH}" 'Green' } else { KV '分辨率' $wmSize 'Yellow' }
if ($aspect) { KV '屏幕比例' $aspect }
$pColor = if ($ppi -ge 440) { 'Green' } elseif ($ppi -ge 320) { 'Yellow' } else { 'White' }
KV '像素密度' "$density dpi (PPI $ppi)" $pColor
if ($screenInch -gt 0) { KV '屏幕尺寸' "约 $screenInch 英寸" 'DarkGray' }

Section '内存 & 存储'
$mColor = if ($memTotal -ge 8) { 'Green' } elseif ($memTotal -ge 4) { 'Yellow' } else { 'Red' }
KV '运行内存' "$memTotal GB (可用 $memAvail GB)" $mColor
KV '存储总量' $stoTotal 'White'
KV '已用 / 可用' "$stoUsed / $stoAvail ($stoPct%)" $(if ($stoPct -lt 85) { 'Green' } else { 'Yellow' })

Section '电池状态'
KV '电量' "$batLevel%" $(if ($batLevel -ge 20) { 'Green' } else { 'Red' })
KV '状态' $batStatus
KV '温度' "$batTemp°C" $(if ($batTemp -le 35) { 'Green' } elseif ($batTemp -le 42) { 'Yellow' } else { 'Red' })
KV '健康' $batHealth $(if ($batHealth -match '良好') { 'Green' } else { 'Yellow' })
KV '电压' "$batV V"

Section '其他'
if ($sensorCount -gt 0) { KV '传感器' "$sensorCount 个" }

# ================================================================
#  4. 综合评分
# ================================================================
Section '综合硬件评分'
Write-Host ""
Rating '处理器' $socScore
Rating '屏幕'   $screenScore
Rating '内存'   $memScore
Rating '电池'   $batScore
Rating '存储'   $stoScore

$totalScore = [math]::Round(($socScore*3 + $screenScore*2 + $memScore*2 + $batScore*1.5 + $stoScore*1.5) / 10, 1)
$gradeColor = if ($totalScore -ge 8) { 'Green' } elseif ($totalScore -ge 5) { 'Yellow' } else { 'Red' }
$grade = if ($totalScore -ge 8.5) {'S 级 · 顶级旗舰'} elseif ($totalScore -ge 7) {'A 级 · 优秀'} elseif ($totalScore -ge 5) {'B 级 · 中端主流'} elseif ($totalScore -ge 3) {'C 级 · 入门'} else {'D 级 · 老旧'}

$star = [char]0x2605
Write-Host ""
Write-Host "  $star 综合评分: $totalScore / 10" -ForegroundColor $gradeColor
Write-Host "  $star 设备等级: $grade" -ForegroundColor $gradeColor

# ================================================================
#  5. 导出
# ================================================================
if ($Export) {
    if (!(Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir | Out-Null }
    $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
    $safeModel = $model -replace '[\\/:*?"<>|]', '_'
    $reportFile = Join-Path $ReportDir "HW_${safeModel}_${ts}.txt"

    $socName  = if ($matchedSoC) { $matchedSoC.N } elseif ($socFallback) { $socFallback } else { $cpuModel }
    $socProc  = if ($matchedSoC) { $matchedSoC.Proc } else { 'N/A' }
    $socGPU   = if ($matchedSoC) { $matchedSoC.G } else { $gpuName }
    $socTier  = if ($matchedSoC) { $matchedSoC.T } else { 'N/A' }
    $socBench = if ($matchedSoC) { $matchedSoC.B.ToString('N0') } else { 'N/A' }

    $report = @"
============================================================
  Android 硬件检测报告
  生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
============================================================

[设备]
  厂商     : $($mfrInfo[0]) ($($mfrInfo[1]))
  品牌     : $brand
  型号     : $model
  代号     : $device
  Android  : $android (SDK $sdk)
  系统 UI  : $osUI
  安全补丁 : $secP
  Build    : $build

[处理器]
  芯片     : $socName
  制程     : $socProc
  GPU      : $socGPU
  核心数   : $cpuCores
  定位     : $socTier
  参考跑分 : $socBench

[屏幕]
  分辨率   : ${resW} x ${resH}
  比例     : $aspect
  密度     : $density dpi (PPI $ppi)
  尺寸     : $screenInch 英寸

[内存 & 存储]
  运行内存 : $memTotal GB (可用 $memAvail GB)
  存储     : $stoTotal (已用 $stoUsed, 可用 $stoAvail, $stoPct%)

[电池]
  电量     : $batLevel%
  温度     : $batTemp°C
  健康     : $batHealth
  状态     : $batStatus
  电压     : $batV V

[其他]
  传感器   : $sensorCount 个

[综合评分]
  处理器   : $socScore/10
  屏幕     : $screenScore/10
  内存     : $memScore/10
  电池     : $batScore/10
  存储     : $stoScore/10
  总分     : $totalScore/10
  等级     : $grade
============================================================
"@
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($reportFile, $report, $utf8Bom)
    Write-Host ""
    C "  [OK] 报告已导出: $reportFile" 'Green'
}

# ================================================================
#  结束
# ================================================================
Write-Host ""
$fline = [string]::new([char]0x2550, 60)
Write-Host ([char]0x2554 + $fline + [char]0x2557) -ForegroundColor Magenta
Write-Host ([char]0x2551 + (PadRight2 '  [OK] 检测完成!' 60) + [char]0x2551) -ForegroundColor Magenta
Write-Host ([char]0x255A + $fline + [char]0x255D) -ForegroundColor Magenta
Write-Host ""

if (!$Quiet) { Read-Host "  按回车退出" }
