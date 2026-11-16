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
- 已做：独立小组件 target 整条下线（`6da0d35`）。摘掉原生 target、它的配置列表与两套
  构建配置、容器代理、target 依赖、Embed App Extensions 拷贝阶段、三个阶段
  （Widget Sources / Frameworks / Resources）、它的 group、产物引用以及 14 条 BuildFile；
  随后 `WidgetAlmanacSnapshot.swift`（436 行）失去唯一调用方一并删除，两处仅用于刷新
  小组件的 `WidgetCenter.reloadTimelines` 与 App Group 镜像写入也清掉。工程现在只剩
  `TiandiLuopan` 与 `TiandiLuopanTests` 两个 target。
- 部分完成：用户可见的收费痕迹已清（`1185c90`）。家人分房卡片去掉了
  「会员权益」角标、解锁按钮和付费弹层，设置页头像不再戴皇冠、不再显示
  「会员/标准用户」徽标。`fra_membership`、`fra_paywall`、`fra_unlock` 三个键就此成为死键，
  按既有约定未动语言表。
- 未做：`VIPPaywallSheet` 与 AR / 户型内层的锁图标与 `showPaywall` 弹层（约 60 处）。
  门禁放行后它们触发不到，属死代码，清理不影响功能，留待编译验证后再收。
- 已做：设置页副标题从「专业风水罗盘与玄空理气」改为实际范围（AR 实景测绘 ·
  户型布局 · 家人分房），八语同步（`e214ccb`）。
- 编译状态：截至 `73b7f55` 的十笔提交已由 CI 验证通过
  （`iOS Multi-Mode Build & Deploy #161`，6m37s，`refactor/no-compass`）。
  此后四笔（`1185c90` 付费痕迹、`e214ccb` 副标题、`4958427` 文档、`6da0d35` 小组件下线）
  尚未编译验证，只过了括号配平、悬挂符号扫描、pbxproj 登记核对与 id 配对审计。
- 推送：本机 SSH 私钥带口令、系统 ssh-agent 处于 Disabled、Windows 凭据管理器里没有
  GitHub 条目，非交互进程无法完成认证；远端已被更新到 `73b7f55`，剩余四笔待推。

### 收尾两笔：黄历路由空转链与付费墙

`45b0ea5`：日签卡下线后，`AppRoute.openDailyCard`、`AppNavigationRouter` 的
`pendingAlmanacRoute` / `requestAlmanac` / `consumeAlmanac`、`AppStateStore.showShortcutDailyCard`、
`.didTapAlmanacWidget` 的定义与三处投递已无任何语义——它们只是置一个没人读的 bool、
发一条没人收的通知。`AppRoute` 收敛成单一 `tab`，`requestRoute(tab:)` 单参，
旧 `almanac` 深链和其它退役链接一样落到 `.ar`。

`20b5ccd`：付费弹层从应用里消失。`showPaywall` 只被额度与 VIP 门禁赋值，而这些门禁
恒真，所以 `VIPPaywallSheet` 结构、购买披露块、六处 `.sheet($showPaywall)`、七个
`@State showPaywall`、`paywallDefaultProduct` 及其全部赋值、关于页的「恢复购买」行
一并删除；文件剩 `VIPLockCardView`，改名为 `VIPLockCardView.swift`，工程登记四处同步。
锁卡仍被 AR 与户型页的 `hasUnlockedVIP` 分支引用，分支今天是死的——等门禁彻底去掉时一起删。

### 锁卡与门禁分支的收尾

上一节留着 `VIPLockCardView`，因为它被三处 `if !iap.hasUnlockedVIP` /
`if !hasFloorplanAccess` 分支引用。这三处分支现在恒真，锁卡永不渲染，所以直接解开：
AR 页的形煞补救段与户型页的体检清单都保留 `else` 那一支内容、变成无条件渲染；
`OwnerGuaVIPGate` 退化成 `var body: some View { content() }` 并丢掉 `iap`/`lang` 依赖。
锁卡本身再无人引用，文件删除，工程里 `1068`/`2068` 四处登记一并摘除。
审计回到 52/52 配对，`VIPLockCardView`/`showPaywall`/`paywallDefaultProduct` 三个符号全树零命中。

