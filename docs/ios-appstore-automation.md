# appstore_setup.py 配置说明

`tiandi_luopan/tools/appstore_setup.py`，Python 3.9+，唯一外部依赖是 `cryptography`
（ES256 签名与 PKCS#8 解析）：

```powershell
python -m pip install cryptography
```

默认 dry-run，加 `--apply` 才真的写 Apple 账户与 GitHub。原来那版 PowerShell 脚本已删除，
避免两份实现漂移。

## 三个作用与实现

**1. 用 API 密钥登录 App Store Connect，为每个 App 建唯一的 Bundle ID 及配套资源**

API 密钥就是「登录」。脚本对每个 App 依次做：查 Bundle ID 是否已存在（存在就复用，不重复建）→
不存在则新建 → 挂 `APP_GROUPS` 能力 → 把配置里的设备 UDID 登记进账户 →
签发开发描述文件（含设备）与 App Store 描述文件（不含设备）。

「唯一」有两层保证：账户侧按 `filter[identifier]` 查，同 ID 不会建第二份；配置侧有守卫，
同一份配置里 `bundleId` 出现两次直接退出——

```
配置里 Bundle ID 重复：com.tjyx.compass。每个 App 的 Bundle ID 必须唯一。
```

**2. 导出到本地，并把值写进 GitHub**

产物落在 `tools/appstore_out/`：

| 文件 | 内容 |
|---|---|
| `com_tjyx_compass.dev.mobileprovision` / `.b64` | 开发描述文件及其 base64 |
| `com_tjyx_compass.appstore.mobileprovision` / `.b64` | 发布描述文件及其 base64 |
| `manifest.json` | 本次建/复用了什么：App ID 的 id、能力是否挂上、两个描述文件 id、产物文件名 |

`manifest.json` 是给你对账用的：下次再跑，看它就知道哪步被跳过、哪步被复用。

`github` 子命令把这些写进仓库，名字与 `build-ios.yml` 实际引用的一致：

| 类型 | 名字 |
|---|---|
| secret | `APPLE_TEAM_ID`、`APPSTORE_ISSUER_ID`、`APPSTORE_API_KEY_ID`、`APPSTORE_API_PRIVATE_KEY`、`DEV_CERTIFICATE_P12`、`DIST_CERTIFICATE_P12`、`DIST_P12_PASSWORD`、`DEV_PROVISION_PROFILE`、`DIST_PROVISION_PROFILE` |
| variable | `APP_GROUP_ID`、`IOS_RUNNER_LABEL` |
| environment | `ios-build`（构建 job 目前没引用，建给以后的发布保护规则用） |

> 这一行以前是 `DEV_CERTIFICATE_P` / `DIST_CERTIFICATE_P` / `P`——键名被截断，workflow 读的是
> `..._P12` 与 `DIST_P12_PASSWORD`，所以那三个 secret 从来没被真正写对过。现在由
> `build_secret_bundle()` 一处生成，键名不再散落在四处。

没有 gh 时 `github` 不再直接失败：它退化成导出 `appstore_out/github_secrets.json`
（按 secret / variable 分组）+ `appstore_out/apply_github_secrets.ps1`（每条值单独一个
`github_secret_files/<NAME>.txt`，脚本逐条 `gh secret set --body-file` 喂进去，绕开命令行长度与引号问题）。

多 App 时 GitHub 只取第一个 App 的两个描述文件，因为本仓库只构建一个 App；脚本会警告。

**3. 配置说明**

就是这份文档。

## 配置字段

复制 `appstore_setup.config.example.json` 成 `appstore_setup.config.json` 再改。

