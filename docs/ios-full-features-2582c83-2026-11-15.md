# 天机演象 iOS · 未删除卜卦前的最全功能盘点

- **基线提交**：`2582c83` refactor: remove redundant resources and simplify contact and settings pages
- **新分支**：`restore/full-features-2582c83`（已创建并指向 2582c83；当前仍停在 `main`，工作区干净，未检出）
- **为什么是它**：`2582c83` 的下一个提交 `3c8931a chore: snapshot residential AR renovation work` 一次性删除 14 个 iOS 源文件、共 8,706 行，并把 5 Tab 砍成 4 Tab。因此 `2582c83` 就是「罗盘 + 玄空理气（卜卦数术体系）仍完整」的最后状态。

## 一、规模对比

| 指标 | 2582c83（最全） | 当前 main（1a6f319） | 差 |
|---|---|---|---|
| iOS Swift 文件 | 53 | 43 | −10 |
| Swift 代码行 | 54,375 | 32,779 | −21,596 |
| 本地化条目（8 语言合计） | 6,616（≈827 / 语言） | 3,840（≈480 / 语言） | −2,776 |
| 主导航 Tab | 5 | 4（项目 / 测量 / 编辑 / 设置） | −1 |
| 主界面模块 | 罗盘 / AR / 户型 / 玄空理气 / 会员 | 住宅 AR 改造 | 品类都变了 |

> 引擎层（Models）在两版之间基本完整保留：`BaZhaiEngine` `FlyingStarsEngine` `QimenEngine` `PurpleWhiteEngine` `SanHeWaterEngine` `TianJiShuEngine` `Hexagram64` 都还在 HEAD。被删掉的主要是**界面 + 本地化键**，也就是「看得见的部分」。

## 二、五个 Tab 全貌（2582c83）

| # | Tab key | 视图 | 承担功能 |
|---|---|---|---|
| 1 | `tab_compass` | `CompassMainView` | 时空罗盘、24 山 / 64 卦 / 120 分金 / 空亡详勘 |
| 2 | `tab_ar` | `ARVisionView` | 全景形煞 AR、AI 形煞识别、水印存证 |
| 3 | `tab_floorplan` | `FloorplanView` | 户型立极、全屋体检、家庭房间分配 |
| 4 | `tab_analysis` | `XuanKongGridView` | 玄空飞星 / 八宅 / 三合 / 紫白 / 奇门 / 择日 / 天机长卷 |
| 5 | `tab_settings` | `SettingsView` | 四档内购、命卦提醒、语言、校准、关于 |

## 三、Tab 1 时空罗盘（2,253 行）

### 3.1 盘面 `CompassDialView.swift`（649 行）

9 个可独立开关的图层：

| 图层 | 内容 |
|---|---|
| `layer_degree_ticks` | 360° 外圈主刻度 |
| `layer_solar_terms` | 二十四节气 + 十二消息卦环 |
| `layer_hexagrams64` | 六十四卦分金环（含吉度、上下卦、分金详情） |
| `layer_fenjin120` | 一百二十分金环（旺相金 / 孤虚灰） |
| `layer_mountain24` | 二十四山（山名 + 五行两行标签） |
| `layer_eight_gua` | 后天八卦环（坎北离南震东兑西） |
| `layer_true_north` | 真北针 / 磁针双针 |
| `layer_level_bubble` | 电子水准泡 |
| `layer_daily_god_markers` | 日神 / 值神标记 |

4 套盘面预设：综合全息盘 / 三元玄空盘 / 三合水法盘 / 极简勘测盘。

### 3.2 顶栏 `CompassHeaderView.swift`（179 行）

实时度数、坐向（山 + 向）、宫位徽章、分金描述、真太阳时、俯仰 / 横滚双轴倾角、正针纯清判定。

### 3.3 主界面 `CompassMainView.swift`（800 行）

- 锁定朝向、空亡诊断状态 chip、校准、图层、八方全鉴
- 底部结论卡：向首总览（度数 / 山 / 俯仰横滚 / 磁场强度）、分金跨度与断语、64 卦吉度、空亡判级与化解
- 5 个弹层：分金详情 / 空亡详勘 / 八方全鉴 / 图层设置 / 双针校准

## 四、Tab 4 玄空理气（6,285 行，卜卦数术主体）

菜单分 4 组（`analysis_group_house` / `people` / `time` / `report`），共 7 个功能入口 + 长卷报告：

