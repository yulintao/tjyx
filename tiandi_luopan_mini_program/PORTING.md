# iOS 完整功能 → 微信小程序移植说明

来源分支：`full-features`（iOS `TiandiLuopan`，含罗盘 / 八宅 / 玄空 / 三合 / 择日 / 奇门 / 紫白 / 天机数 / 户型 / AR）。

> 状态说明：下表「已完成」指页面可运行、能出盘并给出断语；**不等于与 iOS 功能等价**。逐项缺口见 `MIGRATION_AUDIT.md`。经 2026-11-16 至 11-17 六轮补齐，`full-features` 中**所有不依赖 RoomPlan / LiDAR / ARWorldMap / RealityKit / StoreKit / Widget / iCloud KVS 实时同步 / 端侧视觉识别**的实体能力均已在小程序侧落地（含测绘参数与报告长图）；多语种按产品决定仅简体；其余平台硬限制项各有等价实现，见 `GAP_AUDIT_2026-11-17.md` 第十一、十二节。

## 一、模块对照

| iOS 模块 | iOS 源码 | 小程序页面 | 小程序引擎 | 状态 |
|---|---|---|---|---|
| 罗盘（24 山、空亡、120 分金、真太阳时、磁偏角） | `Views/Compass/*`、`CompassMotionManager` | `pages/index` | `utils/compass-data`、`fengshui`、`geomagnetic`、`astronomy`、`solar-terms` | 已有，保留 |
| 玄空飞星（三元九运、下卦/替卦、81 组合） | `FlyingStarsEngine.swift` | `pages/xuankong` | `utils/xuankong` | 已完成 |
| 八宅（命卦、大游年、宅命合配、家人配房） | `BaZhaiEngine.swift` | `pages/bazhai` | `utils/bazhai` | 已完成 |
| 紫白（年/月紫白、五黄二黑、太岁岁破三煞） | `PurpleWhiteEngine.swift` | `pages/zibai` | `utils/zibai` | 已完成 |
| 三合水法（八路黄泉、八煞、十二长生、纳水） | `SanHeWaterEngine.swift` | `pages/sanhe` | `utils/sanhe` | 已完成 |
| 择日（建除十二神、日课、时辰、吉日） | `ZeRiEngine.swift` | `pages/zeri` | `utils/zeri` | 已完成 |
| 奇门（时家奇门、节气定局、值符值使、九星八门八神） | `QimenEngine.swift` | `pages/qimen` | `utils/qimen` | 已完成（转盘·拆补法） |
| 天机数 / 天机长卷（全盘汇总、长图导出） | `TianJiShuEngine.swift` | `pages/tianji` | `utils/tianji` | 已完成（Canvas 长图 + 复制全文） |
| 户型九宫（房间归宫、缺角、房间审计） | `FloorplanEngine.swift` | `pages/floorplan` | `utils/floorplan` | 已完成（手绘录入，非 AR 扫描） |
| 分析总览 | `RootContentView` | `pages/analysis` | — | 已完成 |
| 120 分金（纳音、珠宝火坑、二十四山吉度） | `Fenjin120Data.swift` | `pages/fenjin` | `utils/fenjin` | 本轮补齐（120 位全表） |
| 六十四卦（抽爻换象、之卦互卦错卦综卦） | `Hexagram64.swift` | `pages/gua64` | `utils/hexagram` | 本轮补齐（卦辞爻辞仍缺） |
| 外煞 / 峦头（辨识、影响、化解、自查评分） | `ExteriorShaEngine.swift` | `pages/sha` | `utils/sha` | 本轮补齐（23 类，AR 自动识别未做） |
| 设置中心（语言、单位、提醒、清空、关于） | `SettingsView.swift` | `pages/settings` | `utils/store` | 本轮补齐（恢复购买按约定不迁） |
| 实景叠盘（相机 + 靶心测角 + 水印存证） | `ARVisionView`（ARKit 版） | `pages/ar` | `utils/fenjin`、`utils/sitface` | 降级替代（不含深度与自动识别） |
| 3D 体块示意（等轴测） / 空间测绘报告 | `House3DSpaceViewer`（SceneKit 版）、`HouseSpatialSurveyEngine`、`SurveyReportRenderer` | `pages/floorplan` 内 3D 视图、`pages/report` | `utils/floorplan.isoBlocks`、`surveyMetrics`、`reportcard` | 3D 渲染为降级替代；尺寸/面积/得分/缺角/凶宫与报告长图已对齐（净层高、墙体、开孔因无 LiDAR 标「未采集」） |
| 本地存档（档案、任务、户型、历史、设置） | 各 Engine 存档逻辑 | 各页按需接入 | `utils/store` | 已接入（设置/八宅/户型/历史） |

罗盘页右下角新增「盘解」入口，直达分析总览；分析页内十三个模块可互相跳转，并按当前坐向/朝角传参（分金与六十四卦按度数，其余按坐山）。

## 二、不能移植 / 已替代

