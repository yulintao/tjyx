# 迁移完成度审计（iOS full-features → 微信小程序）

审计时间：2026-11-16　对象：`full-features` 分支 `TiandiLuopan` 与 `tiandi_luopan_mini_program`

## 结论

**没有全部迁移。** 理气六门（玄空、八宅、紫白、三合、择日、奇门）都能出盘并给出断语，但断语库深度、档案与持久化、AR/空间测绘、设置与多语言、长卷精绘均存在明显缺口。

代码量对比：iOS Models 1,972 KB + Views 1,270 KB ≈ 3.2 MB Swift；小程序 utils 126 KB + pages 156 KB ≈ 282 KB。小程序约为 iOS 的 9%（Swift 含 721 KB 多语言文案与大量 AR/空间测绘 UI，不能直接按比例折算能力，但差距量级可见）。

功能点覆盖估算：整体约 78–86%，理气计算约 85–92%，系统与外围能力约 80%（多语种按产品决定不做，不计入缺口）。分享海报与浏览历史已补，剩余缺口集中在收藏夹、户型拖拽/专项体检、卦辞爻辞全文与 AR 真机验证。

### 2026-11-16 本轮补齐（已过 Node 校验）

| 新增 | 文件 | 校验结果 |
|---|---|---|
| 本地持久化 | `utils/store.js` | 版本化读写，`__v` 不符回退默认；17 个导出函数；非小程序环境有空实现，可 Node 直跑 |
| 120 分金 | `utils/fenjin.js` | 120 条、珠宝 48 条、纳音逐条正确（0° 落子山丙寅·炉中火·珠宝） |
| 六十四卦 | `utils/hexagram.js` | 64 卦、二进制首末为 111111/000000；180° 落风天小畜，抽初爻变巽为风，互火泽睽、错雷地豫、综天泽履 |
| 外煞库 | `utils/sha.js` | 23 类、极凶 5 类；`audit()` 返回命中/评分/汇总结论 |
| 择日补强 | `utils/zeri.js` | 十二值神黄黑道按青龙起例 `((日支%6)*2+8)%12` 推算，每日 6 黄道时稳定复现；月破与七类事项判宜忌 |
| 奇门用神 | `utils/qimen.js` | 8 场景落宫、评分、建议均出结果；年命落宫按年干定位 |

## 逐项状态

| # | iOS 能力 | iOS 依据 | 小程序 | 状态 | 具体缺口 |
|---|---|---|---|---|---|
| 1 | 主罗盘：24 山、天心十道、双轴水准、磁偏角、真北换算 | `CompassMainView` 37KB、`CompassDialView` 28.7KB | `pages/index` | 部分（约 80%） | 无 64 卦抽爻换象与卦辞、无八字式传感器校准流程、无拍照水印存证、无历史记录 |
| 2 | 120 分金 | `Fenjin120Data` 26KB | `pages/fenjin` + `utils/fenjin.js` | 基本可用（约 85%） | 120 位全表、六十甲子纳音、逐条断语、二十四山吉度均已补；仅「逐度 360 细断」与兼向合分金未做 |
| 3 | 空亡详勘（大小空亡、出卦） | `KongWangDetailSheet` | 罗盘页弹层 | 基本可用 | 缺逐度吉凶解释与化解建议 |
| 4 | 八宫宜忌与化解锦囊 | `FengshuiPalaceDetailSheet`、`fengshui-palace.js` | 罗盘页弹层 | 可用 | 与 iOS 文案深度不完全一致 |
| 5 | AR 实景叠加、形煞标注、靶心测角、前后镜头、水印快照 | `ARVisionView` 128.8KB、`ExteriorShaEngine` 106.5KB、`OnDeviceShaAnalyzer` 28.4KB | `pages/ar`（降级版） | 部分（约 30%） | 已实现相机取景 + 靶心测角 + 二十四山盘面叠印 + 水平气泡 + 水印存证；**无深度遮挡、无世界锚点、无自动形煞识别**（`sceneDepth`/`ARMesh`/`raycast` 无对应能力） |
| 6 | RoomPlan 扫描、3D 房屋浏览、VR 空间测绘 | `ARRoomPlanCaptureView` 76.3KB、`House3DSpaceViewer` 90.3KB、`VRSpatialSurveyView` 39.6KB、`HouseSpatialSurveyModel` 210.5KB | `pages/floorplan` 3D 视图 | 采集端不可移植；浏览端降级替代 | `RoomCaptureSession`(13)/`CapturedRoom`(35)、`SCNScene`(7)/`SCNNode`(38)、`sceneDepth`(13)/`ARMesh`(13)/`raycast`(26) 均无对应；3D 浏览改为 Canvas 等轴测体块；`HouseSpatialSurveyModel` 几何层（重心/覆盖率/面积/投影）已迁入 `utils/floorplan.js` |
| 7 | 户型：手绘/导入、中宫立极、罗盘叠透、火烧天门/鬼门体检、面积、存档 | `FloorplanView` 196KB、`FloorplanEngine` 127KB | `pages/floorplan` | 部分（约 75%） | 已补：增删房间、改用途、宽深微调、底图导入描摹、面积加权重心（中宫立极）、九宫覆盖率（量化缺角）、宅宽→㎡换算、3D 体块、户型存档/载入/删除；仍缺：拖拽缩放、罗盘叠透、火烧天门/鬼门专项体检 |
| 8 | 玄空飞星：三元九运、下卦/替卦、山向飞星、81 组合、旺山旺向 | `FlyingStarsEngine` 90KB、`XuanKongGridView` 74KB | `pages/xuankong` | 部分（约 60%） | 81 断语经 Node 复核为 **81 条完整**（此前审计写「约 60 条」有误，已更正）；仍缺：页面自动识别兼向起替卦、流年月星叠加、实用化解动作清单、古籍出处（`TraditionalEvidence`） |
| 9 | 八宅：命卦、大游年、宅命合配、家人配房、化解任务勾选 | `BaZhaiEngine` 159.6KB、`FamilyRoomAllocation` | `pages/bazhai` + `utils/bazhai.js` | 部分（约 88%） | 已补：家人档案增删改与持久化、生肖换算、四凶星（五鬼/六煞/祸害/绝命）化解任务清单与勾选存档；仍缺：纳音与逐宫断语全库、宅命合配细分等级 |
| 10 | 三合水法：八路黄泉、八煞、四大局十二长生、纳水 | `SanHeWaterEngine` 71.9KB | `pages/sanhe` | 部分（约 55%） | 无分房分位细断、无兼向水法、无古籍依据、无形峦配合 |
| 11 | 紫白：年/月紫白、五黄二黑、太岁岁破三煞 | `PurpleWhiteEngine` 47.1KB、`PurpleWhiteView` 28.2KB | `pages/zibai` | 部分（约 65%） | 无日紫白/时紫白、无组合断语库、无逐宫化解 |
| 12 | 择日：建除、日课、神煞、时辰吉凶、逐事项择吉 | `ZeRiEngine` 46.1KB | `pages/zeri` + `utils/zeri.js` | 部分（约 70%） | 已补十二值神黄黑道（青龙起例与六黄道判定）、月破、七类事项择日（动土/嫁娶/开市/入学/安葬/出行/入宅）；仍缺天德月德贵人等吉神、四废/杨公忌、逐事项吉时精配 |
| 13 | 奇门：定局、值符值使、九星八门八神、场景评估 | `QimenEngine` 57.4KB、`QimenDunjiaView` 22.6KB | `pages/qimen` + `utils/qimen.js` | 部分（约 65%） | 已补八类场景用神（求财/事业/婚姻/疾病/考试/出行/诉讼/谈判）、落宫评分与建议、年命落宫；仍缺旺衰月令、格局断语（十干克应）、古籍出处 |
| 14 | 天机数深度分析、行动建议、精绘长卷 | `TianJiShuEngine` 87.2KB、`TianJiShuView` 28.8KB | `pages/tianji` | 部分（约 35%） | 只有 8 章摘要 + 简单 Canvas 长图；无 `deepAnalysis`/`guidanceText`、无字体印章排版、无原生级绘制 |
| 15 | 六十四卦 | `Hexagram64` 48.7KB | `pages/gua64` + `utils/hexagram.js` | 部分（约 50%） | 64 卦名矩阵、上下卦、二进制、5.625° 分度、384 爻抽爻换象、之卦/互卦/错卦/综卦已补；仍缺卦辞爻辞全文、纳甲六亲、京房八宫世应 |
| 16 | 外部形煞 / 峦头 | `ExteriorShaEngine` 106.5KB | `pages/sha` + `utils/sha.js` | 部分（约 40%） | 23 类形煞（辨识/影响/化解/四档严重度）与自查评分已补；仍缺 AR 实景自动识别、按方位落宫定轻重、图片标注 |
| 17 | 设置中心：语言、单位、通知、隐私、关于、恢复购买、清空档案 | `SettingsView` 70.7KB | `pages/settings` | 部分（约 45%） | 语言选择（简/繁占位）、单位、提醒、古籍出处开关、清空历史/全部、关于已做；恢复购买与多语种文案未做 |
| 18 | 会员与内购（VIP/永久/单次） | `VIPPaywallSheet`、`StoreKitIAPManager` | 无 | 不可移植 | 微信禁止 iOS 端小程序虚拟支付 |
| 19 | 8 语种本地化 | `LocalizationManager` 721.5KB | 不迁移 | **按产品决定仅简体中文** | 用户明确「语言仅需支持简体中文」，设置页语言项固定显示简体中文，不再保留 i18n 框架与切换位 |
| 20 | Widget 黄历快照 | `WidgetAlmanacSnapshot` 24.1KB | 无 | 不可移植 | 小程序无桌面 Widget |
| 21 | 本地档案持久化（成员、户型、历史、任务） | `BaZhaiEngine` 存档、`Floorplan` 存档 | `utils/store.js` | 部分（约 85%） | 设置页、八宅档案/化解任务、户型存档均已接入；历史记录仅接口就绪、页面未接 |
| 22 | 分享/收藏/历史 | iOS 分享与收藏逻辑 | `pages/poster`、`pages/history`、`utils/store` | 部分（约 75%） | 已补：Canvas 海报（盘面/坐向/分金/元运/格局 + 落款，可存相册、`open-type=share` 分享）；浏览历史自动留痕（盘解/玄空/择日/海报，10 分钟同标题去重、最多 30 条、可单删/清空）；仍未做：收藏夹 |