| Feature | 视图 | 引擎 | 能力 | VIP |
|---|---|---|---|---|
| `xuanKong` 玄空飞星 | `XuanKongGridView` | `FlyingStarsEngine` | 三元九运排盘、替卦、兼向联动、年月日时星、优先宫位、财 / 健康 / 化解建议、宅案事实来源标注 | 免费 |
| `baZhai` 八宅明镜 | `BaZhaiView` | `BaZhaiEngine` | 八游年星、宅型 / 门向 / 纳气、吉凶房间建议、命卦人宅配、化解任务 | 免费 |
| `sanHe` 三合水法 | `BaZhaiView` | `SanHeWaterEngine` | 十二长生水法、黄泉水、八煞、小煞、古法歌诀 | **VIP** |
| `owner` 人宅配卦 | `BaZhaiView` | `BaZhaiEngine` | 命卦、东四 / 西四、家庭成员配卦、兼容性、购宅提醒 | **VIP** |
| `dates` 择日 | `BaZhaiView` | `ZeRiEngine` | 建除十二神、每日宜忌、十二时辰吉凶、最近吉日、每日罗盘吉方 | 免费 |
| `purpleWhite` 流年紫白 | `PurpleWhiteView` | `PurpleWhiteEngine` | 流年 / 流月紫白飞星、太岁 / 三煞 / 岁破 | 免费 |
| `qimen` 时家奇门 | `QimenDunjiaView` | `QimenEngine` | 九宫盘（门 / 星 / 神 / 天干地支）、场景评估（出行 / 谈判 / 求医等） | 免费 |
| `report` 天机长卷 | `TianJiShuView` | `TianJiShuEngine` | 宣纸长卷渲染、存相册 / 分享打印、免责声明 | 单次 9.9 元 |

## 五、Tab 2 全景形煞 AR（ARVisionView 2,632 行 + 4 个 AR 子视图）

- **实景取景**：前后摄像头切换、靶心动态测角、二十四山 / 宫位实时解算、LiDAR 测距
- **形煞库** `ExteriorShaEngine`：分类、别名、视觉特征、化解方案、形理危害、传统危害、古籍原文
- **端侧 AI 形煞识别** `OnDeviceShaAnalyzer`：取帧 → 候选 → 结果，含免责声明与歧义提示
- **全景形煞档案** `ShaSurveyModels`：按八宫归集内外煞、等级统计、撤销 / 清空 / 生成报告
- **水印存证**：快照水印（含坐向、时间、坐标）、分享打印
- **三合一化解建议**：择日 / 玄空 / 方位 + 符箓（材质、悬挂、用法）
- **AR 空间测绘** `ARSpatialSurveyView`：平面 / 网格 / 墙面 / 门窗 / 梁、鲁班尺 A / B 点、保存扫描图、导出 DXF（`HouseSpatialSurveyEngine.generateCAD_DXF`）
- **RoomPlan 扫描** `ARRoomPlanCaptureView`：房间语义识别、入户门确认、生成报告
- **3D 壳层查看器** `House3DSpaceViewer`：俯视 / 透视 / 入户视角、房间分类面板、九宫叠加（玄空 / 八宅）、评分
- **VR 手绘测绘** `VRSpatialSurveyView`：加房间 / 门窗、尺寸校验、生成户型

## 六、Tab 3 户型立极（FloorplanView 3,840 行 + 家庭分配 168 行）

- 图纸导入、AI 自动识别房间轮廓（失败 / 撤销 / 重试）
- 中宫重心立极、罗盘半透明叠透、朝向与罗盘同步或手动微调
- 房间增删、类型、宽高缩放、八宫归属、选中房间建议
- 全屋风水体检：火烧天门、鬼门、八宫角标、严重 / 警告 / 吉三级判级，每条含古籍依据与化解方案
- 一键导出全屋堪舆长图
- `FamilyRoomAllocationView`：家庭成员房间分配（VIP）

## 七、Tab 5 会员中心与设置（1,315 行）

四档内购（StoreKit 2）：

| 商品 | ID | 价格 |
|---|---|---|
| 年度会员 | `com.tjyx.compass.vip.yearly` | 198 元 / 年 |
| 大师终身版 | `com.tjyx.compass.pro.lifetime` | 298 元一次性 |
| 户型单套全案 | `com.tjyx.compass.floorplan.case` | 19.9 元 |
| 天机长卷单次导出 | `com.tjyx.compass.tianji.single` | 9.9 元 |

设置项：8 语言切换、命卦提醒（生日 / 立春校准）、家庭成员资料管理、传感器校准状态、地磁干扰、定位权限、真太阳时、触感反馈、恢复购买、法律条款 / 隐私 / 关于 / 备案。

## 八、引擎层（24 个 Model）

| Model | 职责 |
|---|---|
| `Mountain24` | 24 山、八卦、坐向状态、空亡判级 |
| `Hexagram64` | 64 卦、吉度、上下卦、分金详情 |
| `Fenjin120Data` | 120 分金与断语 |
| `SolarTermsData` | 24 节气、消息卦对应 |
| `SolarTimeCalculator` | 真太阳时、日柱、节气进度 |
| `WorldMagneticModel` | 地磁偏角、场强 |
| `CompassLayerManager` | 图层开关与预设 |
| `BaZhaiEngine` | 八宅游年、命卦、家庭成员、化解任务、日签、节气通知 |
| `FlyingStarsEngine` | 玄空飞星排盘、替卦、宫位建议 |
| `SanHeWaterEngine` | 三合长生水法、黄泉水、八煞 |
| `PurpleWhiteEngine` | 紫白飞星年月盘 |
| `QimenEngine` | 时家奇门排盘与场景评估 |
| `ZeRiEngine` | 建除十二神、宜忌、时辰吉凶、吉日 |
| `TianJiShuEngine` | 天机长卷渲染与存图 |
| `ExteriorShaEngine` | 室外形煞库 |
| `OnDeviceShaAnalyzer` | 端侧视觉形煞识别 |
| `ShaSurveyModels` | 形煞档案、宫位归集 |
| `HouseSpatialSurveyModel` | LiDAR 房间模型、DXF 导出 |
| `FloorplanEngine` | 房间模型、户型体检 |
| `FamilyRoomAllocation` | 家庭房间分配 |
| `GeometryUtils` | 户型映射几何 |
| `TraditionalEvidence` | 典籍引证 |
| `WidgetAlmanacSnapshot` | 小组件快照与择日自检 |
| `LocalizationManager` | 8 语言 6,616 条文案 |

