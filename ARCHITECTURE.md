# 架构说明

## 产品边界

MiCoding 是本地优先的 macOS 应用：不需要账户、登录或联网。配置保存在：

```text
~/Library/Application Support/XiaomiRemoteStudio/config.json
```

## 运行链路

```text
Xiaomi Remote 2 Pro
        │ Bluetooth HID
        ▼
IOHIDRemoteInputService
        │ RemoteInputEvent(slotID, began/ended)
        ├──────────────► SwiftUI 实时热点反馈
        ▼
RemoteGestureEngine
        │ tap / hold / doubleTap
        ▼
前台 App Profile 解析
        │ ActionCommand
        ▼
SystemActionExecutor
        ├─ CGEvent 键盘快捷键
        ├─ NSEvent 媒体键
        ├─ NSWorkspace 启动应用和默认浏览器
        └─ 顺序执行带间隔的本机组合动作
```

## 已实现

- VID `0x2717` / PID `0x32B8` 设备匹配。
- 13 个实体键的 HID usage 映射。
- 设备接入、移除和未知 usage 日志。
- 单击、长按和双击状态机；未配置双击的按键不会增加点击延迟。
- 前台 App 监听和全局配置回退。
- 系统动作与应用启动执行器。
- 三套内置组合动作可手动运行，也可像普通动作一样分配给实体按键。
- 输入监控、辅助功能权限检测和请求入口。
- 本地 JSON 原子写入与版本字段。
- 无硬件时的按键演示通道。

## 需要实物校准

- 不同固件是否仍使用相同 VID/PID 与 usage。
- 按住后的 HID autorepeat、松开丢包和蓝牙重连行为。
- 电量报告所在 usage page / report。
- 设备级 `hidutil` 中转映射，用于在执行自定义动作时抑制原按键副作用。
- 语音键对应的 ATVV 私有 GATT 音频通道。

这些校准点不会改变 UI、配置格式、动作执行器或状态机的主体结构。
