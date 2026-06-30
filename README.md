# TrollTouch AX - 辅助功能方案三

通过 AXUIElement 私有 API 实现模拟点击的独立控制器 IPA。

## 原理
- 加载 AXRuntime.framework 私有框架
- 调用 AXUIElementCopyElementAtPosition 查找前台 App 控件
- 调用 AXUIElementPerformAction(kAXPressAction) 发送系统级点击
- 不依赖 HID entitlement

## 安装
1. GitHub Actions 下载 TrollTouch.ipa
2. TrollStore 安装
3. **设置 → 辅助功能 → 触控 → 找到 TrollTouch → 打开开关**
4. 打开 TrollTouch → 状态变绿"AX 就绪"

## 使用
- 输入坐标 → 点「单击」→ 切到目标 App
- 坐标有红圈预览
- 支持循环点击和滑动
- 日志可复制诊断

## 红圈示意
控制器界面上的红圈预览区显示点击位置的相对示意。
实际 AX 点击发生在前台 App 的对应坐标。