## 可执行优先级

P0（不补就不好用）
1. 本地持久化：成员档案、户型、化解任务、历史记录（`wx.setStorageSync` + 版本迁移）。
2. 玄空 81 断语补齐 + 分金 120 逐条断语 + 八宅逐宫断语。
3. 兼向自动识别：罗盘兼向度数直接驱动玄空替卦。

P1（补齐专业度）
1. 择日神煞体系与按事项择吉。
2. 奇门用神落宫、旺衰、场景评估。
3. 六十四卦抽爻换象 + 卦爻辞。
4. 玄空/择日古籍出处引用（对应 `TraditionalEvidence`）。

P2（体验与外围）
1. 户型：增删房间、拖拽、图片导入、中宫立极、罗盘叠透、面积。
2. 长卷精绘：字体、印章、落款、分享海报。
3. 设置页 + 多语言框架。
4. AR 替代方案：camera 实景 + 盘面叠加 + 靶心测角 + Canvas 水印快照（技术可行，需真机验证）。

---

## 2026-11-17 续查与更正

本文件的部分条目经 11-17 复核后已修正，**以后续文件为准**：[`GAP_AUDIT_2026-11-17.md`](./GAP_AUDIT_2026-11-17.md)

更正点（原表述 → 复核结果）：

1. 「六十四卦缺卦辞爻辞全文」→ iOS `Hexagram64.swift` 本身无卦辞爻辞库（仅引《泰卦》一句），小程序不算漏迁，且多出抽爻换象/互/错/综。
2. 「紫白无日/时紫白」「三合无分房分位」「奇门缺十干克应」「八宅缺纳音」→ iOS 同样没有，属于新需求而非未迁。
3. 「收藏夹未做」→ iOS 无收藏功能。
4. 「历史记录仅接口就绪、页面未接」→ 实为已接（列表/单删/清空/跳转均可用）。
5. 外煞「23 类」→ 小程序条目数**多于** iOS（iOS 8 类），但每类文案深度不及 iOS。

新增缺口（原文件未列）：今日财神/喜神方位与吉方导引、今日吉方日签海报、罗盘手动选山与锁定角微调、图层「度数刻度/真北针/财神喜神金标」三开关与「三合水法盘」预设、玄空替卦入口与三般卦/七星打劫/流年月星、择日冲主人本命、户型缺角长断语与 DXF/宅谱 JSON、设置页隐私协议与新手引导、节气与换月提醒（`showEvidence`/`notify` 目前是死开关）。

---

## 2026-11-17 实施与回填（收尾）

上一段列出的「新增缺口」已于同日晚间全部实施完毕，逐项实现与校验见 `GAP_AUDIT_2026-11-17.md` 第九节。摘要：

- 择日：`dailyCompassDirections`（财神/喜神）、`GOD_OFFICER_INFO`（12 值神黄黑道）、`ownerBranch` 冲本命、`chongSha` 日冲；页面加吉方卡、日冲提示、时辰点选详情。
- 玄空：`diagnoseHeading` 三级坐向诊断、`isTiGua` 替卦入口、`checkSanBanGua`/`checkQiXingDaJie`、`withFlow` 流年月叠加、每格 `action` 化解。
- 断语库：三合原诀+12 长生、紫白 9 星做法+组合+逐宫化解、八宅 8 星逐宫 lore、外煞 23 类四段出处、奇门八门断语+最利方位指南。
- 罗盘：图层 8→11 键（+度数刻度/真北针/财神喜神金标）、三合水法盘预设、盘面金标、吉方导引条、手动选山选向与锁定角微调（`settings.compassLock` 持久化）。
- 新页面：`pages/dailycard`（今日日签）、`pages/legal`（协议/隐私/合规）、`pages/family`（家庭资料）、`pages/guide`（新手引导，首启动自动弹）。
- 户型：缺角九宫断语（带出典）、中宫立极点拖拽、罗盘叠透、宅谱 JSON 导入导出、DXF（R12 ASCII）导出。
- 天机长卷：7 章 → 13 章，加 `deepAnalysis` 评分/处置清单与 `guidanceText` 总纲；导出图加宣纸底纹、朱丝栏、「演象」朱印。
- 回归：新增 `scripts/regression.js`，覆盖 8 组共 24 项断言，当前全通过。

仍未落地且已明确记录：定时推送提醒（需订阅消息模板 + 云函数下发，纯本地不可行）、多语种（产品决策仅简体）、以及 RoomPlan/LiDAR/StoreKit/Widget/iCloud KVS 等平台无对应能力项。

复跑：`node scripts\regression.js`

---

## 2026-11-17 第四轮补迁（继续迁移 · 第三次）

按「Swift 文件 → func 名单 → 页面交互」三层重扫后，补齐此前判定为「部分迁移」或「零星散落」的五处能力，全部为纯算法/纯 UI 可移植项：

- 日课外围：`utils/solar-terms.js` 增 `solarTermProgress(date)`（相邻节气时刻二分定位，进度/倒计时/下一节气名）；`utils/zeri.js` 增 `dayCourseAudit(date, sit, opts)`，输出岁破 / 月破 / 冲山 三自检、`canGroundbreak` / `canInstallDoor` 与「宜修造动土 / 忌动土起造」「宜安门立向 / 忌安门修方」徽章，以及 `overallStatus` / `isAuspicious` / `detailsText`。择日页加「日课自检」卡（含节气进度条），罗盘页加节气条并可带坐山跳转。
- 家人配房：新建 `utils/roomfit.js`，完整对齐 `FamilyRoomAllocationEngine`（`useOf` / `isAssignable` / `palaceOfRoom` / `centralRoomId` / `fit` / `recommend` / `cleaned` / `toggling` / `labels` / `reviewPairs` / `reviewRoomIDs` / `unassignedBedroom` / `peopleOf` / `resolve`），rank 表与 iOS 同值；户型页加「家人配房」卡（逐人卧房+书房、`⚠︎` 复核行、未配卧房提示）。
- 化解清单：新建 `pages/remedy`，汇总玄空逐宫凶星、流年紫白凶宫、八宅命卦凶方三类化解动作，带应期说明与「已办/总数/百分比」，勾选落 `store.toggleRemedyTask`。
- 分享：18 个内容页补齐 `onShareTimeline`（此前仅 2 处），与 `onShareAppMessage` 并存；设置/合规/家庭/引导页有意不分享。
- 长卷排版：导出的章头改为「章号小字 + 朱红标题 + 双线」，卷尾补页码与「共 N 章」，免责声明与 iOS 同义；章节行高 56→62。

回归：`scripts/regression.js` 由 8 组 24 项扩到 **10 组 32 项**（新增日课自检 3 项、家人配房 5 项），全部通过；`check-handlers.js` 覆盖 22 个页面，全部已定义；全项目 50 个 `.js` 静态检查零失败。

仍未落地（不变）：定时推送（订阅消息 + 云函数）、7 语种（产品决策仅简体）、RoomPlan/LiDAR/ARWorldMap/StoreKit/Widget/iCloud KVS/端侧视觉识别（平台无能力）。

---

## 2026-11-17 第五轮：平台能力项全部改等价实现（继续迁移 · 第四次）

前四轮把「纯算法」与「纯 UI」补齐后，剩下的都是 iOS 系统框架能力。本轮按用户指令（仅简体、未迁项全迁）把它们逐条换成小程序能跑的实现或可部署的落地路径。

**新增文件**

| 文件 | 作用 | 对应 iOS |
|---|---|---|
| `utils/reminders.js` | 提醒引擎：换月（偶数索引节气）、岁破/月破/冲山、建除吉日、`toText`、`lockedSit` | `setSolarTermNotifications` / `toggleAuspiciousDayReminder` / `refreshScheduledReminders` |
| `pages/notify/*` | 提醒中心：今日/未来 N 天卡、四类开关、模板 ID 输入、订阅授权、复制、桌面快捷方式说明、云端队列同步 | 同上 + Widget 入口 |
| `utils/backup.js` | collect / serialize / parse / summaryOf / apply(merge\|replace) / cloud* | `NSUbiquitousKeyValueStore`（iCloud KVS） |
| `pages/backup/*` | 三套导入（剪贴板/聊天文件/云开发）+ 导出（剪贴板/JSON 文件）+ 合并与覆盖 | 同上 |
| `pages/vip/*` | 8 条权益逐条「iOS 口径 vs 本版」，声明全开放，附备份/化解入口与清数据前备份 | `StoreKitIAPManager` / `VIPPaywallSheet` / `sanHeVIPPreviewCard` |
| `utils/luban.js` | 门光尺 42.9cm 八格 + 丁兰尺 39.0cm 十格，`nearestAuspicious` | `LubanRulerEvaluation`（原在 AR 文件内，实际不依赖 AR） |
| `pages/luban/*` | 实测厘米输入、6 个常用门宽一键、双尺刻度表、最近吉度、复制结论 | AR 打点测量后的鲁班评定 |
| `cloudfunctions/almanac-notify/{index.js,config.json,package.json}` | 定时（每日 8:00）扫描 `luopan_notify_plan`，`subscribeMessage.send` 后置 `sent:true` | 后台推送（原系统通知的落地替代） |

