# TrollTouch

适配 TrollFools 的注入版点击插件。

## 编译
- 推送到 GitHub 后自动执行 `.github/workflows/build.yml`
- 产物里会上传 `packages/TrollTouch.dylib`

## TrollFools 使用
1. 选择目标 App
2. 注入 `TrollTouch.dylib`
3. 重启目标 App
4. 先执行 `ping.sh` 确认 dylib 已加载
5. 再执行 `tap.sh x y duration`

## 命令文件
- 指令文件: `/var/mobile/Library/Preferences/com.trolltouch.command.plist`
- 结果文件: `/var/mobile/Library/Preferences/com.trolltouch.result.plist`

## 示例
```sh
sh ping.sh
sh tap.sh 200 400 0.05
```

## 关键文件
- 注入逻辑: `TrollTouch.m`
- 构建配置: `Makefile`
- GitHub Actions: `.github/workflows/build.yml`
