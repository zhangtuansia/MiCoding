# MiCoding

MiCoding 是一个基于 macOS SwiftUI 的 Xiaomi Bluetooth Remote 2 Pro 配置器。界面借鉴 Logi Options+ 的信息架构、设备画布、动作库与细腻动效，但不使用罗技品牌、字体或美术资源。

应用完全本地运行，不包含注册、登录、账号或云同步。下载后即可使用，配置只保存在当前 Mac。

## 当前版本

- 设备首页与悬浮卡片动效
- Xiaomi Remote 2 Pro 设备配置页
- 13 个可选择的遥控器按键热点
- 当前动作与应用专属配置档案
- 动作搜索、分类、点击分配与拖放分配
- 有效/无效拖放状态和按键回弹反馈
- 无硬件时的当前按键动作测试
- 三套可运行、可分配的本机组合动作
- 权限、后端诊断与设备信息页面
- 浅色/深色外观
- 统一 Lucide 矢量图标系统，不混用 SF Symbols
- 真实 `IOHIDManager` 设备发现与 13 键输入
- 单击 / 长按 / 双击解析状态机
- `CGEvent`、媒体键、默认浏览器、应用启动与顺序组合执行器
- 前台应用 Profile 自动切换
- 本地 JSON 配置持久化

## 运行

在 Xcode 中打开 `Package.swift`，选择 `XiaomiRemoteStudio` scheme 后运行；或在终端执行：

```bash
cd XiaomiRemoteStudio
swift run XiaomiRemoteStudio
```

生成可双击的本地 `.app`：

```bash
./scripts/package-local.sh
open "build/MiCoding.app"
```

## 下一阶段

1. 用实物校准 HID usage、连发、重连与电量报告。
2. 接入设备级 `hidutil` 中转，抑制原按键的系统副作用。
3. 完成长按、双击和自定义组合动作的可视化编辑器。
4. 视产品范围决定是否接入语音键的 ATVV 音频通道。

设备标识和 usage 表参考并交叉验证了 MIT 项目 [godarrenw/mi_remote_control](https://github.com/godarrenw/mi_remote_control)。
