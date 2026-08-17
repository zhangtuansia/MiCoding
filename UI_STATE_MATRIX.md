# MiCoding UI 状态矩阵

所有状态快照均以正式窗口的 `1180 × 728` 布局区渲染；应用外框在创建时固定为 `1180 × 760`，锁屏启动也不会缩短。空状态保留当前上下文，并明确指向“创建”或模板入口。

| 区域 | 状态 | 界面处理 | 快照 |
| --- | --- | --- | --- |
| 设备首页 | 遥控器已连接 / 未连接 | 在线且 macOS 已上报电量时，状态块按 Options+ 从 54pt 扩展到 103pt，直接显示电池、百分比和蓝牙；离线时设备降亮并直接显示蓝牙恢复和移除设备入口，仍可进入预配置 | `home`、`home-dark`、`home-disconnected`、`home-disconnected-dark` |
| 设备连接状态 | 点击电量 / 蓝牙状态块 | 保持参考的动态宽度与 40pt 高度；弹出卡片继续显示电量、固件、蓝牙设置和刷新入口 | `device-connection-status` |
| 设备首页 | 输入服务已停用 | 保留设备与全部配置，设备降亮且主控制切换为“启用”；重新启用后恢复 HID 接管 | `home-input-service-disabled` |
| 设备首页 | 已从 MiCoding 移除 | 停止输入服务、隐藏设备并显示单一添加入口；配置继续保留，重新添加后恢复 | `home-device-removed` |
| 设备首页 | 体验提示 / 关闭提示 | 主遥控器始终居中；进阶控制只以单行次级提示呈现，不重复展示第二个产品图。关闭后保持隐藏，偏好在重启后保留 | `home`、`home-recommendation-hidden` |
| 添加设备 | 扫描中 / 已发现 | 直接进入 Xiaomi Remote 2 Pro 配对页，不展示只有一个选项的“连接类型”中间页；包含 macOS 蓝牙入口、重新检查和显式采用设备操作 | `connection-pairing-searching`、`connection-pairing-found` |
| 探索中心 | 首页“查看用法” | 对齐原版一大两小卡片结构；按键测试、Actions Ring、应用 Profile 与更多玩法均进入对应真实功能 | `explore-center` |
| 本地配置 | 顶栏账户入口 | 沿用原版账户弹层的遮罩、比例和排版；单一紫色主操作直接导出完整本地配置，不伪造登录或云同步 | `home-local-profile` |
| 设备详情 | 空闲 / 悬停 / 打开动作抽屉 | 侧栏采用 13px 混合中英文字体；设备标注卡采用参考的 14px 动作名、12px 硬件名和 58.4pt 高度，悬停浅强调、编辑时实色选中 | `device-detail`、`device-detail-actions-ring` |
| 按键配置 | 尚未选择按键 | 隐藏无效的动作筛选，提示先在遥控器上选择按键 | `device-detail-no-selection` |
| 动作库 | 搜索或分类无结果 | 保留查询词、结果分组和紫色清除按钮，列表区域留白 | `device-detail-no-results`、`device-detail-no-results-dark` |
| 按键配置 | 按键尚未分配 | 保留动作目录，标题提示选择要执行的动作 | `device-detail-left` |
| 手势与连按 | 查看摘要 / 调整识别速度 | 围绕设备图显示可点击参数摘要；选中卡片变为强调色，并打开 394pt 右侧抽屉调整长按、双击或防抖，修改后立即持久化 | `device-gestures`、`device-gesture-settings-panel`、`device-gestures-dark` |
| 动作抽屉 | 切换单击 / 长按 / 双击 | 顶栏菜单切换触发层，标签、热点提示与选中动作同步；切换按键不丢失当前触发层 | `device-detail-left`、`device-detail-left-hold` |
| 动作抽屉 | 打开任意 App / 高级键盘映射 | 推荐区直接提供应用选择器；高级映射内联显示单击、长按、双击触发层，支持修饰组合、F1–F20 与导航键并持久化 | `keyboard-shortcut-assignment` |
| 动作抽屉 | 已分配显示 Actions Ring | 保持推荐列表原有顺序，选中行下展开原版式说明卡，并可直接进入 Actions Ring 配置后返回设备页 | `device-detail-actions-ring` |
| 应用 Profile | 点按顶栏“＋” | 右侧显示全局设置和本机已安装应用列表；勾选后立即加入顶栏并持久化 | `device-application-picker` |
| FLOW | 欢迎 / 跨 Mac 设置 | 恢复 Options+ 的 FLOW 侧栏与双电脑欢迎页；设置流程复刻本机/其他电脑结构，并直达 macOS“显示器与通用控制”及“隔空投送与接力”，用于跨 Mac 指针与通用剪贴板 | `device-flow`、`device-flow-setup`、`device-flow-dark`、`device-flow-setup-dark` |
| Actions Ring | 动作库分类筛选 | “所有操作”是可用分类菜单；切换到单一分类后立即展开对应动作，不保留无响应的伪按钮 | `actions-ring-editor` |
| Actions Ring | 运行时小 / 中 / 大浮层 | 环形动作与标签随尺寸缩放；透明窗口为外向标签预留空间，并在鼠标靠近屏幕边缘时完整夹入当前屏幕 | `actions-ring-runtime-small`、`actions-ring-runtime-medium`、`actions-ring-runtime-large` |
| Actions Ring | 文件夹子环 | 动作库可分配“工作模式”文件夹；运行时展开九个可执行子气泡，中央返回按钮回到主环 | `actions-ring-runtime-folder` |
| Actions Ring | 音量 / 亮度参数气泡 | 点击后沿圆环向外展开；滚轮和水平拖动会实时调用 macOS 原生音量或亮度调节，中央按钮退出参数态 | `actions-ring-runtime-adjustment` |
| 设备设置 | 信息与维护 | 使用与原版一致的窄栏分组滚动布局；检测、蓝牙、权限、本地备份/恢复、重置和停用均可操作，并可直达实体按键测试 | `device-information`、`device-information-disconnected`、`device-information-dark` |
| 智能操作 | 模板 / 管理 | 模板与已安装动作严格分离；模板卡对齐 260×320pt、24/14px 混合中英文字重及参考边框阴影，管理页保留启停、试运行、分配、复制、导出、编辑与删除 | `smart-actions`、`smart-actions-management`、`smart-actions-dark` |
| 智能操作 | 顶栏本地工作流入口 | 紧凑浮层只说明摘要、翻译与代码解释三类真实能力；单一主操作进入模板，不展示伪造的小型编辑器或装饰性 AI 插画 | `home-ai-prompt-notice-dark`、`smart-actions-ai-entry` |
| 智能操作 | 管理为空 | 保留管理筛选上下文，解释当前没有已安装工作流，并同时提供“创建工作流”和“浏览模板”真实入口 | `smart-actions-empty`、`smart-actions-empty-dark` |
| 智能操作 | 创建 / 编辑工作流 | 对齐原版整页 `如果… / 那么…` 窄列布局；支持设备、应用切换、Actions Ring 与可录制的全局快捷键触发器，动作菜单含应用（打开、关闭、置于前台）、快捷键、文本、网址、系统和延迟，节点支持参数编辑、悬停删除、拖拽排序、无效参数与快捷键冲突错误态 | `smart-action-editor`、`smart-action-editor-application`、`smart-action-editor-invalid-url`、`smart-action-editor-add-action`、`smart-action-editor-add-trigger`、`smart-action-editor-shortcut-trigger`、`smart-action-editor-shortcut-conflict` |
| 设备信息 | macOS 已上报电量 / 暂未上报 | 显示真实百分比；只有系统暂未提供字段时才显示“设备未上报” | `device-information` |
| 特性概览 | 实体按键测试 / 固件未知键值 | 逐键点亮 13 个目标；未映射键不会静默丢失，而会显示原始 HID Usage 与检测时间 | `feature-overview-key-test`、`feature-overview-key-test-unknown` |
| 权限 | 输入监控或辅助功能未授予 | 在“隐私与数据”分项显示权限状态和系统设置入口 | `settings-privacy-required` |
| 通用设置 | 检查更新 / 语言 | 更新按钮和自动检查开关读取 GitHub Releases 并显示明确状态；当前仅支持简体中文时使用只读选中卡，不伪装成可操作下拉菜单 | `settings-general`、`settings-general-dark` |
| Actions Ring 设置 | 支持入口 | 打开应用内四步使用说明，可直接进入动作环编辑器 | `actions-ring-support` |

MiCoding 只服务 Xiaomi Bluetooth Remote 2 Pro。设备离线时仍允许预先配置；用户主动从 MiCoding 移除后才显示空设备状态，并可从“添加设备”恢复。