**改动文件**

- `utils/floorplan.js`：+`TEMPLATES` 四套 / `templateRooms` / `templateList`；`isoBlocks(rooms,{rotDeg})` 绕中心旋转 + 返回 `faces`（四周墙按深度排序）。
- `pages/floorplan`：data +`templates/tmplIdx/isoRot/isoZoom`；方法 +`onTemplate/onIsoTouchStart/onIsoTouchMove/onIsoTouchEnd/resetIso`；`drawIso` 改为遍历 `faces`、以画布中心为基准 `fitScale*zoom`；wxml 加模板 `picker`、canvas 手势绑定、复位按钮、脚注改写。
- `utils/sha.js`：23 → 35 类，补 12 类室内形煞（横梁压顶、房门冲床、水火未济、开门见灶、开门见厕、床头悬空、暗室无窗、吉位落水、户型狭长、五黄到门、二黑临卧、卧房得位）。
- `pages/sha`：+`onCapture/saveEvidence/clearEvidence` 与 `evidencePath`，按钮与口径说明。
- `pages/settings`：+「提醒与数据」卡（`goNotify/goBackup/goVip/goRemedy`），并修掉上一轮 `</view>` 误粘在「重播新手引导」行尾的排版问题。
- `pages/analysis`：入口 18 → 22（提醒中心 / 备份与恢复 / 功能权益 / 鲁班门光尺）。
- `app.json`：22 → 26 页（+`notify`/`backup`/`vip`/`luban`）。
- `project.config.json`：+`"cloudfunctionRoot": "cloudfunctions/"`。
- `scripts/regression.js`：10 组 32 项 → **14 组 42 项**（提醒 4 项、备份 2 项、模板/3D 2 项、鲁班与室内形煞 2 项），并把外煞断言改为 35 类。
- `README.md`：目录树补 `reminders.js`/`backup.js`/`luban.js`/`cloudfunctions/`/`pages notify|backup|vip|luban`，analysis 22 模块，外煞 35 类，回归 14 组 42 项。

**校验**

```
node scripts\regression.js      # 42 项全通过
node scripts\check-handlers.js  # 26 页绑定全部已定义
node --check（56 个 .js，跳过 node_modules）  # 零失败
wxml <view> 开闭：sha 23/23、backup 52/52、vip 25/25、notify 48/48、floorplan 101/101、settings 43/43、luban 30/30
```

**已定口径**

- 语言：仅 `zh-Hans`，其余 6 语种不再迁（用户指令）。
- 付费墙：不做，功能全开放；已建权益对照页，是否接微信支付待用户表态。
- 提醒：模板 ID 与云开发环境由用户自填/自开；未配置时页内卡、复制、备份导出仍可用。
- 平台硬限制无替代者：RealityKit 真实 3D 渲染、RoomPlan/LiDAR 扫描、ARWorldMap、StoreKit 内购与评价入口、WidgetKit、iCloud KVS 实时同步、端侧视觉识别、系统通知/快捷指令/Spotlight。等价实现见 `GAP_AUDIT_2026-11-17.md` 第十一节。

---

## 2026-11-17 第六轮：空间测绘参数与报告长图（收尾）

复盘 `HouseSpatialSurveyModel.swift` 时发现两处只依赖几何/Canvas、与 ARKit 无关的内容仍未搬：尺寸与得分口径（`analyzeSpatialHouse`）与报告长图（`SurveyReportRenderer`）。本轮补齐：

| 新增/改动 | 内容 |
|---|---|
| `utils/floorplan.js` +`surveyMetrics(plan, chart)` | 面宽/进深（包围盒 × 宅宽换算）、套内净面积、建筑估算面积（`max(套内×1.22, 面宽×进深)`，iOS 同式）、进深面宽比、九宫满宫/缺角/气偏统计、凶宫房间、空间得分（基准 92，按缺角/中宫/狭长/凶宫/完整度扣分，夹 0–100）；净层高、墙体段数、门窗开孔置 `null` 并标「未采集」 |
| `utils/reportcard.js` | `build` / `draw` / `toText`：墨底金线、得分条、五段参数、缺角断语（含化解与出典）、凶宫化解、评分口径与免责、朱印「演象」；画布高度随条目增长 |
| `pages/report/*` | 报告页：读户型草稿 → 最近存档 → 示例户型，Canvas 出图，存相册/预览/分享/复制全文/回户型 |
| 入口 | 户型页「生成空间测绘报告图」；盘解页第 23 个模块 |
| 回归 | 15 组 45 项（新增测绘参数、得分、长图 3 项）；`check-handlers` 27 页全通过；`node --check` 零失败 |

口径：小程序无 LiDAR，**可测项照算、不可测项标「未采集」不计分**，不把缺失读数当已有值。至此 `full-features` 中所有不依赖 RoomPlan/LiDAR/ARWorldMap/RealityKit/StoreKit/Widget/iCloud 实时同步/端侧识别的实体能力，均已在 `tiandi_luopan_mini_program` 有对应实现；其余为平台无对应能力或产品决策不做（多语种）。

---

## 2026-11-17 导航修复：菜单进入后无法返回

用户反馈「点进某一个菜单以后，无法返回」。逐页排查后确认三个独立原因，均已修：

| 原因 | 证据 | 修复 |
|---|---|---|
| ① 返回箭头被安全区吃掉（25 个业务页） | `app.wxss` 中 `.topbar { height: 96rpx; padding-top: env(safe-area-inset-top) }`，而全局 `view { box-sizing: border-box }`；刘海机型安全区 ≈44–47px 恰等于 96rpx（48px），内容盒被压到约 1px —— 箭头画得出来，可点区域只剩 1px | 安全区改由 `.screen` 承担（`20px → constant() → env() → max(20px, env())` 四段降级），`.topbar` 回归固定 88rpx；`.topbar-back` 热区放大到 88×88rpx 并负边距贴边，`min-width` 兼容「跳过」这类文字按钮 |
| ② 实景叠盘页相机界面没有返回控件 | `pages/ar/index.wxml` 的 `camera` HUD 内只有读数与拍照/校北/清校，`返回` 只存在于拍完照后的 `snap-overlay` | HUD 增加 `← 返回`（`cover-view`，`bindtap="back"`）；`onLoad` 读 `getWindowInfo().statusBarHeight`，顶部返回与读数按实际状态栏高度下移，避免被刘海压住 |
| ③ tabBar 页之间 `switchTab` 没有页面栈，返回只会掉回罗盘 | `utils/nav.js` 的 `back()` 在栈底固定 `switchTab('/pages/index/index')`；从盘解点「户型九宫 / 择日 / 设置」后回来，落点不是盘解 | `nav.go()` 记录来源 tab（`globalData.tabFrom`），`nav.back()` 在栈底优先回来源 tab、消费后清除；无来源才回罗盘 |

校验：`node scripts\regression.js` → **16 组 46 项全通过**（新增「tab 页栈底回到来源 tab / 无来源回罗盘 / 有栈走 navigateBack」断言）；`check-handlers.js` 27 页全通过；全项目 `node --check` 零失败；`pages/ar` 与 `pages/report` 的 `view`+`cover-view` 开闭各 20/20、35/35 一致。

---

## 2026-11-17 移除隐私说明

按产品要求下线「隐私说明」，不再以任何入口展示该文档：

| 位置 | 改动 |
|---|---|
| `utils/legal-text.js` | 删除 `PRIVACY_TITLE` / `PRIVACY_BODY` / `DOCS.privacy` 及其导出；头部注释改为「用户服务协议 / 合规与安全说明」 |
| `pages/legal/index.js` | `KEYS` 由 `terms/privacy/compliance` 收为 `terms/compliance`，标签页从三枚减为两枚 |
| `pages/settings/index.wxml` | 删除「隐私说明」按钮，保留「用户服务协议」「合规与安全说明」 |
| `pages/settings/index.js` | 删除 `goPrivacy` 处理器 |
| 合规正文 | 去掉对已下线文档的交叉引用（「使用前请阅读用户服务协议与合规与安全说明」） |

校验：`regression.js` → **17 组 47 项全通过**（合规文本组断言改为「协议与合规两份齐备」，并新增「隐私说明已移除」反向断言：`DOCS.privacy` 不存在、`PRIVACY_TITLE`/`PRIVACY_BODY` 不再导出）；`check-handlers.js` 27 页全通过；`check-components.js` 通过；三个改动文件 `node --check` 零失败。

---

## 2026-11-17 房间可拖动（户型页）

用户反馈「房间无法移动」。排查确认这是**能力缺失而非 bug**：`pages/floorplan` 的房间只有点选菜单里的「改用途 / 宽 ±5 / 深 ±5 / 删除」，`x`、`y` 从建模板起就没有任何写入口，房间只能挤在模板给定位置。

实现：

| 层 | 改动 |
|---|---|
| `utils/floorplan.js` | 新增 `moveRoom(room, x, y)`：把左上角落到目标坐标并按 `100-w / 100-h` 夹取，只改位置不改尺寸/用途，返回新对象（不污染数据源）；已加入 `module.exports` |
| `pages/floorplan/index.wxml` | 房间视图补 `catchtouchstart/catchtouchmove/catchtouchend/catchtouchcancel`，`catch` 既拦住页面滚动，也避免与「拖动中宫立极」抢手势 |
| `pages/floorplan/index.js` | 新增 `onRoomTouchStart/Move/End`：8px 内视为点按（不启动拖动），越过后按户型框实时换算百分比并只 `setData` 这一间的 `style`（不整盘重算，保证跟手）；松手才写入 `_rooms` 并 `recompute()`，九宫缺角、凶吉、配房、3D 体块同步刷新 |
| 交互细节 | 拖动结束用 `_dragEndAt` 时间戳吃掉随后派发的 tap（300ms 内），避免「拖完就弹出改用途菜单」；每次按下重新量 `#planBox`，兼容页面滚动与横竖屏切换 |
| 页面文案 | 户型卡脚注改为「按住房间可直接拖动改位置…点按房间可改用途、调宽深或删除」 |