| 字段 | 必填 | 说明 |
|---|---|---|
| `teamId` | 是 | Apple Team ID，10 位。本账户实测是 `9ZK328P458`（证书 CN 里的 `W6QFD6Y86F` 不是团队号） |
| `apiKeyId` | 是 | App Store Connect → 用户和访问 → 密钥 里的 Key ID |
| `issuerId` | 是 | 同页面的 Issuer ID，形如 UUID |
| `apiKeyPath` | 是 | 下载的 `AuthKey_XXXX.p8` 本地绝对路径。**只能下载一次**，丢了就得重新生成 |
| `githubRepo` | 是 | `owner/repo`，现在 `yulintao/tjyx` |
| `githubEnvironment` | 否 | 要创建的 environment 名，默认 `ios-build` |
| `runnerLabel` | 否 | 写进 `IOS_RUNNER_LABEL` 变量；不填则沿用 workflow 默认 `xcode-27` |
| `certP12Base64Dev` | 否 | 开发证书 `.p12` 的 base64；`github` 子命令用它填 `DEV_CERTIFICATE_P12` |
| `certP12Base64Dist` | 否 | 发布证书 `.p12` 的 base64，填 `DIST_CERTIFICATE_P12` |
| `certP12Password` | 否 | 旧字段，保留兼容 |
| `p12Password` | 否 | 当前 `.p12` 的密码，`github` / `secrets` 用它填 `DIST_P12_PASSWORD` |
| `writeAppGroupVariable` | 否 | 默认 `false`：工程没有 entitlements 时把 `APP_GROUP_ID` 留空，填了会让构建硬失败 |
| `apps[]` | 是 | 一个或多个 App；也可退化为顶层单 App 写法（`bundleId` / `appName` / `appGroup` / `devProfileName` / `distProfileName` / `devices` 平铺） |
| `apps[].bundleId` | 是 | 唯一 Bundle ID，如 `com.tjyx.compass` |
| `apps[].appName` | 否 | 显示在 portal 上的名字，缺省取 `bundleId` |
| `apps[].appGroup` | 否 | 该 App 的 App Group，缺省取顶层 `appGroup` |
| `apps[].devProfileName` | 否 | 开发描述文件名，缺省 `com_tjyx_compass_dev` |
| `apps[].distProfileName` | 否 | 发布描述文件名，缺省 `com_tjyx_compass_appstore` |
| `apps[].devices` | 否 | 要登记的设备 UDID 数组；空数组也能签发布描述文件 |

## 运行顺序

```powershell
Copy-Item tools\appstore_setup.config.example.json tools\appstore_setup.config.json

# 1) 只读：校验配置 + 用你的 .p8 签一次 JWT + 查每个 App 是否已建档
python tools\appstore_setup.py check

# 2) 看计划：POST 只打印 body，不发出去
python tools\appstore_setup.py provision

# 3) 执行：建档、挂能力、签描述文件、写 manifest.json
python tools\appstore_setup.py provision --apply --add-devices

# 4) 写 GitHub：先看它要 set 哪些名字（私钥值只打印字符数）
python tools\appstore_setup.py github
python tools\appstore_setup.py github --apply

# 4') 没有 gh 也行：导出清单与可执行脚本
python tools\appstore_setup.py secrets --apply
```

`github` 子命令需要 GitHub CLI：`winget install --id GitHub.cli -e`，然后 `gh auth login`。
脚本用 `shutil.which` 找 gh，`.exe` 与 `.cmd` 两种落地形式都能用。没有 gh 时它自动退回
`secrets`，产物见上一节。

已经手工在 portal 下载了描述文件（比如 API 密钥还没就绪时），可以直接指过去，跳过 `provision`：

```powershell
python tools\appstore_setup.py github --dev-profile .\tjyx_development.mobileprovision
python tools\appstore_setup.py github --apply --dev-profile .\tjyx_development.mobileprovision
```

推之前它会读这个文件里的 plist 并核对：App ID 是否覆盖当前 Bundle ID（不覆盖直接拒绝，
这正是 `Profile App ID does not cover` 那次失败的原因）、Team 是否一致、
有没有带上配置里的 App Group、含几台设备。拒绝对话长这样：

```
==> 描述文件 old.mobileprovision
    Name=yulintao_test  UUID=53bf2cee-...  AppID=W6QFD6Y86F.com.yanxiang.compass
    设备 1 台  get-task-allow=True  App Group=['group.com.yanxiang.compass']
这个描述文件的 App ID 是 W6QFD6Y86F.com.yanxiang.compass，覆盖不到 com.tjyx.compass。
在 portal 里为当前 Bundle ID 重新生成一个，再指过来。
```

## 需要你自己准备的两样东西