仍未动的是 `hasFloorplanAccess` 的额度授予链（`acquireFloorplanAccess`、`didConsumeFloorplanCredit`、
grant 签名与持久化）。它已走不到——门禁恒真时 `hasFloorplanAccess` 恒为真是因为
`iap.hasUnlockedVIP` 恒真——但牵动布局持久化格式，留待有编译反馈的一轮再收。

### 户型额度门禁也放行

`hasFloorplanAccess` 与 `acquireFloorplanAccess()` 这两个判断点是户型页最后在问
「你有没有额度」的地方。前者收成 `true`，后者整段 30 行的额度授予流程
（reserve → persist → commit → cancel）替换成 `true`，注释写明恢复收费时改回哪个表达式。
`didConsumeFloorplanCredit`、`floorplanCreditsCount`、`FloorplanCreditPurchase` 与
grant 存档字段都留着——它们参与布局档案格式，动它们要以能编译为前提。


### 删掉小组件之后，CI 里还留着三道「必须有小组件」的硬门槛

target 删掉之后的第一次 CI 立刻失败，失败点不是编译，是 `tools` 里的回归测试：

```
test_both_manifests_declare_app_group_defaults
FileNotFoundError: .../ios/TiandiLuopanWidget/PrivacyInfo.xcprivacy
```

两处代码把小组件目录写死在名字里——`check_swift_target_dependencies.py` 的 `ROOTS`
固定扫 App + Widget 两个目录，并在 `source_phases` 里硬要求 `{"Sources","Widget Sources"}`
两个阶段都存在；对应测试则遍历 `["TiandiLuopan","TiandiLuopanWidget"]`。删掉 target 后
前者直接抛 `App and widget source phases must both be checked`，后者报错找不到私隐清单。

改法都是「按实际存在的 target 校验」：`ROOTS` 在导入时按目录是否存在过滤，Widget 源阶段
只在小组件目录还在时才要求；清单测试改成 `glob("*/PrivacyInfo.xcprivacy")` 走一遍实际存在的清单，
不再硬写两个目录名。本地复跑 CI 同款两步：13 个测试 OK，检查脚本输出
`Checked 1 source phases (52 compilation entries); 0 unavailable local types`。

`build-ios.yml` 里还有三处更隐蔽的：app-store 模式缺小组件描述文件 `exit 1`、导出后的 IPA 里
找不到 `*.appex` 就 `exit 1`、以及 `WIDGET_PROV_RAW` 分支去装旧的小组件描述文件——
第三处会在 App Store 开通里留下一个指向已不存在 target 的配置。现在三处都以
「工程里是否还有 `TiandiLuopanWidget.appex`」为前提（运行时 grep `project.pbxproj`），
没有小组件就跳过；App Group 那段错误文案也不再声称「主 App 与小组件描述文件都要带这个组」。
改完用 PyYAML 解析过整个 workflow（14 个 step 结构完好），但这只证明 YAML 合法，
shell 分支要等一次真跑。

### 收尾编译验证（第一次等编译器说话之前的体检）

这一批改动（拆 target、删 11 个分析页、删付费墙、配色 token、P0/P1 界面）在推送前先按仓
库自带的静态检查逐项过了一遍，因为本机没有 Xcode，编译器要到 CI 上才第一次开口：

- `validate_swift_syntax.py`：53 个 Swift 文件，括号与语法错误 0。
- `check_swift_target_dependencies.py`：`Checked 1 source phases (52 compilation entries);
  0 unavailable local types`。
- `check_identifiable.py`：148 个 struct、40 个 Identifiable，全部有合法 `id`。
- `check_localization_keys.py`：8 种语言各 827 个 key，缺 key 0、重复 0、未用 292。
  未用 key 是删页面与删付费墙的必然残留；按「不动中/日/韩三张语言表」的既定偏好，
  这批死 key 暂不清。
- pbxproj 登记审计：53/53 配对，唯一报项是 `FunctionalRegressionTests.swift` 的
  `children = (9602 …,);` 单子项内联写法——脚本按缩进匹配所以误报，条目本身在。

顺手修掉一个真会编译失败的写法：分房面板 `tierColor(_:)` 里原本用
`case .some:` 兜四个凶位，Swift 的 optional 模式不接受不带子模式的 `.some`，
改为 `case nil:` 先判空、再用 `default:` 兜凶位。