校验：`regression.js` → **17 组 48 项全通过**（新增第十二组断言：`moveRoom` 夹取左上/右下边界、尺寸与名称不变、不修改入参对象）；`check-handlers.js` 27 页全通过（三个新处理器均已定义）；`check-components.js` 通过；`utils/floorplan.js`、`pages/floorplan/index.js`、`scripts/regression.js` 的 `node --check` 零失败。

---

## 2026-11-17 从「只展示」改为「可操作」（页面交互补齐）

用户反馈「iOS 能力没 100% 复刻，很多功能仅提供展示、没有互动」。先做了一次逐页量化：统计每页的输入控件数、手势绑定数、事件处理器数，以及其中真正改状态（`setData` / 重算 / 落盘）的处理器数。结果最薄的是分金、六十四卦、三合、紫白、鲁班尺这几页——它们把算法结果整块铺出来，用户只能滑动或换下拉，不能参与推演。

本轮按「同一套算法 + 可操作入口」补了五页：

| 页面 | 之前 | 现在可操作的部分 |
|---|---|---|
| 三合水法 | 只有坐山下拉，十二长生表只读 | 新增「水口合参」：来水、去水各一个下拉，实时判吉/平/凶并给改口建议（`utils/sanhe.js` 新增 `judgeWater`）；点十二长生任一字可直接设为来水或去水，该行高亮 |
| 六十四卦 | 只有角度滑杆，卦象只读 | 六爻可点：点某爻即成动爻（阴阳翻转、生成之卦），再点取消；上卦/下卦双下拉手动起卦；点卦图任一卦跳到该卦角度；爻线用实体线段绘制（阳一整条、阴两段），动爻行高亮 |
| 一百二十分金 | 滑杆 + 只读列表 | 点「本山五位分金」任一行直接跳到该位中心；点「二十四山吉度」任一行跳到该山首个吉度（无吉度则取山中心）；结果卡随之更新 |
| 鲁班门光尺 | 输入框 + 快捷尺寸 | 加 0–300cm 滑杆实时判定；「改取最近吉度」一键把实测值改成最近吉格；八格/十格表按当前尺寸高亮，并标出「← 当前」 |
| 外煞自查 | 勾选只活在本次会话 | 勾选结果落本机（`yj_sha_check`），再进页面自动带回并显示上次保存时间；清空同步落盘 |
| 紫白九星 | 只能改日期 | 新增「上月 / 下月」推移与「回到当前月」，按节气月重排九宫；点宫看断语沿用原有 `picked` |

新增算法断言：`judgeWater` 合局判吉 / 破局给改口建议；`changeYao` 同一爻再变回落本卦（六爻全覆盖）。回归从 48 项增至 **50 项**。

仍属「输出页 / 文本页」而非互动缺失：`report`（测绘报告出图、存相册、分享）、`poster`（海报出图）、`vip`（权益说明）、`legal`（协议正文）、`guide`（引导）。这些页面本身以生成或阅读为终点，不安排额外操作入口。

校验：`regression.js` 17 组 **50 项全通过**；`check-handlers.js` 27 页全通过（新增 `onLaiChange`/`onQuChange`/`onRowSet`/`onYaoTap`/`onUpperChange`/`onLowerChange`/`resetHeading`/`onFenjinPick`/`onMountainPick`/`onSlider`/`applyNearest`/`shiftMonth`/`resetMonth` 均已定义）；`check-components.js` 通过；`pages/gua64` 新增 `index.wxss`（爻线样式）；相关 8 个 js 文件 `node --check` 零失败。

---

## 2026-11-17 结论优先改版：上下文条 + 长文收进折叠

用户反馈「拿到 App 应该只看到当前方位、所处位置、时令、自己生辰，以及当前页面能给出的结论，不要一屏平铺那么多字」。按这个标准做了两件事。

**一、四项上下文全局可见**

新增 `utils/context.js`（`snapshot` / `refreshPlace` / `namePlace` / 各单项格式化）与全局组件 `components/ctx-bar`：

| 格 | 数据来源 | 点按行为 |
|---|---|---|
| 当前方位 | `orientation.current()`（罗盘测向或手选，唯一数据源） | 回罗盘页重新测向 |
| 所处位置 | 本机缓存的一次性定位结果（不常驻监听）；显示坐标或用户起的名字 | 点按刷新定位，长按给位置命名（如「自家客厅」） |
| 时令 | `solarTermProgress()`：当前节气 + 距下一节气天数 | 进择日看节气与日课 |
| 本人生辰 | 家庭档案宅主出生年 + 八宅命卦 | 进家庭资料补出生年 / 性别 |

已在 16 页接入：罗盘首页（传 `hide-dir`，方位已在盘面，只留位置/时令/生辰三格）、盘解、玄空、八宅、紫白、三合、择日、奇门、外煞、日签、化解、提醒、天机、户型、分金、六十四卦。组件在 `app.json` 全局注册，页面无需重复声明。

**二、把所有平铺长文改成「一句结论 + 折叠详解」**

沿用已有 `.conclusion` 看板样式，本轮新改：

- **三合水法**：首屏只剩「总断 / 坐山阶段 / 水口合参 / 宜来水」四个数字与一句建议；黄泉、八煞、十二长生逐条长文、五煞诀全部移入「黄泉 / 八煞 / 十二长生详解」折叠区（默认收起）。
- **外煞自查**：首屏是「已中标 N 项 + 极凶几项 + 一句处置建议」；命中项只列名称与一句化解；完整 35 类煞型清单收进「逐项自查」折叠，点条目仍是勾选。
- **紫白九星**：新增结论看板（年/月入中 + 五黄/二黑方位 + 一句话引导）；流年凶位与坐向冲犯共十几条收进折叠。
- **全局默认收起出处**：`store.getSettings()` 的 `showEvidence` 默认改为 `false`，各页的「原诀 / 出处」脚注不再默认铺出来，需要时在设置里打开。

**三、回归**

新增上下文快照断言（四项齐备、无定位/无档案时有兜底文案、时令含距下一节气天数），断言数 50 → **51 项**；`check-components.js` 同时支持 `components/x/x.wxml` 命名与 `app.json` 全局 `usingComponents`，避免全局组件被误判为未声明。

**四、首页盘面控件收口**

罗盘首页原本把「模式切换、功能按钮（锁定/选山向/图层/分享）、当日吉神条、节气条、磁北/真北胶囊」全部铺在盘面上方，首屏要滚过一屏半才看到盘面。现在统一收进一条「盘面设置 · 模式 / 图层 / 选山向 / 校准」开关（`panelOpen`，默认收起），强磁干扰告警保留常显——它是安全提示，不能藏。首屏顺序变成：标题 → 上下文三格 → 结论看板 → 盘面 → 详情折叠。

**五、历史与化解两页按同一标准重排**

- `history`：首屏「N 条记录 / 今天几条 / 最近类型 / 当前筛选条数」，下接类型胶囊筛选（盘解、海报、择日、玄空、天机、户型、外煞各自计数），列表默认最近 8 条，可「展开全部」；单条删除用 `catchtap` 防冒泡，`open`/`remove` 改按 `data-id` 查找，不再依赖数组下标（筛选后下标会错位）。
- `remedy`：首屏「还剩 N 项未做 / 完成度 % / 已办-共 / 极凶几处」+ 进度条，条目只给标题与来源标签，点开才出化解做法与应期；来源胶囊可只看玄空 / 紫白 / 八宅；底部保留「查看某模块详解」。

**六、修一处插入位置错误**

批量插 `ctx-bar` 时，7 个页面（日签、化解、提醒、天机、户型、分金、六十四卦）的锚点命中了 `<view class="screen">`，导致上下文条跑到导航条上方。已改为一律插在 `<view class="body">` 开头，与盘解、玄空等页一致，并核对每页只有一个 `ctx-bar`。

校验：`regression.js` 17 组 51 项全通过；`check-handlers.js` 27 页全通过（新增 `togglePanel`、`onFilter`、`toggleAll`、`onSourceFilter`、`toggleTaskDetail` 均已定义）；`check-components.js` 通过；`app.json` JSON 解析通过。
**七、Tab 视觉改版（五个 tab 的首屏重排）**

用户反馈「每页排版看不出使用欲望」。重新按「图标 + 结论 + 能点的事」三层排首屏：

- **tabBar 加线性图标**：`images/tab/` 下 5 组 81×81 PNG（罗盘 / 四宫格 / 日历 / 房屋 / 信息），常态 `#6f7a8f`、选中 `#e9d8a6`，与文字同色系。图标由 `make_icons` 脚本以 SDF 超采样绘制，无第三方依赖，可直接改色重生成。
- **罗盘首页**：结论看板下新增四格快捷入口（盘解 / 择日 / 户型 / 化解），首屏就能进主功能；盘面控件收进「盘面设置」抽屉（见上一节）。
- **盘解页**：原本折叠在「全部工具」里的 8 个入口改为常显 2 列宫格，点击有 `hover-class` 反馈 —— 这是「能做什么」最直接的表达。
- **择日页**：新增七天横条（今天起七天，标星期、日号、建除与吉凶，点击直接切到该日日课，左右箭头翻组），把择日从「一个日期选择器」变成「一张日历」。
- **关于页**：改为「本机计算」结论卡 + 四个常用入口（家庭资料 / 化解清单 / 提醒中心 / 备份恢复）+ 显示设置；协议、权益、引导与两个危险操作（清空历史、清空全部数据）收进「更多」折叠，避免误触。
- **交互反馈**：新增 `.entry-active`、`.quick-active` 按下态，宫格与快捷入口不再是「看不出能点」的纯文字块。

