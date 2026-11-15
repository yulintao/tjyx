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

## 四、产品收窄：AR 测绘 + 户型布局 + 家人分配

用户把产品范围定为「通过 AR/VR 分析，根据房屋布局合理安排家人居住，其他的都不要」，
并要求「全部重构，收费先取消，等功能出来以后再看怎么收费」。据此做了五个提交。

| 提交 | 内容 |
|------|------|
| `e241ecb` | 导航收口到 AR / 户型 / 设置三个 Tab，删除 `Views/Analysis` 全部 11 个文件（八宅、紫白、奇门、长卷、玄空），pbxproj 同步删 44 行 |
| `aa857c4` | 删除 `TianJiShuEngine`（长卷渲染器，内含 `TianJiAnalysisSnapshot`），删前确认零引用 |
| `425c19c` | 收费暂停：`hasUnlockedVIP` / `canUseFloorplan` / `canUseFamilyRoomAllocation` / `canUseTianji` 四个门禁统一放行 |
| `addbc7a` | 找回被 `BaZhaiView` 带走的四个类型（见下方「删除风险」） |
| `00875a3` | 撤下设置里的会员中心入口，删除 `MasterVIPPageView` 与其商品状态 |

### 为什么理气引擎留下

引用扫描结论：这些引擎不是分析页专属，而是空间功能的内核。

```
FamilyRoomAllocation      → BaZhaiEngine（按家人命卦算吉凶方）
FloorplanEngine           → XuanKongDeepAnalyzer、PurpleWhiteEngine、BaZhaiEngine
HouseSpatialSurveyModel   → BaZhaiEngine、FlyingStarsEngine
House3DSpaceViewer        → BaZhaiEngine、FlyingStarsEngine
ARVisionView              → SanHeWaterEngine、ZeRiEngine、BaZhaiEngine
```

可删的是页面与报告，引擎必须留。真正零引用、已删除的只有 `TianJiShuEngine`
（连带的 `TianJiAnalysisSnapshot` 一并消失）。

### 删除风险：页面文件里藏着别家在用的类型

`BaZhaiView.swift` 里同时定义着 `OwnerLifeGuaView`、`AddFamilyMemberDialog`、
`EditOwnerKuaDialog`、`OwnerGuaVIPGate`、`ActiveSheet` 五个类型，其中前四个分别被
`FamilyRoomAllocationView.swift`（家人分房的「添加家人」弹窗）与
`OwnerKuaReminderPageView.swift`（设置里的宅主命卦提醒）使用。删页面等于删掉它们，
工程会编不过。已原样搬到 `Views/Floorplan/OwnerLifeGuaView.swift`（1,865 行），
删掉搬迁后无人使用的 `ActiveSheet`，pbxproj 四处登记（`1108` / `2110`）。

教训：删一个视图文件之前，先把它定义的**顶层类型**列出来，逐个查引用，
不能只看文件名是否被引用。

### 现状与待办

- 家人分房本来就已经接在户型页里（`FloorplanView` 第 498 行
  `FamilyRoomAllocationSection`），含标签开关、手动分配、添加家人与持久化，不需要新接线。
- 工程登记已核对：主 target 53 个 swift 文件、54 条 `PBXBuildFile`，
  id 与文件引用一一配对，无幽灵条目、无漏登记。
- 已做：应用内「今日吉方」日签卡片下线（`ca4f3dc`）。渲染器与分享弹层从
  `BaZhaiEngine` 移除（该文件 2,711 → 2,330 行），`RootContentView` 不再呈现，
  主屏快捷指令与 Spotlight 里指向它的条目一并删除。旧深链仍落到 AR 页，不会死链。
- 未做：独立 widget target（`TiandiLuopanWidget/AlmanacWidgetViews.swift` 1,416 行 +
  `TiandiLuopanAlmanacWidget.swift`）仍会显示今日黄历，下线需动 target 级配置。
- 部分完成：用户可见的收费痕迹已清（`1185c90`）。家人分房卡片去掉了
  「会员权益」角标、解锁按钮和付费弹层，设置页头像不再戴皇冠、不再显示
  「会员/标准用户」徽标。`fra_membership`、`fra_paywall`、`fra_unlock` 三个键就此成为死键，
  按既有约定未动语言表。
- 未做：`VIPPaywallSheet` 与 AR / 户型内层的锁图标与 `showPaywall` 弹层（约 60 处）。
  门禁放行后它们触发不到，属死代码，清理不影响功能，留待编译验证后再收。
- 已做：设置页副标题从「专业风水罗盘与玄空理气」改为实际范围（AR 实景测绘 ·
  户型布局 · 家人分房），八语同步（`e214ccb`）。
- 仍未编译、未 push：本机没有 Xcode，十个提交只过了静态检查（括号配平、
  悬挂符号扫描、pbxproj 登记核对、id 配对审计）。推送被阻断：远端走 SSH，
  私钥 `id_ed25519_github` 带口令且系统 ssh-agent 处于 Disabled，Windows 凭据管理器
  里也没有 GitHub 条目，非交互进程无法完成认证。
