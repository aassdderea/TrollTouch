# TrollTouch - 控制器 IPA

带 HID entitlement 的独立应用，通过 TrollStore 安装后可在后台向系统发送触摸事件，控制任意前台 App。

## 功能
- **单次 Tap**：在指定坐标执行一次点击
- **循环点击**：按设定间隔持续点击
- **滑动**：从起点到终点平滑滑动
- **后台运行**：切到目标 App 后可继续发触摸
- **日志**：复制日志方便诊断

## 安装
1. 从 GitHub Actions 下载 `TrollTouch.ipa`
2. 用 TrollStore 打开安装
3. 打开 TrollTouch → 设置坐标 → 点"开始循环"
4. 切到目标 App → 系统会把触摸事件投递给前台 App

## 原理
TrollStore 安装时注入 `com.apple.private.hid.client.event-dispatch` entitlement，使 App 可以通过 IOHIDEventSystemClient 向系统发送触摸事件，系统自动投递给前台 App。

## 编译
推送到 GitHub，Actions 自动产出 `TrollTouch.ipa`。