新增 `scripts/check-assets.js`：校验 `app.json` 里 tabBar 等本地资源路径真实存在（图标缺失是小程序里最常见的白块来源），当前 10 个路径全部通过。

**八、奇门点宫解读、天机结论化、结论卡字号（本轮）**

- **奇门九宫可点**：原来九宫格只是「看」，现在每格 `bindtap` 选中并高亮（`.cell-picked`），下方出该宫断语卡：地盘干、九星（含星性）、八门（含门性短句）、八神，加一句可用/受制/中和的判断。判据全部复用 `evaluateScenario` 的既有规则（门 ±2、星 ±1、神 ±1），另在 `utils/qimen.js` 新增导出 `palaceLine(cell)`，不另造新说法；中五宫单独处理为「天禽寄坤、不给八门」，与 iOS 排法一致。
- **天机长卷结论优先**：首屏从「总评一大段 + 6 条风险 + 摘要 + 13 门逐段」改成：总评（等级 + 分数）、高危项数、待处置条数、收录门类数四格；处置优先级只留标题、来源、一句影响，化解做法与总评详解合并进一个折叠；13 门正文（摘要 + 逐门 rows）进另一个折叠，两个折叠用独立状态（`showRisks` / `showScroll`），不会互相牵连。
- **结论卡字号**：`.conclusion-head` 34rpx → 38rpx、行高 46 → 50rpx；`.conclusion-v` 26rpx → 28rpx。罗盘首页与各页的结论主数字放大一档，首屏视线先落在数字上。

回归新增奇门单宫断言（三吉加会判 `ji`、中宫 `gateLine` 为空），总数 51 → **52 项**；`check-handlers` 覆盖新增 `onCellTap` / `toggleRisks` / `toggleScroll`。

**九、罗盘盘面：坐/向常显标记（本轮）**

原来盘面上只有「触屏选中某一山」时才有一段橙色高光，静止时看不出自己坐哪、朝哪。现在：

- 新增 `drawSitFaceBands()`，在静态盘面绘制之后、山向高光之前调用（位于盘面旋转坐标系内，随盘转，不随手指动）：
  - **坐山**：金色 15° 淡扇区（`rgba(233,216,166,0.12)`），覆盖「八宫环外沿 → 分金环」；
  - **向首**：红色 15° 淡扇区（`rgba(231,120,120,0.12)`），同环带；
  - 最外圈再各补一枚 6px 小帽（同色 0.42），把方位落到盘边，扫一眼即知朝向。
- 扇区角度取 `MOUNTAINS_DATA` 中该山的 `deg ± 7.5`，与二十四山刻度严格对齐；坐/向来源仍是 `getSitAndFaceDiagnosis()` 单一口径，不新增方位计算。
- 首页结论副标题去掉与上下文条重复的节气/定位，只留日期与时刻；结论脚注改为「金色扇区为坐山、红色为向首」，给颜色一个明确说法。

校验：`pages/index/index.js` `node --check` 通过；`regression.js` 52 项全通过；`check-handlers` / `check-components` 通过。

**十、盘面现场记忆：图层 / 缩放 / 平移 / 抽屉（本轮）**

之前每次进入罗盘页都要重开图层、重调转盘模式，缩放一离开就归位。现在把「现场」写进 `settings.dialView`：

- **存什么**：`layers`（完整 `layerConfig` 布尔表）、`scale`（保留两位）、`tx`/`ty`（平移像素）、`panelOpen`（盘面设置抽屉是否展开）；转盘/固定盘与立向锁定仍走原有的 `settings.compassLock`，两者口径不变。
- **什么时候存**：`onHide`（切 tab 或跳走）、`onLayerToggle`、`applyLayerPreset`、`toggleCompassMode` 之后。缩放是页面实例字段而非 `setData`，所以落盘点选在「离开」这种明确的时刻，避免手势过程中频繁写 Storage。
- **怎么恢复**：`onLoad` 先还原图层（逐键校验布尔类型后 merge 到 `DEFAULT_LAYERS`，脏数据不会污染盘面），同时把 `scale/tx/ty` 暂存到 `_pendingView`；等 `initCanvas` 拿到真实画布尺寸后再套用并重绘一次——平移边界依赖 `canvasW`，提前套用会被错误夹取。
- **安全边界**：`scale` 必须落在 `MIN_SCALE..MAX_SCALE`（1.0–4.5）才生效，NaN/超界直接忽略；恢复后 `applyViewTransform()` 重新做一次边界收敛，保证 `scale=1` 时 `tx/ty` 归零。

校验：`pages/index/index.js` `node --check` 通过；`regression.js` 52 项全通过；`check-handlers` / `check-components` / `check-assets` 通过。

**十一、整机搬家：备份升级到 v2 + 存储键登记校验（本轮）**

以前「备份」只覆盖档案、户型、任务、历史、设置五段；定位结果、上次坐向、外煞勾选、测绘报告草稿散在各页，换机全丢；`clearAll` 也只清这五个键，残留的键会跟着新用户继续跑。这轮统一收口：

- **`store.KEYS` 成为唯一事实**：9 个键集中登记（`yj_profiles` / `yj_remedy_tasks` / `yj_floorplans` / `yj_history` / `yj_settings` / `yj_place` / `yj_current_orientation` / `yj_sha_check` / `yj_report_draft`），`clearAll` 直接遍历这张表。
- **备份 v1 → v2**：`collect()` 追加 `place` / `orientation` / `shaCheck` / `reportDraft` 四段；`summaryOf` 增加 `placeName`、`hasOrientation`、`shaChecked`、`hasReportDraft`，备份预览能说清「带了哪些现场数据」。
- **导入校验变严**：`parse()` 先挡版本（`v` 高于 2 直接提示升级）、再挡结构（`members` 必须是数组、`floorplans`/`remedyTasks`/`history` 必须是数组、`settings` 必须是对象）。宁可拒绝整份备份，也不把脏数据落进本机。
- **恢复语义明确**：`replace` 把现场数据一并覆盖；`merge` 时「本机已有的位置/坐向保留本机」，避免拿旧备份把当前现场改回去；户型改为一次性写入 `yj_floorplans`（原来逐个 `saveFloorplan` 会反复 unshift、写 20 次）。
- **新增 `scripts/check-keys.js`**：静态扫描 `utils/` 与 `pages/` 里的 `yj_*` 字面键，与 `store.KEYS` 比对，未登记即报错。当前 62 个文件、9 个键全部对齐 —— 这正是「加了新键忘了登记」的防呆。

回归新增 v2 断言（位置/坐向/外煞往返、高版本拒绝、`members` 非数组拒绝、`replace` 写回现场），总数 52 → **53 项**。

校验：`node --check`（store/backup/backup 页）通过；`regression.js` 53 项全通过；`check-handlers` / `check-components` / `check-assets` / `check-keys` 全通过。

**十二、导入前差异预览（本轮）**

上一轮备份能带全数据了，但点「执行恢复」之前用户仍只知道一句笼统摘要，不知道会新增多少、覆盖多少、哪些本机数据会丢。这轮补上「先算后写」：

- **`backup.diff(obj, mode)`**：纯计算、零写入，逐段对比备份与本机，返回
  - `members` / `floorplans` / `tasks` / `history`：`incoming`、`add`、`dup`，以及覆盖模式下会丢弃的 `dropped`
  - `tasks.newlyDone`：合并时「本机未完成、备份已完成」的项数（会被标为已完成）
  - `settings.changed` + 中文键名（语言、单位、提醒开关、显示原诀、引导已读、云环境、盘面现场、立向锁定）
  - 现场四段 `place` / `orientation` / `shaCheck` / `reportDraft` 的动作：`none` / `keep` / `overwrite` / `set`
- **页面**：读取备份（剪贴板 / 聊天文件 / 云端）后立刻生成「差异预览」清单；切换合并与覆盖会实时重算，因为两种模式结论完全不同（合并保本机现场、覆盖改写现场）。
- **文案口径**：合并显示「新增 N / 已存在 M」，覆盖显示「将替换为 N，本机多出的 K 条会被丢弃」，并统一提示「以上为推算结果，尚未写入本机」。

回归新增差异预览断言（合并新增/重复、任务完成态翻转、设置差异、合并保现场 vs 覆盖改现场），总数 53 → **54 项**。

校验：`node --check`（backup / backup 页）通过；`regression.js` 54 项全通过；`check-handlers` / `check-components` / `check-assets` / `check-keys` 全通过。

**十三、恢复的事务性与容量预警（本轮）**

「整机搬家」还差最后一环：`apply` 原来是连续 6～9 次独立写，中途任一段失败就会留下「一半新、一半旧」的结果，而页面还会报成功。这轮改成事务式提交：

- **先排好写入计划**：把 settings / profiles / floorplans / remedyTasks / history + 现场四段压成一个 `pairs` 列表，不再边算边写。
- **逐段写并收集失败**：`store.write` 返回布尔（`setStorageSync` 抛错即 false），失败的键名进 `failed`。
- **整体回滚**：任一段失败就把写前快照（`cur` 的五个主段 + 四个现场段）逐键写回；原本不存在的键直接 `store.remove`，不留空壳。返回 `{ error: '写入失败（N 段），已回滚到恢复前的数据', failed }`。
- **页面**：`onApply` 先判 `st.error`，失败时把原因写进结果卡并 toast，不再展示「恢复完成」。
- **容量预警**：`wx.getStorageInfoSync()` 读出占用，超过 85% 时在数据卡和确认弹窗里提示「可能因空间不足中断，失败会自动回滚」。恢复前先知道风险，比事后排查好。