本轮两个决定（用户拍板）：新增文案**八语一起补**，译文由实现方起草交用户审；
P3 报告页**暂缓**，先让编译器与真机把 P0/P1 验证过去再谈形态。

## CI 里的 Bundle ID 只有一处来源（2026-11-16）

`APP_BUNDLE_ID` 原来在 workflow 里另存了一份 `com.tjyx.compass`。它和工程一旦分家，报错会落在
「描述文件不覆盖」上，看起来像证书/描述文件的问题，实际是 CI 自己记错了 ID。现在：

- workflow 里的 `APP_BUNDLE_ID` 默认留空，签名步骤从 `project.pbxproj` 的
  `PRODUCT_BUNDLE_IDENTIFIER` 读出真值（实测提取到 `com.tjyx.compass`），
  与 env 不一致时给 warning 并以工程为准，写进 `$GITHUB_ENV` 供后续步骤使用；
- 描述文件错配的提示补上了「该塞进哪个 secret」（`DEV_PROVISION_PROFILE` /
  `DIST_PROVISION_PROFILE`），原来说的 `PROVISIONING_PROFILE` 没有任何步骤读取。

仍未定：账户里注册的到底是 `com.tjyx.compass` 还是只有改名前的 `com.yanxiang.compass`。
前者只需为新 ID 签一个开发描述文件；后者要在 portal 新建 ID，或把工程与 CI 一起回滚成旧 ID
（能沿用现有 App Store 记录）。哪一种都没动手，等确认。

## 第一次真正跑到 xcodebuild（2026-11-16，run #165）

之前两次都死在签名前。这次在浏览器里把门户和仓库都核实了一遍：

- App ID `com.tjyx.compass` **早就注册了**（Identifiers 里叫 `tjyx`），不必新建；
- 描述文件 `tjyx_dev_profile`（Development，1 台设备）与 `tjyx_appstore_connect`（App Store）
  同样已经存在，App ID 都对；
- **实际团队是 `9ZK328P458`**，而证书 CN 里写的是 `W6QFD6Y86F`——两个值不是一回事，
  secret 里存哪个都可能让 `EXPECTED_APP_ID` 对不上；
- App Groups 一个都没注册，工程也没有 entitlements 文件，App Group 只剩
  `LocalizationManager.appGroupID` 一个没人读的字符串，属小组件时期残留。

据此改了两处 CI 逻辑：Bundle ID 与 Team ID 都以「工程 / 描述文件」为准，
secret 只在冲突时给出警告并被覆盖（`f8f0560`、`b3b677e`）。

随后把 `DEV_PROVISION_PROFILE` / `DIST_PROVISION_PROFILE` 用浏览器写进仓库 secrets
（base64 分别 18884 / 16120 字节），派发 run #165：**描述文件校验通过，进入 `xcodebuild`**，
16 秒后以退出码 65 失败，日志（Build-Logs artifact）里只有一处真错误：

```
OwnerKuaReminderPageView.swift:220:14: error: Consecutive statements on a line must be separated by ';'
OwnerKuaReminderPageView.swift:220:15: error: Expected expression
```

原因是删付费墙时留下了 `} else {` 而没有配对的 `if`：那个 `}` 把 `List` 提前闭合，
后面的「节气提醒」Section 落到了语句层。删掉这个孤立 else 及其空的 VIP 占位 Section
（`c9a9586`），括号深度回到 0，`validate_swift_syntax.py` 53 文件 0 错。

这也说明：**此前的静态检查抓不到这一类问题**。`validate_swift_syntax.py` 只验括号配平，
而这个文件的括号本来就是配平的，错在语义层。真正的验收只能靠一次真编译。

## 第一次出包（run #167，2026-11-16）

`8950dff` 之后派发的 run #167 在 5 分 35 秒内 **Success**，14 个步骤全绿，
产出 `TiandiLuopan-development-IPA`（2.52 MB）。之前一次 run #166 只用了 1 秒就死：

```
line 22: TEAM_ID: unbound variable
```

签名步骤把 `TEAM_ID` 写进 `GITHUB_ENV` 的语句原本只在「secret 为空」和「secret 冲突」
两个分支里，于是 secret 恰好与描述文件一致时反而什么都不导出，下一步
`DEVELOPMENT_TEAM="$TEAM_ID"` 在 `set -u` 下直接炸。改成无条件导出后即通过；
同时把整份 workflow 的 shell 变量可见性审计了一遍（job env / step env / 本步赋值 /
`GITHUB_ENV` 写回），除 `for` 循环变量外没有第二处裸引用。