1. **App Store Connect API 密钥**（Admin 或 App Manager 角色，要能改 App ID 与描述文件）。
2. **证书 `.p12` 的 base64 与密码**，或者让 `appstore_bootstrap.py --create-certificates`
   在账户缺证书时当场生成一套。注意区分两件事：**新增**一张证书只是占用团队额度
   （发布证书通常上限 2 张），已有构建不受影响；**吊销**旧证书才会让那些构建无法再签名。
   `appstore_setup.py` 本身不建证书，只挑现有的。自己导出时的 base64 命令：

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes('cert.p12')) | Set-Clipboard
   ```

## 它不做的事

- 不创建证书、不生成 CSR（本机没有 openssl；`certreq` 产物容易变成垃圾证书）。
- 不上传构建、不提交审核。Windows 上没有 Transporter；上传由 CI 的 `upload_to_appstore` 开关负责。
  真要从命令行提交审核，需要另加 App Store Connect 的 `appStoreVersions` / `reviewSubmissions` 调用，
  那是下一步的事。

## 已验证 / 未验证

- 已验证：`py_compile` 与 `ast.parse` 都通过；JWT 签名格式与 claims 正确（真实 Key ID 下 200，
  占位符下 401）；双 App 配置展开成各自的描述文件名；重复 Bundle ID 会被拦下；`github` 在 gh 存在时
  按 `build_secret_bundle()` 的名字逐条 set，私钥值只显示字符数；凭证失效时 `provision` 给一句人话而不是 traceback。
- 已修正：描述文件 App ID 核对失败时直接退出并给出重建指引（`Profile App ID does not cover` 那次失败的原样复现）。
- 未验证：`APP_GROUPS` 能力的公开 API 形态（已确认被 409 拒绝，见文末「真实账户」一节）。

## 一条命令建齐新 App：appstore_bootstrap.py

`appstore_setup.py` 是做单件事的工具，`appstore_bootstrap.py` 是把它们串成「新 App 建档」的流程，
并补上两件 setup 里没有的能力：生成证书、建 App 记录。

```powershell
python tools\appstore_bootstrap.py selfcheck   # 离线验证 证书→.p12 链路，不联网
python tools\appstore_bootstrap.py             # 打印全流程计划，不发写请求
python tools\appstore_bootstrap.py --apply --create-certificates --create-app-record
```

顺序与每步的产物：

| 步骤 | 做什么 | 失败时 |
|---|---|---|
| 1 | Bundle ID（存在则复用） | 查不到就退出，因为后续都要它的 id |
| 2 | 挂 `APP_GROUPS` 能力 | 公开 API 恒定 409（只收 ICLOUD_VERSION 等三键），只警告；需要就去 portal 手点 |
| 3 | 登记设备 UDID（`--add-devices`） | 缺设备只警告，不影响发布描述文件 |
| 4 | 证书：账户缺可用证书时生成（`--create-certificates`） | 额度满（发布证书常见上限 2 张）只警告，提示去吊销旧的 |
| 5 | 开发描述文件 + App Store 描述文件 | 没有对应证书就跳过；建完会核对 App ID 是否等于 `<teamId>.<bundleId>` |
| 6 | App 记录（`--create-app-record`，需 `sku`） | API 恒定 403（apps 不支持 CREATE），只警告，去网页建；`check` 会提示还缺不缺 |
| 7 | 落 `manifest.json` | — |
| 8 | 写 GitHub secrets / variables / environment（`--skip-github` 可关） | gh 缺失时提示安装 |

**公开 API 建不出来的三样**，只能 portal 手点（不是脚本偷懒，是端点不存在）：

1. **App Group 这个实体**。API 只能在 Bundle ID 上挂 `APP_GROUPS` 能力并引用组名，
   但 `Identifiers → App Groups` 里那条 `group.com.tjyx.compass` 得自己建。
   注意这个能力本身 API 也挂不上（`settings/0/key` 只认 ICLOUD_VERSION /
   DATA_PROTECTION_PERMISSION_LEVEL / APPLE_ID_AUTH_APP_CONSENT），得在 portal 手点。
2. **StoreKit 商品与订阅**。价格、周期、审核信息都在 portal 里配。
3. **App Store 版本页面的截图、描述、隐私问卷**。API 有 `appStoreVersions`，
   但截图上传与本地化元数据的完整流程复杂度远超这个脚本的范围。
4. **「我的 App」那条记录**。`POST /v1/apps` 返回 403，只能网页建一次。

`sku` 与 `primaryLocale` 加在 `apps[]` 条目里（`sku` 是 App 记录必填，缺省会用
`bundleId-时间戳` 兜底，但不建议）。

## 在真实账户上跑出来的三件事（2026-11-16）

脚本的假设被真实账户逐条校验过，下面三条是**公开 API 的硬限制**，不是脚本 bug，也不是权限没开够：

**1. `POST /v1/apps` 不能建 App 记录**

```
403 FORBIDDEN_ERROR
The resource 'apps' does not allow 'CREATE'. Allowed operations are: GET_COLLECTION, GET_INSTANCE, UPDATE
```

密钥是 Admin 级别；端点本身只开放 GET/UPDATE。所以「我的 App」里那条记录必须去
App Store Connect 网页 → App → 新建 App 手建**一次**。表单四项：平台 iOS、名称、
主要语言、套装 ID、SKU。`check` 会先告诉你到底缺不缺这条记录。

命名有个坑：`天机演象` 会被判重——账户里已有的 `天機演象`（`com.yanxiang.compass`）
在苹果那边算同一个名字，报「你输入的 App 名称已经用于你账户中的其他 App」。
本轮建记录时用了 `天机演象罗盘`；App 名称在「App 信息」里随时可改，不影响上传。

**2. `/v1/bundleIdCapabilities` 不接受 `APP_GROUPS`**

```
409 ENTITY_ERROR.ATTRIBUTE.TYPE
'groups' is not a valid value for the attribute 'settings/0/key'.
Expected one of: 'ICLOUD_VERSION', 'DATA_PROTECTION_PERMISSION_LEVEL', 'APPLE_ID_AUTH_APP_CONSENT'
```

也就是说 App Groups 能力只能在 portal 的 Identifiers → Capabilities 手点。
工程没有 entitlements、也不读写共享容器时，跳过它不影响出包——本轮就是这么过的。

**3. `GET /v1/bundleIds?filter[identifier]=X` 是模糊匹配**

账户里同时有 `com.tjyx.compass`（id `FB9FYFP4W6`，名字 `tjyx`）和
`com.tjyx.compass.9ZK328P458`（id `2H2YWNVQPA`）时，它把带团队后缀的排在前面返回。
按 `data[0]` 取就会把描述文件绑到错的 App ID 上，包签不上、上传还报 App not found。
`get_bundle_id()` 现在自己再按 `identifier` 全等过滤一次；描述文件生成后用
`read_profile_metadata()` 核对 `application-identifier` 必须是
`<teamId>.<bundleId>`——本轮实测两边都是 `9ZK328P458.com.tjyx.compass`。

证书列表接口偶尔不回 `status` 字段，直接取 `c["attributes"]["status"]` 会 KeyError 把
整条链路弄断；`cert_usable()` 把「缺 status 视为可用 + 按到期日过滤」收在一处。

## 已验证 / 未验证

- 已验证（真实账户）：JWT 用真实 Key ID `V8HURHGAZC` 签发通过；`check` 能列出 Bundle ID、
  证书、描述文件与 App 记录；`bootstrap --apply --create-certificates` 建出发布证书
  `Q9UX2L7L2J` 并落 `.p12` + `.b64`；App Store 描述文件 `D77TW36ZQ7` 建出且 App ID 正确；
  `secrets --apply` 导出 8 secret + 1 variable；App 记录在网页建好后 `check` 能读到。
- 已验证（本条尚未跑完）：`app-store` 模式在 GitHub Actions 上签名 → 导出 → 上传 TestFlight
  的端到端链路，结果见 `docs/ios-refactor-no-compass-status.md`。
- 未验证：`POST /v1/apps` 在将来若开放 CREATE（目前明确不支持，脚本保留该分支但会 403）；
  `APP_GROUPS` 能力的公开 API 形态。
