# iOS 重构（去罗盘 + 深度架构）进度与后续方案

分支：`refactor/no-compass`（从 `restore/full-features-2582c83` 拉出，指向 `2582c83` 的全量功能基线）
已提交 3 个 commit，尚未 push（无本地 Xcode，编译验证需 CI）。

## 一、已完成的三个提交

### 1. `7c8cfc9` refactor(ios): drop compass page, route tabs through AppTab

- 删除 `Views/Compass/` 下 7 个文件（`CompassMainView` 785、`CompassDialView` 627、`CompassHeaderView` 179、`FenjinDetailSheet` 92、`KongWangDetailSheet` 113、`FengshuiPalaceDetailSheet` 97、`LayerSettingsSheet` 76），以及只服务盘面的 `Models/CompassLayerManager.swift`。
- `Views/Compass/CalibrationSheet.swift`（247 行）迁到 `Views/Settings/CalibrationSheet.swift`：设置页仍在用双针校准入口，直接删会断链。
- `RootContentView` 由 5 Tab 收敛为 4 Tab（AR / 户型 / 理气 / 设置），仍然只是切换视图，不搬迁业务代码。
- 新增 `Core/App/AppTab.swift`、`Core/App/AppRoute.swift`：Tab 下标不再以字面量形式散落在视图、深链、快捷指令、Spotlight 路由里。
- `SceneDelegate` 的 `requestRoute` 改成接收 `AppTab`，旧下标由 `AppTab.fromLegacyIndex` 统一换算（0/3 → 理气、1 → AR、2 → 户型、4 → 设置）。
- `CompassMotionManager` 保留：AR、户型、理气、设置都要它提供的方位与真太阳时。

### 2. `ce512de` refactor(ios): centralize page state and sensor policy

- `Core/State/AppStateStore.swift`：把 RootContentView 原先 5 个平行 `@State`（选中的 Tab、理气子页、功能请求、引导页、黄历卡片）收进状态中枢，深链意图也在这里一次性归一。
  每个窗口各持一份 `AppStateStore`（iPad 多窗口不能共用 Tab），只有 `AppNavigationRouter` 单例共享。
- `Core/Services/SensorPolicy.swift`：把「哪个页面要常亮 / 要 device motion / 要持续方位」从三处裸下标比较收敛成一条规则。
- `Core/Services/ServiceProtocols.swift`：`LocalizationProviding`、`MotionProviding` 两个协议 + `AppService` 访问点；`LocalizationManager`、`CompassMotionManager` 已 conform，新代码可以不再直接摸单例。

### 3. `092f886` refactor(ios): split settings page and extract its view model

- `SettingsView.swift` 从 1,428 行拆成 9 个文件：根视图 261 行、大师会员 187、宅主命卦 316、语言 111、关于 186、个人资料 42、法律文书 29、链接常量 33、本地化帮助 257。
- 新增 `SettingsViewModel`：支付弹层的「是否显示 / 文案 / 是否错误 / 选中商品」由 ViewModel 持有，失败与成功共用一条呈现路径。
- `LegalDocument` 由 `private` 提升为 internal（跨文件使用）。

## 二、还没做的页面（按同一模式继续）

| 页面族 | 文件 | 行数 | 重构要点 |
|---|---|---|---|
| 理气 | `XuanKongGridView` | 1,462 | 九宫飞星从 body 里的同步计算移到 ViewModel；菜单状态改状态机 |
| 理气 | `BaZhaiView` | 2,963 | 八宅/三合/择日/人宅配四种模式共用大量状态，按模式拆 ViewModel + 子视图文件 |
| 理气 | `PurpleWhiteView` / `QimenDunjiaView` / `TianJiShuView` | 544 / 492 / 561 | 计算与渲染分离，长卷渲染移到后台 + 加载态 |
| 户型 | `FloorplanView` | 3,840 | 图纸导入/识别/房间编辑/体检/导出五段拆开；失败路径补 alert |
| 户型 | `FamilyRoomAllocationView` | 168 | 分配规则抽到模型层 |
| AR | `ARVisionView` | 2,632 | 相机会话、形煞档案、靶心测角、水印存证拆成独立 service + ViewModel |
| AR | `ARSpatialSurveyView` | 3,176 | 测绘状态机（扫描/平面/门窗/梁/鲁班尺）独立 |
| AR | `ARRoomPlanCaptureView` | 1,427 | RoomPlan 会话生命周期集中管理 |
| AR | `VRSpatialSurveyView` | 805 | 手绘测绘状态收敛 |
| AR | `House3DSpaceViewer` | 1,613 | 场景构建与 UI 面板分离 |

统一约定（后续每个页面一个提交）：

1. 页面状态一律进 `XxxViewModel`（`@Published` 输入 + `func` 动作），视图只保留布局。
2. 依赖从 `AppService` / 协议取，不再新增 `.shared` 直连；已有的在迁移该页时顺手替换。
3. 超过 1,000 行的视图文件按 `// MARK:` 段落拆成同目录多文件，拆完的每个文件保持单一职责。
4. 每次提交前跑静态检查：括号平衡、`git grep` 确认无悬挂符号、`xcodebuild` 交给 CI。

## 三、需要留意的地方

- **未编译验证**：Windows 环境没有 macOS/Xcode，三个提交只做了静态检查。要确认编译，需要 push 触发 `.github` 的 macOS runner。
- **深链语义变化**：原「罗盘」深链 `/compass` 与旧下标 `0` 现在落到理气页；`index=3` 仍保留「户型」的历史语义（widget 里曾这么用）。上线前建议核对小组件与网页里的深链参数。
- **多窗口**：`AppStateStore` 是按窗口创建的，`AppNavigationRouter` 仍是全局单例；两个窗口同时收到深链时，只有先消费的那个生效（与改动前一致）。
- **i18n 未清理**：`tab_compass` 等罗盘专属键仍留在 8 张表里（死键，不影响运行）。清理会改动语言表，按既有约定（不动中日韩表）需要单独评估。

生成时间：2026-11-15
