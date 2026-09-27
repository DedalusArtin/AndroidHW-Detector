# AndroidHW-Detector

Android 手机硬件检测工具 (ADB-based) — SoC 智能匹配 + 终端美化展示 + 报告导出

## 功能

- **ADB 自动采集**：CPU / GPU / 屏幕 / 电池 / 内存 / 存储 / 传感器
- **SoC 智能匹配**：内置 46+ 芯片数据库（骁龙 8 Elite → 4 系、天玑 9400+ → Helio、Exynos 2500 → 1280、Tensor G5 → G2、麒麟 9020 → 9000），支持 codename 别名匹配（kalama/pineapple/sun 等）
- **厂商识别**：15+ 品牌（小米/华为/OPPO/vivo/三星/Google 等），显示国家和产品线
- **智能分析**：PPI 计算、屏幕尺寸估算、比例识别、电池健康评分、存储余量评估
- **终端美化**：Unicode 框线 + 中文对齐 + 彩色评分条 + S/A/B/C/D 等级
- **报告导出**：`-Export` 生成 UTF-8 文本报告

## 使用

```powershell
# 双击 run.bat
# 或命令行:
.\AndroidHW-Detector.ps1              # 基本检测
.\AndroidHW-Detector.ps1 -Export     # 带报告导出
.\AndroidHW-Detector.ps1 -Quiet      # 静默模式
.\AndroidHW-Detector.ps1 -Device <serial>  # 指定设备
```

## 环境要求

- Windows 10/11 + PowerShell 5.1+
- [Android SDK Platform-Tools](https://developer.android.com/studio/releases/platform-tools)（adb 在 PATH）
- 手机开启 USB 调试

## 项目结构

```
AndroidHW-Detector/
├── AndroidHW-Detector.ps1    # 主脚本
├── run.bat                   # 双击启动
├── reports/                  # 导出报告 (gitignore)
├── docs/                     # 文档
├── README.md
└── .gitignore
```

## 支持的 SoC

| 厂商 | 芯片 |
|------|------|
| 高通 | Snapdragon 8 Elite Gen 5 / 8 Elite / 8 Gen 1-3 / 888 / 865 / 855 / 7+ Gen 2-3 / 7s Gen 3 / 7 Gen 1 / 778G / 750G / 730G / 6 Gen 1 / 695 / 680 / 4 Gen 1 / 460 |
| 联发科 | Dimensity 9400+ / 9300+ / 9200+ / 9000+ / 8400 / 8300 / 7300 / 1050 / 700 / Helio G85 / G35 |
| 三星 | Exynos 2500 / 2400 / 2200 / 2100 / 1480 / 1380 / 1280 |
| Google | Tensor G5 / G4 / G3 / G2 |
| 华为 | Kirin 9020 / 9010 / 9000S / 9000 |

## License

MIT
