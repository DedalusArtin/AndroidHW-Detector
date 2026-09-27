@echo off
title Android 硬件检测工具 v2.0
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "AndroidHW-Detector.ps1" %*
if errorlevel 1 pause
