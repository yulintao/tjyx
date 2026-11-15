# 品牌与标识迁移：com.yanxiang.compass → com.tjyx.compass

本次把 `yanxiang` 全部替换为 `tjyx`，覆盖 iOS 工程、Android 工程、官网、脚本与文档。代码侧已改完，但**有若干步骤只能在开发者后台/商店后台完成**，下面分开写清楚。

## 一、代码侧已改（39 + 7 个文件，共 373 处）

### iOS

| 位置 | 改动 |
|---|---|
| `project.pbxproj` | 三个 target 的 `PRODUCT_BUNDLE_IDENTIFIER`：`com.tjyx.compass` / `.widget` / `.tests` |
| `Info.plist` | URL Scheme `com.tjyx.compass`、`com.tjyx.compass.almanac` |
| `LocalizationManager.swift` | App Group `group.com.tjyx.compass`；英文/印尼语文案里品牌名 `TianJi YanXiang` → `TianJi TJYX`（含隐私政策、协议、水印、VIP 标题等 29 处） |
| `StoreKitIAPManager.swift` | 4 个商品 ID 改为 `com.tjyx.compass.*`；keychain account 改为 `com.tjyx.compass.iap.seal.key`；历史 ID 映射同步为 `com.tjyx.luopan.*` |
| `SceneDelegate.swift` | 通知名、快捷指令 ID `com.tjyx.compass.shortcut.*` |
| `www/index.html` | 内置网页内的商品 ID、品牌文案 |
| `SceneDelegate` / AR / Floorplan / 引擎 | 深链与调试用 bundle 引用 |
| 8 个 `.lproj/InfoPlist.strings` | 英/印尼桌面显示名统一为 `TianJi TJYX`；中/日/韩/泰/越仍为本地化名称 |

### Android

| 位置 | 改动 |
|---|---|
| `app/build.gradle` | 签名库 `tjyx.jks`、环境变量 `TJYX_STORE_PASSWORD` / `TJYX_KEY_ALIAS` / `TJYX_KEY_PASSWORD`、APK 名 `tjyx-v*.apk` |
| 磁盘文件 | `yanxiang.jks` → `tjyx.jks`；`yanxiang-v1.2.4.apk`、`-debug.apk` → `tjyx-*`（这两个 APK 不在 git 里，仅本机改名） |
| Kotlin 引擎 / `strings.xml` / `i18n.json` / `yiijing_map.html` | 商品 ID、品牌文案 |

### 官网与文档

`website/i18n/en|id` 六个页面（首页/隐私/订阅条款/支持/联系/产品概览）、`README.md`（含商品价格表同步为 199 / 399）、`docs/`、`.github/workflows`（`APP_BUNDLE_ID` / `WIDGET_BUNDLE_ID` / 模拟器 bundle）、`.github/scripts/capture_ipad_screenshots.py`、`tools/package_ipa.py`、`tools/serve_ios_web.py`、`build_ios.ps1`、`setup_and_build.ps1`。

## 二、必须去后台做的事（代码改不了）

1. **Apple Developer 后台**
   - 新建 App ID：`com.tjyx.compass`、`com.tjyx.compass.widget`（含 App Groups 能力）
   - 新建 App Group：`group.com.tjyx.compass`，两个 App ID 都勾上
   - 重新生成描述文件（`build-ios.yml` 会用 `TEAM_ID.com.tjyx.compass` 校验，不匹配会直接失败）
   - 注意：仓库里**没有 .entitlements 文件**，App Group 能力目前在 Xcode 工程的 Signing & Capabilities 里配置，换组后需要在 Xcode 里重新勾选一次
2. **App Store Connect**
   - 新 App（Bundle ID `com.tjyx.compass`）下重建 4 个内购：`com.tjyx.compass.vip.yearly`（199/年）、`.pro.lifetime`（399，非消耗）、`.floorplan.case`（19.9）、`.tianji.single`（9.9）
   - 商品 ID 不能复用旧 App 的，老商品的购买记录不会迁移过来
3. **GitHub Actions secrets**
   - 仓库/环境变量里的 `YANXIANG_STORE_PASSWORD`、`YANXIANG_KEY_ALIAS`、`YANXIANG_KEY_PASSWORD` 需改成 `TJYX_*`，否则安卓 release 会退化为未签名包
4. **安卓商店后台**（华为/小米/Google Play 等）
   - 应用包名仍是 `com.example.yiijingcompass`（本次不在替换范围，因为它不含 yanxiang），但内购商品 ID 已改成 `com.tjyx.*`，需在对应后台重建商品并同步价格

## 三、这次改名会带来的实际影响

- **老用户购买全部失效**：bundle id 与商品 ID 同时变更，StoreKit 无法为新 App 拉取旧商品，`Restore Purchases` 对新 App 无效。若需要平滑过渡，唯一办法是保留旧 bundle id 继续发版，或在新版内做「凭旧账号人工补偿」。
- **快捷指令/小组件失效**：`com.tjyx.compass.shortcut.*` 与 App Group 都变了，用户已创建的快捷指令和桌面小组件需要重新添加。
- **已存数据读不到**：App Group 换了，旧组里的家庭档案、户型草稿、偏好设置不会自动出现在新组下。
- **安卓已购商品同理**：`com.tjyx.luopan.*` 是全新商品 ID，历史订单不再匹配。

如果这些不是你想要的结果，正确做法是只换显示品牌、保留 `com.yanxiang.compass` 的 bundle id 与商品 ID；需要那样的话告诉我，我可以把 iOS 侧回滚成「仅文案改名」。

## 四、验证建议

- `grep -ri yanxiang` 全仓应为 0 命中（`.git`、`build/`、`.tmp_scripts`、`dist-ios` 除外，这些是历史产物）
- 编译前先在 Xcode 的 Signing & Capabilities 里确认新 Bundle ID 与 App Group 已生效
- 沙盒购买：4 个商品逐个走一遍，确认 `displayPrice` 与权益

生成时间：2026-11-15

## 五、Logo 替换（2026-11-15 追加）

新图标以用户提供的 SVG 为母版重绘：青绿渐变底（#2FB5A8 → #136F73）、白色圆头折线房屋、金黄渐变沙发、右上角星芒。

为什么是「重绘」而不是直接转存：原 SVG 把圆角（rx=230）画进了图里，而 iOS 与安卓自适应图标都由系统自己裁形，直接使用会在四角露出透明缺口。因此母版改成满版无圆角，圆角只在安卓 legacy 图标与网页图标上按比例裁。

| 平台 | 产物 |
|---|---|
| iOS | `AppIcon.appiconset` 18 个切片全部覆盖，1024 主图满版无 alpha |
| 安卓 legacy | 5 档密度 `ic_launcher.png`（圆角方片）+ `ic_launcher_round.png`（圆形） |
| 安卓自适应 | `ic_launcher_foreground.png` 432×432 透明前景（按 108dp 画布 1:1 映射，图形约占 58%，落在中心安全区内）；`ic_launcher_background.xml` 由深黑 `#121216` 改为青绿渐变 |
| 网页 | 内嵌 www 与官网各一套 `icon-512 / icon-192 / apple-touch-icon / favicon-32 / favicon-16` |

生成脚本按 4096 超采样后降采样，保证 20pt 小图标不糊。