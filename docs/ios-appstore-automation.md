# appstore_setup.ps1 配置说明

`tiandi_luopan/tools/appstore_setup.ps1`，PowerShell 7，无第三方依赖。默认 dry-run，
加 `-Apply` 才真的写 Apple 账户与 GitHub。

## 三个作用与实现

**1. 登录 App Store Connect，为每个 App 建唯一的 Bundle ID 及配套资源**

API 密钥就是「登录」。脚本对每个 App 依次做：查 Bundle ID 是否已存在（存在就复用，不重复建）→
不存在则新建 → 挂 `APP_GROUPS` 能力 → 把配置里的设备 UDID 登记进账户 →
签发开发描述文件（含设备）与 App Store 描述文件（不含设备）。

「唯一」有两层保证：账户侧按 `filter[identifier]` 查，同 ID 不会建第二份；
配置侧有守卫，同一份配置里 `bundleId` 出现两次直接抛错——

```
Exception: 配置里 Bundle ID 重复：com.tjyx.compass。每个 App 的 Bundle ID 必须唯一。
```

**2. 导出到本地，并把值写进 GitHub**

产物落在 `tools/appstore_out/`：

| 文件 | 内容 |
|---|---|
| `com_tjyx_compass.dev.mobileprovision` / `.b64` | 开发描述文件及其 base64 |
| `com_tjyx_compass.appstore.mobileprovision` / `.b64` | 发布描述文件及其 base64 |
| `manifest.json` | 本次建/复用了哪些东西：App ID 的 id、能力是否挂上、两个描述文件的 id、产物文件名 |

`manifest.json` 是给你对账用的：下次再跑，看它就知道哪个环节被跳过、哪个被复用。

`-Command github` 把这些写进仓库，名字与 `build-ios.yml` 实际引用的一致：

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
pwsh -File tools\appstore_setup.ps1 -Command check

# 2) 看计划：POST 只打印 body，不发出去
pwsh -File tools\appstore_setup.ps1 -Command provision

# 3) 执行：建档、挂能力、签描述文件、写 manifest.json
pwsh -File tools\appstore_setup.ps1 -Command provision -Apply -AddDevices

# 4) 写 GitHub：先看它要 set 哪些名字（值只打印长度）
pwsh -File tools\appstore_setup.ps1 -Command github
pwsh -File tools\appstore_setup.ps1 -Command github -Apply
```

`github` 子命令需要 GitHub CLI：`winget install --id GitHub.cli -e`，然后 `gh auth login`。

## 需要你自己准备的两样东西

1. **App Store Connect API 密钥**（Admin 或 App Manager 角色，要能改 App ID 与描述文件）。
2. **证书 `.p12` 的 base64 与密码**。脚本不创建证书——新建一张会让同一 Team 下已有构建的签名链失效，
   还会在账户里堆孤儿证书。base64 命令：

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes('cert.p12')) | Set-Clipboard
   ```

## 它不做的事

- 不创建证书、不生成 CSR（本机没有 openssl；`certreq` 产物容易变成垃圾证书）。
- 不上传构建、不提交审核。Windows 上没有 Transporter；上传由 CI 的 `upload_to_appstore` 开关负责。
  真要从命令行提交审核，需要另加 App Store Connect 的 `appStoreVersions` / `reviewSubmissions` 调用，
  那是下一步的事。

## 已验证 / 未验证

- 已验证：脚本可解析；用临时生成的 P-256 私钥签出的 JWT 真的打到了 `api.appstoreconnect.apple.com`
  并返回 401（因为不是你的密钥），说明签名格式与 claims 正确；多 App 配置能正确展开成各自的描述文件名；
  重复 Bundle ID 会被拦下。
- 未验证：`POST /v1/bundleIdCapabilities` 的 `APP_GROUPS` payload 字段格式，只能在你账户上第一次跑才知道。
  被拒时脚本只警告不中断，App Group 那一步退回 portal 手点一次即可，其余照旧自动化。
