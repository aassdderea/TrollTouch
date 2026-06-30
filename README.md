# TrollTouch

适配 TrollFools 的注入版悬浮窗插件。

## 功能
- 注入目标 App 后自动显示悬浮窗
- 点击 `Tap` 按钮会在目标 App 内固定坐标执行一次点击
- 点击 `Hide` 隐藏悬浮窗

## 编译
- 推送到 GitHub 后自动执行 `.github/workflows/build.yml`
- 产物为 `packages/TrollTouch.dylib`

## 使用
1. 用 TrollFools 注入 `TrollTouch.dylib`
2. 重启目标 App
3. 进入 App 后会显示悬浮窗
4. 点 `Tap` 测试点击

## 文件
- 入口: `TrollTouch.m`
- 悬浮窗: `TTFloatWindow.m`
- 点击实现: `TTTouchSimulator.m`
