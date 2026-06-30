# TrollTouch

TrollFools 注入版悬浮窗插件，支持诊断日志。

## 功能
- 注入目标 App 后自动显示悬浮窗
- `Tap` — 对固定坐标执行点击（红圈反馈 + 诊断日志）
- `Swipe` — 对固定区域执行滑动
- `Copy Logs` — 复制完整诊断日志到剪贴板

## 编译
- 推送到 GitHub 后自动执行 `.github/workflows/build.yml`
- 产物为 `packages/TrollTouch.dylib`

## 使用
1. 用 TrollFools 注入 `TrollTouch.dylib`
2. 重启目标 App
3. 进入 App 后会显示悬浮窗
4. 点 `Tap` 测试点击，日志区会显示每一步诊断
5. 点 `Copy Logs` 粘贴出来分析

## 点击路径（按顺序尝试）
1. `accessibilityActivate`
2. `UIControl sendActionsForControlEvents:`
3. IOHIDEvent + `_enqueueHIDEvent:` / `_handleHIDEvent:`

## 注意事项
- 若 `_enqueueHIDEvent:` 不生效，可能需要注入到的 App 具有 `com.apple.private.hid.client.event-dispatch` entitlement
- 该 entitlement 可通过 TrollStore 签名时注入到目标 IPA

## 文件
- 入口: `TrollTouch.m`
- 悬浮窗: `TTFloatWindow.m`