为支持回滚，`store` 额外导出 `remove(key)`。

回归新增「写失败整体回滚」断言：故意让 `yj_history` 写入抛错，验证返回 `error` 与 `failed: ['yj_history']`，且档案、户型、历史三处都保持恢复前的原值。总数 54 → **55 项**。

校验：`node --check`（store / backup / backup 页）通过；`regression.js` 55 项全通过；`check-handlers` / `check-components` / `check-assets` / `check-keys` 全通过。

**十四、备份撤销点：敢点「覆盖」的最后一块（本轮）**

事务回滚能挡住「写一半失败」，但挡不住「用户点错了覆盖」。这轮加撤销点：

- **`UNDO_KEY = yj_backup_undo`**（登记进 `store.KEYS`，共 10 个键）：每次 `apply` 前先 `collect()` 一份当前数据，写进撤销点，附带 `at` 与本次 `mode`。提交失败（已回滚）时不写撤销点，避免留下无意义的存档。
- **`getUndo()`**：返回 `atText`、`mode`、`age`、`expired`（7 天 TTL）与 `summary`（家人/户型/化解/历史计数），页面直接渲染，不做额外计算。
- **`restoreUndo()`**：用撤销点整体 `commit(..., 'replace')` 覆盖回去；成功后把「撤销前的当前状态」写成新的撤销点 —— 于是可以来回切，而不是单向的一次性回退。超过 7 天则清除撤销点并报错。
- **页面**：新增「撤销点」卡，显示上次恢复时间与可退回的数据量；`onUndo` 二次确认后执行，失败同样走错误态；过期时按钮变灰并提示「已过期（7 天）」。
- 撤销点**不进备份导出**：它是本机安全网，跨设备搬过去反而会带着一台陌生机器的旧现场。

回归新增撤销点断言（恢复后留档、撤销回原值、再撤一次切回新值、过期标记与清除），总数 55 → **56 项**。

校验：`node --check`（backup / store / backup 页）通过；`regression.js` 56 项全通过；`check-handlers` / `check-components` / `check-assets` / `check-keys`（10 键 62 文件）全通过。

**十五、恢复日志（本轮）**

有了撤销点之后还缺一件事：用户过几天会问「我上次到底动过数据没有」。这轮加本机审计日志：

- **`LOG_KEY = yj_restore_log`**（登记进 `store.KEYS`，共 11 个键）：`pushLog()` 头插、最多 20 条，`getLog()` 过滤掉无 `at` 的脏项，`clearLog()` 供清空数据时用。
- **留痕范围**：`apply` 成功记「动作 + 模式 + 家人/户型/化解/历史计数 + 位置与外煞」，失败记「错误原因 + 失败键名」；`restoreUndo` 成功记 `undo`，撤销点过期/损坏也各留一条。**失败同样留痕**，否则用户只看得到失败提示，事后无从追溯。
- **页面**：备份页新增「最近的数据变动」卡，展示最近 5 条：动作（恢复/撤销）、模式（覆盖/合并）、结果（绿成功 / 红失败）、时间。脚注标明「最多 20 条，仅存本机，清除数据一并删除」。
- 日志**不进备份导出，也不进撤销点**：它是本机行为记录，跨设备没有意义，还要防止把别人的操作史带进来。

回归新增日志断言（成功/撤销/失败各一条、失败带原因、25 次恢复后截断为 20 条），总数 56 → **57 项**。

校验：`node --check`（backup / backup 页）通过；`regression.js` 57 项全通过；`check-handlers` / `check-components` / `check-assets` / `check-keys`（62 文件 / 11 键）全通过。

**十六、补齐剩余算法缺口：分金逐度 / 空亡逐度 / 八宅合配分级（本轮）**

按审计表里仍标「未做」的条目逐条落地，都是纯算法、页面直接可用的东西：

1. **分金逐度细断（`utils/fenjin.js`）**
   - 新增 `mountainOf` / `offsetToCenter` / `jianXiang`：以山中心为中心，`|off|<1.5°` 正针、`1.5–6.5°` 兼向（给出「午山兼丁」这类正式称谓）、`≥6.5°` 贴边界。
   - 新增 `degreeReading(deg)`：一次给出所属分金 / 纳音 / 吉凶 / 分金内位置（前段·中段·后段）/ 兼向 / 可用性 / 一句结论 / 调整建议 / 最近吉度。判级与 `kongwang.classify` 同口径，避免两套说法。
   - 新增 `nearestAuspicious(deg)`：±8° 内 0.5° 步长找最近可用吉度，带偏移量与纳音，供「一键取吉度」。
   - `pages/fenjin` 加「逐度细断」卡：兼向、空亡判级、分金内位置、可用性、结论、建议，底部按钮直接跳到最近吉度；当前即吉度时按钮文案改为「当前度数即吉度」。
2. **空亡逐度解释（`utils/kongwang.js`）**
   - 新增 `mountainAt` 与 `reading(angle)`：在 `classify` 之上补「人话解释 + 可执行调整建议 + `adjustTo` 建议度数」。正针→可直接立向；兼向→按替卦或回正至山中心；差错小空亡→回到山心 ±1.5°；出卦大空亡→必须离开出卦线取正针。
3. **八宅宅命合配分级（`utils/bazhai.js`）**
   - `compatibility` 由「相配 / 相克」两级细化为四级：`same`（同卦伏位，4 分）、`group`（同组相配，3 分）、`borrow`（异组借吉，2 分，防御分支）、`clash`（异组相冲，1 分）。判据取「命卦大游年落在宅卦所在宫」的那颗星，附星名、吉凶、说明与建议。
   - `pages/bazhai` 合配结论加等级标签（≥3 绿、2 黄、1 红），让「同卦」与「同组」不再显示成同一句。
   - 说明：八宅定式下吉星只落同组宫，`borrow` 实际不可达，保留为游年表变更时的兜底；回归按三级验证（坎命五鬼在艮、六煞在乾）。
4. **法务口径回归一致**
   复核时发现 `utils/legal-text.js`、`pages/legal`、设置页又出现了「隐私政策」入口，而回归里「隐私说明已移除」断言因此失败。已按既有口径重新收敛：删除 `PRIVACY_TITLE/BODY` 与 `DOCS.privacy`，`pages/legal` 只保留「用户服务协议 / 合规与安全说明」，设置页去掉隐私按钮与 `goPrivacy`，旧的 `?type=privacy` 链接回落 `terms`。

回归：59 项（新增分金逐度 1 项、八宅合配 1 项），全部通过；`check-handlers` / `check-components` / `check-assets` / `check-keys`（62 文件 / 11 键）全通过。

**仍未迁移（结论性口径）**

| 项 | 原因 | 现状 |
|---|---|---|
| 8 语种全量文案 | iOS `LocalizationManager` 721KB 文案；小程序仅 `utils/i18n.js` 的界面骨架 + 设置页词条 | 产品既定只做简体；语言选择器仍在，切语言只影响设置页标签，业务页未接 |
| StoreKit 内购 / 恢复购买 / 评分 | 微信禁止 iOS 端小程序虚拟支付 | `pages/vip` 权益全开放说明，无付费墙 |
| RoomPlan / LiDAR / ARWorldMap / RealityKit | 小程序无 ARKit 对应 API | 手工录入 + Canvas 等轴测 + 相机叠盘 + 拍摄存证 |
| WidgetKit 桌面组件 | 小程序无桌面组件 | `utils/widget-timeline.js` 今日快照 + 提醒中心说明 |
| iCloud KVS 实时同步 | 无系统键值同步 | `backup.js` 导出/导入 + 云开发可选 |
| 端侧视觉识别（自动形煞） | 无端侧模型 | 35 类人工自查 + 拍照存证 |
| 系统通知 / 快捷指令 / Spotlight | 无对应入口 | 订阅消息 + 云函数 + 桌面快捷方式说明 |

**十七、功能缺口补迁：择日吉神体系与奇门月令旺衰（本轮）**

按「只迁未完成的功能、不迁平台做不了的」口径，补两处审计里明确标缺的功能：

**1. 择日：吉神 / 忌日 / 逐事项吉时（`utils/zeri.js`）**

- `auspiciousGods(date)`：按月建查 **天德、天德合、月德、月德合、天赦**。天德按月给干或支（寅月丁、卯月申…），天德合取干五合 / 支六合；月德按三合局（寅午戌丙、申子辰壬、亥卯未甲、巳酉丑庚），月德合取五合；天赦按四季（春戊寅、夏甲午、秋戊申、冬甲子）。命中给「今日值此神」，未命中给「本月此神在某日」，可直接另择。
- `badDaysOf(date)`：四废（春庚申辛酉、夏壬子癸亥、秋甲寅乙卯、冬丙午丁巳），与月破分开判。
- `eventHours(shichen, key)`：逐事项吉时。取黄道时（`level=ji`）按六合 +2、三合 +1 排序取前三；当日无黄道则退回「六合/三合时辰」并标记 `fallback`，不硬凑。
- 事项判定纳入神煞：月破或四废一票否决，**天赦日可解**（唯坐山冲煞仍避）；每条「宜」的事项直接列出该事项的吉时与值神。
- `pages/zeri`：事项择日卡新增「吉神 / 忌日」两行与每条事项的「吉时：X时（神）」，脚注写清查表口径。

**2. 奇门：月令旺衰（`utils/qimen.js`）**