包内实际内容（对下载回来的 IPA 解包读 Info.plist）：

| 字段 | 值 |
| --- | --- |
| CFBundleIdentifier | `com.tjyx.compass` |
| CFBundleDisplayName | 天机演象 |
| CFBundleShortVersionString | 1.3.4 |
| CFBundleVersion | 261116.752 |
| MinimumOSVersion | 16.0 |
| DTSDKName | `iphoneos27.2` |
| embedded.mobileprovision | 存在 |

`DTSDKName` 是 `iphoneos27.2`，所以「必须 iOS 27.1+ SDK 编译」这条断言是真实通过而不是被跳过。

## 小组件残留的假警告

run #167 的 6 条警告里，有 4 条在讲一个不存在的 target：小组件目录早已删除，
`project.pbxproj` 里也搜不到 `TiandiLuopanWidget.appex`，但 workflow 仍然
无条件打印「Expected App ID: …widget」「No widget provisioning profile secret found」，
并检查两个在工程里根本没被引用的 `WIDGET_` 覆盖变量。

现在这两组提示都以「工程里是否真有 appex」为前提：有才检查、有才警告。
留着的 `WIDGET_CODE_SIGNING_ALLOWED=NO` 等命令行参数对没有该 target 的工程是无害的空操作，
真正的兜底逻辑（app-store 模式下缺小组件描述文件就拒绝）也还在。


## app-store 模式第一次进 TestFlight（run #168）

这一轮之前的失败都停留在「证书/描述文件/App 记录」这几样资源上，而不是代码。补齐它们的过程分三段：

**1. 先把资源和名字对齐**

- 账户里**没有任何发布证书**；三个 App Store 描述文件（`tjyx_appstore_connect` 等）绑的都是
  已经不存在的证书，签不出来。bootstrap `--create-certificates` 新建 `Q9UX2L7L2J`，
  `.p12` 与 `.b64` 落在 `tools/appstore_out/certificate.dist.p12`，密码 `Tjyx2026Cert`。
- `get_bundle_id()` 取 `filter[identifier]` 的第一个结果，而账户里同时有
  `com.tjyx.compass`（`FB9FYFP4W6`）和 `com.tjyx.compass.9ZK328P458`（`2H2YWNVQPA`），
  于是第一版发布描述文件 `VMLD28DA7L` 绑到了带团队后缀的**不是这个 App** 的标识上。
  改成按 identifier 全等过滤后删掉它、重建为 `D77TW36ZQ7`；用
  `read_profile_metadata()` 回读确认 `application-identifier = 9ZK328P458.com.tjyx.compass`。
- 「我的 App」里没有 `com.tjyx.compass` 的记录，`POST /v1/apps` 回 403
  （`does not allow 'CREATE'`）。网页新建记录 `6835357727` 成功，SKU `TJYX-IOS-001`、
  主要语言 `zh-Hans`。名称 `天机演象` 被拒（与账户里已有的 `天機演象` 判重），
  记录名暂用 `天机演象罗盘`，App 名称之后可改。
- GitHub secrets 里那三个键名是**截断的**（`DEV_CERTIFICATE_P` / `DIST_CERTIFICATE_P` / `P`），
  workflow 读的是 `..._P12` 与 `DIST_P12_PASSWORD`，所以 `github --apply` 从来没写对过。
  本轮按 `build_secret_bundle()` 逐条写入：`DIST_CERTIFICATE_P12`（4428 字符）、
  `DIST_P12_PASSWORD`、`DIST_PROVISION_PROFILE`（16072 字符）、`APPSTORE_API_KEY_ID`
  `V8HURHGAZC`、`APPSTORE_ISSUER_ID`、`APPSTORE_API_PRIVATE_KEY`（PEM 257 字符）、
  `APPLE_TEAM_ID=9ZK328P458`。

**2. 真跑**

run #168，`app-store` + `upload_to_appstore`，14 步全绿，5 分 54 秒：

| 步骤 | 时长 |
| --- | --- |
| Build Archive | 3m 26s |
| Export IPA | 6s |
| Upload to App Store Connect (TestFlight) | 1m 45s |

产物 `TiandiLuopan-app-store-IPA` 4.95 MB。