## 九、小组件与测试

- `TiandiLuopanWidget/AlmanacWidgetViews.swift`、`TiandiLuopanAlmanacWidget.swift`：日柱、值神、节气环、动土 / 开门自检
- `TiandiLuopanTests/FunctionalRegressionTests.swift`：回归测试
- 工程 3 个 target：`TiandiLuopan` / `TiandiLuopanWidget` / `TiandiLuopanTests`

## 十、3c8931a 删除清单（恢复目标，共 8,706 行）

| 文件 | 行数 | 模块 |
|---|---|---|
| `Views/Analysis/BaZhaiView.swift` | 3,156 | 八宅 / 三合 / 择日 / 人宅配 |
| `Views/Analysis/XuanKongGridView.swift` | 1,532 | 玄空理气主页与菜单 |
| `Views/Analysis/TianJiShuView.swift` | 561 | 天机长卷 |
| `Views/Analysis/PurpleWhiteView.swift` | 544 | 流年紫白 |
| `Views/Analysis/QimenDunjiaView.swift` | 492 | 时家奇门 |
| `Views/Compass/CompassMainView.swift` | 800 | 罗盘主页 |
| `Views/Compass/CompassDialView.swift` | 649 | 罗盘盘面 |
| `Views/Compass/CalibrationSheet.swift` | 247 | 双针校准 |
| `Views/Compass/CompassHeaderView.swift` | 179 | 顶栏仪表 |
| `Views/Compass/KongWangDetailSheet.swift` | 113 | 空亡详勘 |
| `Views/Compass/FengshuiPalaceDetailSheet.swift` | 97 | 八方全鉴 |
| `Views/Compass/FenjinDetailSheet.swift` | 92 | 分金详情 |
| `Views/Compass/LayerSettingsSheet.swift` | 76 | 图层设置 |
| `Views/Floorplan/FamilyRoomAllocationView.swift` | 168 | 家庭房间分配 |

另有 3 处**非删除性削减**，恢复时必须一起补：

1. `Views/RootContentView.swift`：5 Tab → 4 Tab（2582c83 为 967 行，HEAD 735 行）
2. `Models/LocalizationManager.swift`：6,616 条 → 3,840 条（少 2,776 条；`tab_analysis`、`xk_*`、`bz_*`、`qimen_*`、`layer_*` 等键在 HEAD 已不存在）
3. `TiandiLuopan.xcodeproj/project.pbxproj`：需重新登记 14 个文件

## 十一、两条恢复路线

**路线 A：整分支回到全量（推荐先做）**

```bash
git switch restore/full-features-2582c83
```

- 优点：一次到位，5 Tab 完整可编译，罗盘 / 玄空 / 户型 / AR 全在，8 语言 827 键/语言齐全。
- 代价：回到 11 月 10 日状态，之后 main 上的住宅改造（`ResidentialPlanning` `ResidentialWorkspace`、场景预设 1a6f319、地块标记 c703794）与本轮的 iPad / Duo 适配修复都不在这个分支。

**路线 B：只把模块搬回 main**

```bash
git checkout 2582c83 -- <14 个文件路径>
```

再补三处：RootContentView 的 5 Tab、LocalizationManager 的 2,776 条键、pbxproj 登记。

- 风险点：HEAD 的 `FloorplanView`（277 行）、`SettingsView`（62 行）、`ARVisionView`（509 行）已被住宅改造精简，**不能**用 2582c83 版本（3,840 / 1,315 / 2,632 行）直接覆盖，否则会把住宅 AR 新功能顶掉。只能新增 `Views/Compass`、`Views/Analysis` 两个目录后接回 5 Tab。
- LocalizationManager 也不能整文件覆盖：HEAD 新增了 `res_*` 住宅键，需做键差集合并，而不是替换。

**建议顺序**：先 A 跑通全量包（验证 53 文件 / 5 Tab / 8 语言），再把 HEAD 的住宅 AR 新特性与 iPad·Duo 适配按文件移植到 `restore/full-features-2582c83`。

## 十二、一句话结论

最全最丰富的状态就在 `2582c83`：**5 Tab、53 个 Swift 文件、54,375 行、24 个术数引擎、8 语言 6,616 条文案、4 档内购、3 个 target**；被 `3c8931a` 砍掉的是 14 个界面文件（8,706 行）与 2,776 条文案，引擎本体并未丢失。

---

生成时间：2026-11-15 · 依据 `git show` / `git ls-tree` 实测，非估计