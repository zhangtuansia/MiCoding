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
        ├─ NSWorkspace 启动应用、默认浏览器和白名单协议网页
        └─ 顺序执行带间隔的本机组合动作
```

## 已实现

- VID `0x2717` / PID `0x32B8` 设备匹配。
- 13 个实体键的 HID usage 映射。
- 设备接入、移除和未知 usage 日志；未知 usage 与映射键共用完整报告差分，因此按下/松开不会重复或丢失，并会在 13 键测试页显示原始值。
- 单击、长按和双击状态机；未配置双击的按键不会增加点击延迟。
- 前台 App 监听和全局配置回退。
- 系统动作与应用启动执行器；用户从动作抽屉选择的 App 以标准化 `.app` 路径保存和执行，同时保留 bundle identifier 执行路径供内置动作与应用控制节点使用。
- 二十七套内置组合动作可添加、导入、手动运行，也可像普通动作一样分配给实体按键。
- Smart Actions 模板、管理和编辑状态使用固定参考几何；管理空状态以代码绘制的键盘与鼠标复现参考插画，侧栏会向辅助功能报告当前选中页。
- Smart Actions 模板卡按参考的 260×320pt 网格、24px/14px 标题说明层级和 10% 卡片阴影渲染；混合标题只加重拉丁字形，中文保持 CSS `font-weight: 500` 对应的系统中等字重。
- 自定义工作流使用带参数的 `SmartActionStep` 顺序保存，可混合应用、快捷键、文本、网址、系统动作与延迟；旧版仅含动作 ID 的 JSON 会在载入时自动迁移。
- `SmartActionTrigger` 支持设备按键和全局快捷键；全局监听只匹配用户明确录制的组合，忽略 MiCoding 自己合成的键盘事件以防递归触发。
- 输入服务、操作反馈、权限提醒、连接状态通知与首页体验推荐偏好会随本地配置持久化。
- 首页按原版式显示“停用/启用 + 移除”控制，停用输入服务后设备降亮但保留配置；电量未上报时状态块保持参考的 54pt 紧凑尺寸，取得真实值后扩展到 103pt 并直接显示百分比，点击后还可查看固件和刷新，清除所有 Profile 分配保留在设备右键菜单与设备设置中。
- 设备生命周期区分“停用输入服务”“从 MiCoding 移除”和“清除配置”：移除状态会持久化并停止后端，但保留所有 Profile、触发层和 Actions Ring 配置，重新添加后恢复。
- 设备级 `hidutil` 映射在输入服务运行期间抑制遥控器原始键盘副作用，并在服务停止或进程退出时恢复原映射。
- 设备二级页保留固定侧栏和应用 Profile 顶栏；手势参数通过设备旁摘要卡进入 394pt 设置抽屉，设备设置中的检测、权限、蓝牙、本地备份/恢复、重置和停用入口均连接真实本机动作。
- 设备页字体按 Options+ 的 Brown Pro CSS 结构映射为本机 Avenir Next + 系统中文回退；按键标注严格使用 14px 动作名、12px 硬件名和 58.4pt 卡高，悬停为浅强调色，打开动作抽屉后切换为实色选中态。
- 蓝牙问题页可导出不含按键内容的本机诊断报告。
- 全局设置使用与当前 Options+ 相同的连续画布和 403pt 导航列，避免左右栏形成纯白拼缝；主题、语言与更新控件仍只呈现已经实现的本机能力。
- 主窗口在创建时显式固定为 1,180×760pt 外框与 1,180×728pt 布局区，不依赖 AppKit 在首次前台激活或解锁后补做标题栏尺寸修正。
- 输入监控、辅助功能权限检测和请求入口。
- 本地 JSON 原子写入与版本字段。
- 无硬件时的按键演示通道。

## 需要实物校准

- 不同固件是否仍使用相同 VID/PID 与 usage。
- 按住后的 HID autorepeat、松开丢包和蓝牙重连行为。
- 电量读取 macOS 蓝牙缓存中的 `device_batteryLevelMain`，后台刷新且 30 秒内去重；系统暂时漏报字段时保留本次运行中最后一个真实值，启动后始终未取得过数据才显示“设备未上报”，不伪造百分比。
- Actions Ring 的文件夹动作由稳定 action ID 解析为九个子动作；运行时浮层在本地切换主环/子环，只有叶子动作交给执行器，避免把文件夹误当成批量命令执行。
- Actions Ring 的音量与亮度动作会进入参数气泡状态；浮层把滚轮和水平拖动量离散为增减步数，通过 AppStore 调度到 macOS 音量、亮度辅助键，中央按钮先退出参数态再关闭动作环。
- 动作抽屉的触发方式是会话级编辑状态：首次打开按键回到单击层，在抽屉内切换其他按键时保留当前单击 / 长按 / 双击层；关闭抽屉后复位。
- 动作抽屉的高级键盘映射由 AppKit first responder 录制，并在录制态拦截 key-equivalent 路径，因此 Command 菜单快捷键不会绕过录制器；保存的虚拟键码与修饰位最终仍通过 `CGEvent` 合成。
- 应用 Profile 选择器扫描 `/Applications`、`/System/Applications` 与用户 Applications 目录，按 bundle identifier 去重；勾选状态复用本地 Profile 持久化，执行时由前台应用 bundle identifier 选择专属分配并回退全局分配。
- 语音键对应的 ATVV 私有 GATT 音频通道。

这些校准点不会改变 UI、配置格式、动作执行器或状态机的主体结构。
