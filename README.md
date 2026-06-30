# TrollTouch

基于 TrollFools 注入的简单点击插件。

## 构建
- 本地: `make package`
- GitHub Actions: 推送后自动构建

## 注入
- 将产物 `TrollTouch.dylib` 与 `TrollTouch.plist` 注入目标 App
- 默认过滤示例是 Safari 和设置，可自行改 `layout/Library/MobileSubstrate/DynamicLibraries/TrollTouch.plist`

## 触发点击
```sh
sh scripts/tap.sh 200 400 0.05
```

## 原理
- 注入目标进程
- 通过通知读取 `/var/mobile/Library/Preferences/com.trolltouch.command.plist`
- 在主线程构造 `UITouch/UITouchesEvent` 并发送