1. **RoomPlan 扫描与自动量房**：`ARRoomPlanCaptureView` 依赖 `RoomCaptureSession`（13 处）与 `CapturedRoom`（35 处），这是系统进程内的房间语义模型（墙/门/窗/家具类别 + 尺寸 + 拓扑），第三方 App 也只能调用、不能实现，小程序更无入口。**结论：采集端不可移植**。替代：`floorplan` 手工录入 + 底图描摹 + 九宫覆盖率。
2. **LiDAR 深度网格（`sceneDepth` 13 处、`ARMesh` 13 处、`raycast` 26 处）**：小程序拿不到深度图、场景网格与相机内外参，也就没有“贴墙锚点、点对点测距、遮挡关系”。`pages/ar` 因此只做**取景 + 靶心测角 + 拍照水印**，不做量房、不做遮挡融合、不做形煞自动识别（形煞回到 `pages/sha` 人工勾选）。
3. **VR 空间测绘采集**：`VRSpatialSurveyView` 的数学层只依赖 `simd`，可迁；但其全景采集与沉浸式浏览没有对应能力，未做。
4. **StoreKit 2 内购 / 会员 / 永久版 / 单次解锁**：不移植。微信规定 iOS 端小程序不得提供虚拟商品购买与支付。
5. **App Group / iCloud KVS 同步、Widget**：小程序以 `wx.setStorageSync` 本地存储，跨设备同步需自建后端或微信云开发，本版未接。
6. **多语种本地化**：iOS 的 8 语种文案不迁移（产品决定仅简体中文）。设置页语言项固定「简体中文（固定）」，不提供切换；如需扩展，再按 key 表引入。

> 口径说明：以上“不可移植”均指**原生框架与硬件底座不可移植**，不是算法层。`HouseSpatialSurveyModel`（210.5 KB）只依赖 `Foundation/CoreGraphics/simd`，其几何与数据层是可迁的，已按重心、覆盖率、面积、体块投影四类逻辑落到 `utils/floorplan.js`。

## 三、算法校验

已用 Node 对纯逻辑做离线验证（`node --check` 全部通过）：

- 玄空：24 山 × 9 运 × 2（下卦/替卦）全量不抛错；八运旺山旺向恰为古法六局（丑山未向、未山丑向、巽山乾向、乾山巽向、巳山亥向、亥山巳向）；九运因「九紫只居中宫」无旺山旺向局，与沈氏结论一致。
- 八宅：坎命大游年 = 坎伏位/艮五鬼/震天医/巽生气/离延年/坤绝命/兑祸害/乾六煞；乾命 = 兑生气/坤延年/艮天医，与《大游年歌》逐宫吻合；1980 男命坤二、2000 男命离九。
- 紫白：2024 三碧、2025 二黑、2026 一白；立春换年、节气换月；2026 年五黄落离、二黑落乾（与太岁午、岁破子、三煞亥子丑一致）。
- 三合：申子辰水局、亥卯未木局、寅午戌火局、巳酉丑金局的长生起点与十二阶段顺时针排布；乾山巽向、坤山艮向判为救贫黄泉。
- 择日：建除按节气月建顺数；日破、旬空、六合、三合标记；冲坐山与三煞提示。
- 奇门：节气定局（立冬上元阴遁六局）、地盘三奇六仪阳顺阴逆、值符加时干、值使随时宫、八神阳顺阴逆。
- 压力用例：289 组坐向/元运/日期组合全部通过，天机长卷固定输出 8 章。

## 四、下一步建议

1. 户型：加拖拽改尺寸、房间增删、多户型存档、面积换算（㎡）。
2. 奇门：补用神（年命、日干、时干）旺衰与格局断语。
3. 长卷：加落款、印章、分享卡片（`onShareAppMessage` 竖版海报）。
4. 多语言：按 iOS `LocalizationManager` 的 key 结构补 en / ja / ko / zh-Hant。
5. 数据同步：接微信云开发，替代 iCloud KVS。

## 五、运行

微信开发者工具导入 `tiandi_luopan_mini_program` 目录即可；AppID 使用测试号，罗盘需真机调试（模拟器无磁力计）。

## 六、导航结构（tabBar 改造 · 2026-11-16）

- 底部 tabBar 五项：罗盘（pages/index）· 盘解（pages/analysis）· 择日（pages/zeri）· 户型（pages/floorplan）· 关于（pages/settings）。纯文字无图标，未选色 `#6f7a8f`，选中色 `#e9d8a6`，底色 `#12131a`。
- 首页原先右下角的悬浮「盘解」胶囊已移除：它是 `position:fixed` 且 `bottom:180rpx`，在开发者工具模拟器里没有渲染出来（点击面积随之丢失），导致除首页外的 16 个页面没有任何可见入口。tabBar 接管入口后该元素已删除（wxml 与 wxss 各一处）。
- tabBar 页之间只能用 `wx.switchTab`，且 `switchTab` 不支持在 url 上带 query。为此新增 `utils/nav.js`：
  - `nav.go(path, params)`：非 tab 页走 `wx.navigateTo(url?query)`；tab 页则把参数写进 `app.globalData.tabParams[path]` 再 `wx.switchTab`。
  - `nav.take(path)`：目标页在 `onShow` 取走并删除，保证参数只用一次。
  - `nav.back()`：页面栈长度 > 1 用 `navigateBack`，否则 `switchTab` 回罗盘。
- 已改的调用点：`pages/index`（goAnalysis）、`pages/analysis`（onEntry / goXuankong..goTianji / goCompass / back / 新增 onShow 消费参数）、`pages/zeri`（新增 onShow 消费 sit、back）、`pages/floorplan`（back）、`pages/settings`（back 原为 `navigateBack({delta:1})`，在 tabBar 页上无效，改为 `nav.back()`）、`pages/history`（跳分析页）。
- 校验：Node 下 mock `wx / getApp / getCurrentPages` 跑 14 条断言全部通过（含 heading 180→坐子、heading 90→坐酉、直接传 sit=艮）；开发者工具内验证 tab 切换（择日→盘解）、分析页渲染、分析页→玄空飞星跳转均正常，非 tab 页正确隐藏 tabBar。