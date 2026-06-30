# TrollTouch - ESign 注入版

注入目标 App 后自动扫描并跳过广告/弹窗。

## 核心能力
- **自动扫描**：注入后 3 秒自动扫描视图树，找到"跳过/关闭/知道了"按钮自动点击
- **HID 坐标点击**：手动发送坐标指令，通过 ESign entitlement 获得真正 HID 权限
- **关键词匹配**：内置 20+ 中文/英文跳过关键词
- **文件日志**：`/var/mobile/Library/Preferences/com.trolltouch.log.txt`

## 使用步骤

### 1. 编译 dylib
推送到 GitHub → Actions 自动编译 → 下载 `TrollTouch.dylib`

### 2. ESign 重签目标 App
```
1. 砸壳目标 App → 得到 App.ipa
2. 打开 ESign → 导入 App.ipa
3. 注入 dylib: 选择 TrollTouch.dylib
4. Entitlements: 导入 entitlements.plist
5. 签名 → 安装到 TrollStore
```

### 3. 自动跳过广告
- ESign 安装后打开目标 App
- dylib 自动启动，每 1 秒扫描一次
- 发现"跳过"按钮自动点击
- 日志文件实时查看运行状态

### 4. 手动控制（可选）
```bash
# 自动扫描模式
sh scripts/auto_skip.sh

# 坐标点击模式
sh scripts/tap.sh 200 400

# 查看日志
cat /var/mobile/Library/Preferences/com.trolltouch.log.txt
```

## 文件
- 核心代码: `TrollTouch.m`
- ESign 用的 entitlements: `entitlements.plist`
- 编译: `make package` → `packages/TrollTouch.dylib`
