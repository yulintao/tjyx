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
| secret | `APPLE_TEAM_ID`、`APPSTORE_ISSUER_ID`、`APPSTORE_API_KEY_ID`、`APPSTORE_API_PRIVATE_KEY`、`DEV_CERTIFICATE_P`、`DIST_CERTIFICATE_P`、`P`、`DEV_PROVISION_PROFILE`、`DIST_PROVISION_PROFILE` |
| variable | `APP_GROUP_ID`、`IOS_RUNNER_LABEL` |
| environment | `ios-build`（构建 job 目前没引用，建给以后的发布保护规则用） |

多 App 时 GitHub 只取第一个 App 的两个描述文件，因为本仓库只构建一个 App；脚本会警告。

**3. 配置说明**

就是这份文档。

## 配置字段

复制 `appstore_setup.config.example.json` 成 `appstore_setup.config.json` 再改。

| 字段 | 必填 | 说明 |
|---|---|---|
| `teamId` | 是 | Apple Team ID，10 位。现在的值是 `W6QFD6Y86F` |
| `apiKeyId` | 是 | App Store Connect → 用户和访问 → 密钥 里的 Key ID |
| `issuerId` | 是 | 同页面的 Issuer ID，形如 UUID |
| `apiKeyPath` | 是 | 下载的 `AuthKey_XXXX.p8` 本地绝对路径。**只能下载一次**，丢了就得重新生成 |
| `githubRepo` | 是 | `owner/repo`，现在 `yulintao/tjyx` |
| `githubEnvironment` | 否 | 要创建的 environment 名，默认 `ios-build` |
| `runnerLabel` | 否 | 写进 `IOS_RUNNER_LABEL` 变量；不填则沿用 workflow 默认 `xcode-27` |
| `certP12Base64Dev` | 否 | 开发证书 `.p12` 的 base64；`github` 子命令用它填 `DEV_CERTIFICATE_P` |
| `certP12Base64Dist` | 否 | 发布证书 `.p12` 的 base64，填 `DIST_CERTIFICATE_P` |
| `certP12Password` | 否 | `.p12` 导出时的密码，填 `P` |
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
```

`github` 子命令需要 GitHub CLI：`winget install --id GitHub.cli -e`，然后 `gh auth login`。
脚本用 `shutil.which` 找 gh，`.exe` 与 `.cmd` 两种落地形式都能用。

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

- 已验证：`py_compile` 与 `ast.parse` 都通过；用临时生成的 P-256 私钥签出的 JWT 真的打到了
  `api.appstoreconnect.apple.com`，返回 401（因为不是你的密钥），说明签名格式与 claims 正确；
  双 App 配置展开成各自的描述文件名；重复 Bundle ID 会被拦下；`github` 在 gh 桩存在时
  正确打印 9 个 secret、2 个 variable、1 个 environment 的计划，且私钥值只显示字符数；
  凭证失效时 `provision` 给一句人话而不是 traceback。
- 未验证：`POST /v1/bundleIdCapabilities` 的 `APP_GROUPS` payload 字段格式，只能在你账户上第一次跑才知道。
  被拒时脚本只警告不中断，App Group 那一步退回 portal 手点一次即可，其余照旧自动化。

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
| 2 | 挂 `APP_GROUPS` 能力 | 只警告；组本身要 portal 建 |
| 3 | 登记设备 UDID（`--add-devices`） | 缺设备只警告，不影响发布描述文件 |
| 4 | 证书：账户缺可用证书时生成（`--create-certificates`） | 额度满（发布证书常见上限 2 张）只警告，提示去吊销旧的 |
| 5 | 开发描述文件 + App Store 描述文件 | 没有对应证书就跳过 |
| 6 | App 记录（`--create-app-record`，需 `sku`） | 只警告，不影响前面几步 |
| 7 | 落 `manifest.json` | — |
| 8 | 写 GitHub secrets / variables / environment（`--skip-github` 可关） | gh 缺失时提示安装 |

**公开 API 建不出来的三样**，只能 portal 手点（不是脚本偷懒，是端点不存在）：

1. **App Group 这个实体**。API 只能在 Bundle ID 上挂 `APP_GROUPS` 能力并引用组名，
   但 `Identifiers → App Groups` 里那条 `group.com.tjyx.compass` 得自己建。
2. **StoreKit 商品与订阅**。价格、周期、审核信息都在 portal 里配。
3. **App Store 版本页面的截图、描述、隐私问卷**。API 有 `appStoreVersions`，
   但截图上传与本地化元数据的完整流程复杂度远超这个脚本的范围。

`sku` 与 `primaryLocale` 加在 `apps[]` 条目里（`sku` 是 App 记录必填，缺省会用
`bundleId-时间戳` 兜底，但不建议）。

## 已验证 / 未验证

- 已验证：`appstore_setup.py` 与 `appstore_bootstrap.py` 都能编译；用临时 P-256 私钥签出的 JWT
  真的打到 `api.appstoreconnect.apple.com`，返回 401（因为不是真实 Key ID），说明签名格式正确；
  多 App 展开、重复 Bundle ID 拦截、`github` 的计划输出（9 secret / 2 variable / 1 environment，
  私钥与证书值只显示字符数）都通过；`selfcheck` 证明 RSA 2048 → 自签证书 → PKCS#12 → 回读可用；
  用一个假客户端把 bootstrap 的 8 步编排在 dry-run 下跑通并落出 manifest。
- 未验证：`POST /v1/bundleIdCapabilities` 的 `APP_GROUPS` payload 格式；`POST /v1/apps`
  建 App 记录的字段要求（sku 是否必填、是否需要 `platform`）。这两处只能在你账户上首跑才知道，
  失败都只警告不中断，按报错补字段即可。