- 新增节气→月建映射与五行表；`relation(elem, monthElem)` 按「当令旺、令生者相、生令者休、克令者囚、令克者死」出 `state/score/text`。
- `vitalityOf(name, isGate, monthElem)`：八门（休水、生土、伤杜木、景火、死土、惊开金）与九星（蓬水、芮土、冲辅木、禽土、心柱金、任土、英火）各自判旺衰。
- `calculateChart` 每宫写入 `gateState` / `starState` / `vitality`，盘面带 `monthText`（如「月建亥（水当令）」）。
- `evaluateScenario` 与 `palaceLine` 纳入旺衰：得令 +1、失令 −1；断语文末补「旺衰：…」，`palaceLine` 的 parts 也拼上旺衰。
- `pages/qimen` 盘面参数卡新增「月令旺衰」行。

回归：61 项（新增择日吉神/忌日/吉时 1 项、奇门旺衰 1 项），全部通过；`check-handlers` / `check-components` / `check-assets` / `check-keys` 全通过。

**十八、三合兼向水法 · 玄空兼向起替（本轮续补）**

**1. 三合：双山定局 + 兼向水法（`utils/sanhe.js`）**

- 修正 `bureauOfMountain()`：原实现只认三合地支（申子辰／亥卯未／寅午戌），其余一并落金局，导致 **壬、癸、艮、甲、乙、巽、丙、丁、辛、乾** 十山局属错判。改按「双山定局」（壬子同水、癸丑同金、艮寅同火、甲卯同木……），十二长生表与黄泉合参随之归正。
- 新增 `MOUNTAIN_24`（二十四山顺时针）与 `nextMountain(mountain, step)`，供兼左／兼右取邻山。
- 新增 `jianXiangWater(sit, face, aux, laiShan, quShan)`：
  - **向首校验**：向首须与坐山差 12 山（180°），否则判「立向不合」并给出应为之向。
  - **同双山兼**：如壬兼子，两山同属壬子双山、同为水局 → 兼向不换局，只作度数微调，判「成局」。
  - **跨双山兼**：如子兼癸，已出壬子双山入癸丑双山 → 判「出卦（大空亡／差错）」，局由水局改金局，古法忌用，给「改立正向 / 兼回本双山」建议。
  - **水口归局**：来水 / 去水双山各按双山取局，有水口即以水口归局者为「用局」，并接 `judgeWater()` 出合参结论；水口凶时整体降为「需校」。
- `pages/sanhe`：坐山卡新增「兼向（不兼／兼前一山／兼后一山）」选择，下方新增「兼向判定」卡（用局、坐局／兼局、向首校验、结论与建议），首屏仍是一句话结论。

**2. 玄空：无传感器也能起替卦（`pages/xuankong`）**

- 新增「兼向」选择（正针 0°／兼向右 2°／4°／6°）：按坐山对宫加偏移合成向首度数，交给 `sitface.diagnoseHeading()` 判级，**兼向（≥1.5°）自动起替卦、正针保持下卦**，并解锁手动切换。
- 判据与空亡分级同源（1.5° 正针、1.5–6.5° 兼向、≥6.5° 出卦），避免页面自造阈值。

回归：63 项（新增「玄空替卦盘面变化 + 兼向阈值」1 项、「三合兼向水法」1 项），全部通过；五条校验全绿。

**十九、六十四卦补京房八宫：宫位 / 世应 / 纳甲六亲 / 六神**

审计里 `六十四卦` 标缺「纳甲六亲、京房八宫世应」，本轮补齐（纯算法，页面直接可用）。

**1. 新增 `utils/jingfang.js`**

- `GONG`：八宫宫首与五行（乾兑金、坤艮土、震巽木、坎水、离火）。
- `TYPES`：八宫卦型与世应——本宫（世6应3）、一世（1/4）、二世（2/5）、三世（3/6）、四世（4/1）、五世（5/2）、游魂（4/1）、归魂（3/6）。归魂按「游魂内卦三爻复原」生成，相对宫首即五爻变，故乾宫归魂为火天大有、坤宫归魂为水地比，与传世八宫卦序一致。
- `binaryOfGong()` 生成每宫八卦；建表后校验 **64 卦不重**（曾误设归魂变爻导致 56 卦，已修正并加断言守住）。
- `NA_JIA`：乾甲壬、坤乙癸、震庚、巽辛、坎戊、离己、艮丙、兑丁，内三爻／外三爻地支全表。
- `liuQinOf()`：以宫五行为我，同我兄弟、生我父母、我生子孙、克我官鬼、我克妻财。
- `analyze(binary, dayGan)`：出宫、卦型、世应、六爻纳甲干支五行六亲，六神按日干起（甲乙青龙、丙丁朱雀、戊勾陈、己腾蛇、庚辛白虎、壬癸玄武）。
- `table()`：八宫六十四卦总表。

**2. `pages/gua64` 接入**

- 新增「京房八宫」卡：宫与五行、卦型胶囊、世应位置、日干选择器（初爻起何六神实时变）、六爻表（爻位／纳甲／六亲／六神／世应标记），默认日干取当日四柱日干。
- 起卦、抽爻、改上下卦时同步刷新，静卦也有完整八宫信息。

回归：64 项（新增京房八宫 1 组：卦序、世应、纳甲、六亲、六神），全部通过；五条校验全绿。

**二十、八宅补纳音：坐山居中分金纳音 × 宅卦 / 命卦五行**

审计里八宅标缺「纳音」，本轮补齐。

**1. `utils/bazhai.js` 新增**

- `sitNayin(mountain)`：取二十四山**居中分金**（山心）的甲子与纳音，直接复用 `utils/fenjin.js` 的 120 分金表，与「分金」页同一数据源，不另造一套。返回山、度、甲子、纳音名、纳音五行、分金等级、可用性。
- `elemRelation(a, b)`：五行关系五判（同／我生／生我／我克／克我），文案带「泄气／得助／受制／受压」的白话注解。
- `nayinCompat(houseGua, lifeGuaNum, sitMountain)`：
  - **纳音 × 宅卦**：纳音生宅卦或比和 → 判「山气助宅」（吉）；宅卦克纳音或纳音泄宅 → 判「宅压山气」（慎）。
  - **纳音 × 命卦**：并列给出与命卦五行的生克，供与「宅命合配四级」相互印证。
  - 结论与做法：吉则按大游年取用即可；慎则坐山方少动土少开门、按克我之五行泄化（如水克火，忌该方积水）。
  - 口径写明：纳音只作合配的加减参考，**不单独定吉凶**，主判仍是宅命大游年。

**2. `pages/bazhai`**

- 合配卡新增「坐山纳音」行：显示居中分金甲子与纳音（如「丙寅 · 炉中火（火）」），下接一枚等级胶囊（山气助宅／纳音平和／宅压山气）与一句关系说明、一句做法。
- 换坐山、换出生年、换性别时同步刷新。

回归：65 项（新增八宅纳音 1 组：纳音归一、五行五判、纳音合配分级），全部通过；五条校验全绿。

**二十一、迁移完整度复核（2026-11-18，全量对账）**

**口径**：与 iOS 工程 `tiandi_luopan/ios` 56 个 Swift 文件逐项对账；iOS 自身没有的不算缺口，平台无对应能力的不算缺口（按用户既定口径不再迁）。

**1. 引擎 → 工具层对账（13 个引擎，全覆盖）**

| iOS 引擎 | 小程序实现 |
|---|---|
| CompassMainView / CompassDialView / CompassLayerManager | `pages/index` + `compass-data/-layer/-filter`、`geomagnetic`（WMM 磁偏）、`heading-state`、`haptic` |
| Fenjin120Data / Mountain24 | `utils/fenjin`（120 分金全表 + 逐度细断 + 兼向 + 最近吉度）、`sitface` |
| KongWangDetailSheet | `utils/kongwang`（逐度判级 + 解释 + adjustTo） |
| FlyingStarsEngine / XuanKongGridView | `utils/xuankong`（81 断语、三般卦、七星打劫、流年月、替卦；页面可按兼向自动起替） |
| BaZhaiEngine / FamilyRoomAllocation | `utils/bazhai`（命卦、游年、四级合配、纳音合配、家人配房、化解任务） |
| SanHeWaterEngine | `utils/sanhe`（黄泉、八煞、十二长生、水口合参、双山定局 + 兼向水法） |
| PurpleWhiteEngine | `utils/zibai`（年/月紫白、太岁岁破三煞、组合断语、逐宫化解） |
| ZeRiEngine | `utils/zeri`（建除黄黑道、月破、吉神（天德/月德/天赦）、四废、七类事项 + 逐事项吉时） |
| QimenEngine | `utils/qimen`（九宫排盘、八场景用神、年命落宫、月令旺衰） |
| Hexagram64 | `utils/hexagram` + `utils/jingfang`（抽爻、错综互、八宫世应、纳甲六亲、六神） |
| ExteriorShaEngine / OnDeviceShaAnalyzer | `utils/sha`（35 类形煞四段文案、四档严重度、`resolveShaByHeading` 方位落宫联动；端侧识别无替代） |
| TianJiShuEngine | `utils/tianji`（`buildScroll` 长卷、`deepAnalysis` 深度分析、`guidanceText` 行动建议） |
| SolarTimeCalculator / TraditionalEvidence / GeometryUtils | `astronomy`（真太阳时 + 均时差）、`traditional-evidence`、`geom` |
| HouseSpatialSurveyModel / FloorplanEngine | `utils/floorplan`（几何层：面积、形心、九宫覆盖率、投影）、`roomfit`、`spatial-findings`、`reportcard` |

**2. 修正原审计表中的过时结论（以本节为准）**