**3. 用 API 回验上传**

`GET /v1/builds?filter[app]=6835357727` → 1 条，`processingState = VALID`，
`uploadedDate = 2026-11-16T00:33:06-08:00`。这是「真的进了 TestFlight」，不是「命令退出码 0」。

**还没进 TestFlight 的改动**：本地 `eb8c6c9`（户型页最左 + 权限按需）与 `a9cacc4`
（小组件假警告）当时未推送，所以 #168 编的是 `8950dff`。要验这两个改动，需要推送后再跑一次
`app-store`。

## 产物文件名改为 tianjiwushe

workflow 里加了一个 job 级变量 `PACKAGE_NAME: tianjiwushe`，只作用在**打出来的文件名**上：

- `Export IPA` 找到 xcodebuild 产出的 `TiandiLuopan.ipa` 后 `mv` 成 `tianjiwushe.ipa`，
  再回写 `IPA_FILE` 给后面的签名校验、SHA256、artifact 上传用；
- artifact 名从 `TiandiLuopan-app-store-IPA` / `TiandiLuopan-Build-Logs-*`
  改成 `tianjiwushe-app-store-IPA` / `tianjiwushe-Build-Logs-*`。

没有动工程的 target / PRODUCT_NAME / CFBundleExecutable——那会牵动 pbxproj 与包内可执行文件名，
且与上架身份无关；改名只发生在导出之后的文件层。

## 身份换成 tianjiwushe（com.tianjiwushe.app）

按「新建记录 + 新 Bundle ID」的方案把上架身份整体换掉，不是只改名字：

| 项 | 旧 | 新 |
| --- | --- | --- |
| Bundle ID | `com.tjyx.compass` | `com.tianjiwushe.app`（测试 target `com.tianjiwushe.app.tests`） |
| 包内 `.app` / 可执行文件 | `TiandiLuopan.app` / `TiandiLuopan` | `tianjiwushe.app` / `tianjiwushe` |
| 桌面显示名（CFBundleDisplayName） | 天机演象 | tianjiwushe |
| App Store Connect 记录 | `6835357727`（现名「天机屋舍」，绑旧 Bundle ID） | `6835371832`（tianjiwushe，SKU `TIANJIWUSHE-001`，zh-Hans） |
| Bundle ID 资源 | `FB9FYFP4W6` | `P38GDA8XXN` |
| App Store 描述文件 | `D77TW36ZQ7` | `H6F97C5FV8`（`9ZK328P458.com.tianjiwushe.app`，get-task-allow=false） |

改动落点：`PRODUCT_BUNDLE_IDENTIFIER` 两处、`PRODUCT_NAME = tianjiwushe`（并钉住
`PRODUCT_MODULE_NAME = TiandiLuopan`，否则 `@testable import TiandiLuopan` 会断）、
`Info.plist` 的 `CFBundleExecutable` 改 `$(EXECUTABLE_NAME)`、`CFBundleIdentifier` 改
`$(PRODUCT_BUNDLE_IDENTIFIER)`、`CFBundleDisplayName` / `CFBundleName` 改 `tianjiwushe`、
测试 target 的 `TEST_HOST`、scheme 的 `BuildableName`、pbxproj 的 productReference、
CI 里解包校验的 `.app` 路径、本地 `package_ipa.py`。

**没有跟着换的**：`group.com.tjyx.compass`（工程无 entitlements，没有实际使用的共享容器；
要换得在 portal 建新组并加 entitlements）、StoreKit 商品 ID、通知名、`UserDefaults` 键、
URL scheme `com.tjyx.compass.almanac` —— 这些都是标识串而非上架身份，换掉会牵动深链与
老数据兼容。

**开发描述文件暂时建不了**：iOS 开发描述文件必须至少含一台已登记设备，而账号里没有任何
设备 UDID（配置里那条 `00008110-0000000000000000E` 是占位符）。所以 `DEV_PROVISION_PROFILE`
仍是旧 Bundle ID 的那份，`development` 模式会签名失败；要签开发包，把真机 UDID 填进
`apps[].devices` 再跑 `--add-devices`。

旧记录 `6835357727` 与新工程不再对应，它上面那条 `processingState = VALID` 的构建仍留在
它的 TestFlight 里；App Store Connect 不支持删除 App 记录，只能后续自己决定是否弃用。