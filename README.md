# TrollTouch - ESign 注入版 v2

注入目标 App 后自动扫描并跳过广告/弹窗。

## 核心升级 (v2)
- **日志写入沙盒 Documents 目录**，可用 Filza 直接查看
- **屏幕左上角状态标签**，直观显示 dylib 运行状态
- **注入后 4 秒自动开始扫描**（2 秒初始化 + 2 秒延迟）
- 关键词覆盖 20+ 种常见关闭/跳过按钮

## 状态标签含义
| 颜色 | 文字 | 含义 |
|------|------|------|
| 绿色 | 已加载 ✓ | dylib 加载成功 |
| 蓝色 | 扫描中… | 正在扫描视图树 |
| 绿色 | 已点击 ✓ | 找到并点击了按钮 |
| 黄色 | 等待窗口… | 窗口未准备好 |
| 灰色 | 已停止 | 扫描已停止 |

## 使用步骤

### 1. 编译
推送 GitHub → Actions 下载 `TrollTouch.dylib`

### 2. ESign 重签 + 注入
1. 砸壳目标 App → 得到 IPA
2. ESign 导入 IPA
3. 注入 `TrollTouch.dylib`
4. 导入 `entitlements.plist`（可选）
5. 签名 → TrollStore 安装

### 3. 验证
- 打开 App，屏幕左上角应出现绿色 "TT: 已加载 ✓"
- 广告出现后自动变为 "TT: 已点击 ✓"

### 4. 查看日志
```
Filza → /var/mobile/Containers/Data/Application/{UUID}/Documents/com.trolltouch.log.txt
```