| 原编号 | 原结论 | 现况 |
|---|---|---|
| 1 主罗盘 | 无 64 卦抽爻、无水印存证 | 64 卦环在盘面，抽爻在 `pages/gua64`；`canvasToTempFilePath` 存图已接 |
| 2 分金 | 缺逐度细断、兼向 | **已补**（`degreeReading` / `jianXiang` / `nearestAuspicious`） |
| 3 空亡 | 缺逐度解释 | **已补**（`kongwang.reading`） |
| 7 户型 | 缺拖拽缩放 | **已补**（`onRoomTouchMove` 房可拖动；缩放未做，属体验项） |
| 8 玄空 | 缺自动替卦、流年月、化解、出处 | **已补**（兼向选择自动起替、`withFlow`、`practicalActions`、`evidence`） |
| 9 八宅 | 缺纳音、合配分级 | **已补**（`nayinCompat`、`compatibility` 四级） |
| 10 三合 | 缺兼向水法 | **已补**（`jianXiangWater` + 双山定局修正） |
| 12 择日 | 缺吉神、四废、逐事项吉时 | **已补**（`auspiciousGods` / `badDaysOf` / `eventHours`） |
| 13 奇门 | 缺月令旺衰 | **已补**（`relation` / `vitalityOf`） |
| 14 天机 | 无 deepAnalysis / guidance | **已补**（两函数均在 `utils/tianji`） |
| 15 六十四卦 | 缺纳甲六亲、八宫世应 | **已补**（`utils/jingfang`） |
| 16 外煞 | 缺方位落宫 | **已补**（`resolveShaByHeading` 八宫主应联动） |
| 21 本地档案 | 历史仅接口 | **已补**（`pages/history` 已接） |

**3. 仍然存在的差异（都不是「没做」，而是「做不到 / 做浅了」）**

- **平台无对应能力（不迁）**：Widget 黄历快照、StoreKit 内购付费墙、RoomPlan/LiDAR 扫描、ARWorldMap 世界锚点与深度遮挡、SceneKit 3D 场景漫游、端侧 Vision 形煞识别、iCloud KVS、系统通知/快捷指令/Spotlight。
- **降级但等价**：AR 实景 = 相机取景 + 靶心测角 + 二十四山叠印 + 气泡 + 水印存证（无深度遮挡）；3D = Canvas 等轴测体块（无第一人称漫游）；长卷 = Canvas 简版排版（无字体印章级还原）。
- **多语种**：iOS 738KB `LocalizationManager`（8 语种）；小程序按既定产品决定只做简体，`i18n.js` 仅留骨架。

**4. 唯一确认「iOS 有、且可迁、但尚未迁」的功能项**

`Hexagram64.HexagramItem` 每卦还有三个字段：`elementNumber`（卦气生成数：一水二火三木四金五土）、`luckDegree`（吉凶分级：大吉/中吉/平/凶）、`fenJinDetail`（穿山透地七十二龙 / 易经分金描述）。小程序 `utils/hexagram.js` 只建了卦名、上下卦、二进制、角度，**这三个字段未迁**（其余 13 个引擎无同类缺口）。

**二十二、六十四卦补齐卦气生成数 / 吉凶分级 / 居中分金（iOS 最后一处可迁缺口）**

iOS `HexagramItem` 有三个字段此前未迁：`elementNumber`、`luckDegree`、`fenJinDetail`。本轮按「与分金页同源」的口径补齐，并修正 iOS 侧的占位式取值。

**1. `utils/hexagram.js`**

- `ELEM_NUMBER`：卦气五行生成数——一水、二火、三木、四金、五土；取**上卦（外卦）五行**定卦气，乾兑金→4、坎水→1、离火→2、震巽木→3、坤艮土→5。
- `attributesOf(angleCenter, upperElem)`：以本卦 5.625° 卦区**居中分金**（`fenjin.degreeReading`）定三件事：
  - `fenJinDetail`：`居中分金 丁卯（炉中火） · 旺相珠宝 · 分金中段`（甲子 + 纳音 + 分金等级 + 段位）。
  - `luckDegree`：珠宝中段＝大吉、珠宝前/后段＝中吉、龟甲火坑＝平、孤虚差错 / 虚度空亡＝慎用，四档齐全（实测分布 大吉 8 / 中吉 16 / 平 16 / 慎用 24）。
  - `luckRank`：四档排序值，供日后排列表格。
- 不套用「兼向」判语：卦区（5.625°）与二十四山分区（15°）不同源，硬套会把「子山正中」误标成「子山兼癸」；因此分金描述只述分金，不掺兼向（本轮先按兼向写过一版，已修正）。
- iOS 原实现是 `elementNumber = (i % 9) + 1`、`luck = f(i % 8)`、`detail` 三段固定串，与卦象无关；小程序改为按卦气与分金实算，口径可复核。

**2. `pages/gua64`**

- 卦卡新增三行：卦气生成数（如「4（金）」）、吉凶分级（大吉绿 / 中吉平 / 慎用红胶囊）、居中分金（甲子·纳音·等级·段位），脚注写明取值规则。
- 抽爻、改上下卦、静卦时同步刷新。

回归：66 项（新增六十四卦卦气与分金 1 组：生成数归一、四档齐全、五行齐全、乾卦取四金），全部通过；五条校验全绿。

**二十三、八宅逐宫断语细化 + AR 点画面取方位**

按上一轮复核后的两个方向继续，都是「补深度」而非补算法。

**1. 八宅：逐宫断语落到人（`utils/bazhai.js`）**

- 新增 `PALACE_ROLE`：八宫人物与主应——坎＝中男（次子）·事业官运与肾泌尿；坤＝母亲（女主人）·脾胃与家宅安稳；震＝长男·肝胆与功名冲动；巽＝长女·感情人缘与胆；乾＝父亲（长辈）·头脑权威与官非；兑＝少女·肺与口舌桃花；艮＝少男（幼子）·脾胃学业与阻隔；离＝中女·心眼与文书名声。
- `loreOf(key, palace)` 重写为四段式：`坎宫（正北·中男位）· 五鬼凶星｜做法：… 影响：… 家人主应：少男（幼子），脾胃、学业与阻隔受此方影响最直接。`
- 变化点：原先 8 条通用说法只按「星」给建议，现在按「宫×星」落到具体家人与具体事类；八宅页点宫、化解卡、家人配房共用同一段文案，口径统一。

**2. AR：点画面即出该方位结论（`pages/ar`）**

- 新增全屏透明 `cover-view` 拾取层（压在 HUD 之下，不挡返回/拍照/校北）：点击位置按「水平视场 62°」换算成镜头偏角，右为正、左为负，得到所点方位角。
- `applyPick()` 一次给出四件事：二十四山与坐向、该度分金（甲子·等级）、该方八宫主应形煞（复用 `sha.resolveShaByHeading`）、以及该煞的化解建议；无犯煞则标绿「此方不犯主应形煞」。
- 画面出现金色竖标（点在哪就标在哪），底部弹出结论卡：方位角 · 坐向 / 分金 / 形煞（红绿分色）/ 化解；卡内「← 左寻 / 右寻 →」每次步进 7.5°（半个山），不依赖点击坐标也能逐山巡看；右上「×」关闭。
- 兼容处理：部分机型 `cover-view` 的 tap 不带坐标，此时退回靶心（屏幕中心）方位，功能不失效。

回归：67 项（新增八宅逐宫断语 1 组：角色齐备、宫宫带家人主应、坎落中男、艮落少男），全部通过；五条校验全绿。

**二十四、长卷排版升级：双栏小楷 + 竖排卷名 + 双印 + 自动分卷**

原先「生成长卷图片」是单栏横排：卷首居中一行、正文一字一行排到底（28 字折行），印章单枚。内容一整卷约 5500px 高，字小而密，手机上看着像清单。

改为独立的绘制模块 `utils/scroll-painter.js`（纯 Canvas 2D，无 DOM 依赖），页面只负责建画布与出图：

- **版式常量化**：`LAYOUT` = W 750 / pad 46 / 小楷 20px / 行距 32 / 双栏间距 34 / 章间距 26 / 首页卷首 250 / 续页页眉 130 / 卷尾 170 / 单页上限 1900。
- **折行**：`wrap` 按列宽切句，中文算 1 格、ASCII 算 0.55 格，中英混排不再断在数字中间；`visWidth` 供单测校验。
- **量版**：`measure` 先把每章正文折成行，再按双栏均分（`ceil(总行/2)` 左栏、其余右栏），算出章块高度与整卷高。
- **分卷**：`paginate` 逐章装页，单页不超过 1900（dpr 2 时物理 3800，留足平台余量），章块不拆开；首页带卷首与总纲，续页用紧凑页眉「天机长卷 · 续 / 第 n / N 页」。实测十三门整卷 4 页（1770 / 1652 / 1762 / 1232）。
- **画面**：宣纸渐变 + 确定性纸纹（同一份内容每次导出纹理一致）+ 上下暗角；朱丝栏外框双线、中缝双栏界栏；卷首右侧**竖排**「天机长卷」与「演象时空」小字；每章「第 N 章 + 标题 + 双横线」，正文双栏小楷；卷尾双线 + 两句免责 + **朱文「演象」与白文「时空」双印**（白文为红底白字）+ 右下日期与页码。
- **出图**：`pages/tianji` 逐页改画布尺寸（`dpr = min(2.5, pixelRatio)`）后依次 `canvasToTempFilePath`；单页直接存相册，多页转预览（长按逐张保存），避免反复弹相册权限。失败链路仍是「存相册 → 预览 → 复制全文」三级兜底。
- 页面里原有的 `drawPaper/drawZhuSiLan/drawSeal` 三个内联函数已删除，绘制口径统一到 painter，天机页与后续复用同一套版式。

回归：68 项（新增长卷排版 1 组：折行不超宽不空行、整卷自动分页、每页不超高且页码递增、首页带总纲续页不带、分页后章数守恒且章号不重复），全部通过；五条校验全绿。
