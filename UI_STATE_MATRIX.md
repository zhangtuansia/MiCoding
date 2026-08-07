# MiCoding UI 状态矩阵

所有状态快照均以 `1280 × 820` 渲染。空状态必须说明发生了什么，并在可以恢复时提供直接操作。

| 区域 | 状态 | 界面处理 | 快照 |
| --- | --- | --- | --- |
| 设备首页 | 遥控器未连接 | 保留离线按键配置入口，提供蓝牙设置入口 | `home`、`home-dark` |
| 按键配置 | 尚未选择按键 | 隐藏无效的动作筛选，提示先在遥控器上选择按键 | `device-detail-no-selection` |
| 动作库 | 搜索或分类无结果 | 显示搜索上下文，并提供“清除筛选”恢复入口 | `device-detail-no-results`、`device-detail-no-results-dark` |
| 按键配置 | 按键尚未分配 | 保留动作目录，标题提示选择要执行的动作 | `device-detail-left` |
| 智能操作 | 没有组合动作 | 显示原因和“载入推荐模板”恢复入口 | `smart-actions-empty`、`smart-actions-empty-dark` |
| 设备信息 | 电量尚未上报 | 使用 `--`，解释正在等待实物报告 | `device-information` |
| 权限 | 输入监控或辅助功能未授予 | 分项显示权限状态和系统设置入口 | `settings-permissions` |

连接设备为空列表不属于当前产品状态：MiCoding 只服务 Xiaomi Bluetooth Remote 2 Pro，并允许在设备离线时预先配置。
