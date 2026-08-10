# MiCoding

MiCoding 是一款面向 macOS 的 Xiaomi Bluetooth Remote 2 Pro 配置工具，使用 SwiftUI 原生开发。

它可以把遥控器的实体按键映射为快捷键、系统操作、应用启动和多步骤自动化，并针对不同的前台应用自动切换配置。所有设置默认只保存在当前 Mac，不需要注册、登录或云同步。

## 主要功能

### 按键自定义

- 识别并配置 13 个实体按键
- 分别设置单击、长按和双击动作
- 支持点击分配、搜索分配和拖放分配
- 可直接选择任意本机 `.app`，包括没有 bundle identifier 的本地或自签名应用
- 可录制 `fn`、`⌘`、`⌥`、`⌃`、`⇧`、F1–F20、方向键及 Home、End、Page Up、Page Down 等高级键盘映射
- 录制 `fn` 时会优先捕获按键事件，即使 macOS 已经为它设置输入法切换或其他本地动作
- 支持按前台应用自动切换专属配置档案

### 智能操作

- 内置 27 套本机自动化模板
- 使用“如果… / 那么…”结构创建多步骤工作流
- 支持设备按键、应用切换、环形动作面板和全局快捷键触发
- 支持打开、关闭或置前应用，以及快捷键、文本、网址、系统操作和延迟步骤
- 支持步骤拖拽排序、参数校验、试运行、复制、启停、导入、导出和按键分配
- 自动检测重复的全局快捷键，避免多个操作同时响应
- AI 文本模板可处理当前所选文本，并打开 ChatGPT；桌面客户端不可用时会使用网页和剪贴板兜底

### Codex / Claude 遥控编程

- 内置 Codex 与 Claude 应用专属配置档案
- 支持一键打开、语音输入、发送、取消、新任务/新对话和添加文件
- Codex 额外支持终端、文件树、代码审查以及上一个/下一个任务
- 可为两个 AI 分别配置 8 个环形动作，并用电源键或语音键的单击/双击快速切换
- “开始语音输入”直接调用当前应用的系统听写菜单，不依赖本机 Globe/`fn` 快捷键设置

### 环形动作面板

- 提供 8 个主动作位置和文件夹式子动作面板
- 支持从动作库自由分配操作
- 音量和亮度参数支持滚轮或水平拖动调节
- 运行时可从子面板快速返回主面板

### 设备与连接

- 使用 `IOHIDManager` 发现设备并读取实体按键
- 识别遥控器报告 6、7、8 的原始麦克风数据通道，并提供有界诊断采集
- 提供实体按键测试和未映射 HID Usage 提示
- 显示 macOS 上报的连接状态、电量和固件信息
- 支持输入服务启停、设备移除与重新添加，保留已有配置
- 可导出蓝牙诊断报告，报告不包含实际按键内容
- 支持导出和恢复按键、手势参数、智能操作及环形动作面板配置
- 可设置长按时间、双击间隔和按键防抖
- 支持浅色、深色和跟随系统外观

### 跨 Mac 使用

MiCoding 可引导开启 macOS 通用控制与接力，从而使用系统提供的跨 Mac 指针切换和通用剪贴板能力。

## 系统要求

- macOS 14 或更高版本
- Xiaomi Bluetooth Remote 2 Pro
- 从源码构建时需要 Xcode 16 / Swift 6

## 安装与运行

克隆项目后直接运行：

```bash
git clone https://github.com/zhangtuansia/MiCoding.git
cd MiCoding
swift run XiaomiRemoteStudio
```

也可以使用 Xcode 打开 `Package.swift`，选择 `XiaomiRemoteStudio` scheme 后运行。

生成可双击启动的本地应用：

```bash
./scripts/package-local.sh
open "build/MiCoding.app"
```

打包脚本会优先使用钥匙串中可用的 Apple Development 证书，使输入监控和辅助功能授权在本机覆盖升级后保持稳定；没有开发证书时会退回 ad-hoc 签名。也可以通过 `MICODING_CODESIGN_IDENTITY` 显式指定签名身份。

## 权限说明

MiCoding 只在实现对应功能时请求以下系统权限：

- **输入监控**：读取遥控器 HID 按键事件
- **辅助功能**：执行用户明确分配的快捷键和系统动作

如果授权后仍无法读取按键，请完全退出并重新打开 MiCoding，再到“系统设置 → 隐私与安全性”确认相应开关已经启用。

## 本地数据与隐私

MiCoding 不包含分析 SDK，也不会上传诊断信息、使用数据或按键内容。

按键配置、应用配置档案、智能操作和界面偏好保存在：

```text
~/Library/Application Support/XiaomiRemoteStudio/config.json
```

只有在用户手动检查更新或启用自动更新检查时，应用才会请求 GitHub Releases 的公开版本信息。蓝牙诊断报告仅在用户主动选择导出时生成。

## 当前限制

- 不同固件可能使用不同的 HID Usage；遇到未识别按键时，可通过实体按键测试记录并导出诊断信息
- 设备休眠期间，macOS 可能暂时不提供实时电量
- 遥控器麦克风的原始 HID 音频报告已接入诊断链路；在完成具体固件的 ADPCM 参数校准前，文字输入使用 macOS 系统听写和当前系统麦克风

## 开发与测试

运行全部测试：

```bash
swift test
```

生成原生 UI 快照：

```bash
RENDER_UI_SNAPSHOTS=1 swift test \
  --filter UISnapshotTests.testRenderReferenceScreensWhenRequested
```

第三方依赖与素材说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。设备标识和 HID Usage 表参考并交叉验证了 MIT 项目 [godarrenw/mi_remote_control](https://github.com/godarrenw/mi_remote_control)。
