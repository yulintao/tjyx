# 开发者账户与 GitHub 配置脚本（appstore_setup.ps1）

这一份脚本解决的是「改名之后签名链断了」这类配置问题：工程已经叫 `com.tjyx.compass`，
而 secret 里的描述文件还是 `com.yanxiang.compass`。以前这类事只能在两个网站上手点，
现在一条命令做完，并且默认只打印计划。

## 它做什么

| 子命令 | 作用 |
|---|---|
| `-Command check` | 校验配置、签发一次 JWT 证明鉴权链通、查 App ID / 证书 / gh 是否就绪 |
| `-Command provision` | 确保 App ID 存在、挂上 App Group 能力、登记设备、签发开发与发布描述文件，并把描述文件存成 `.mobileprovision` 与 `.b64` |
| `-Command github` | 把上面产出的 base64 与团队号、密钥写给 GitHub：secrets、variables、environment |

## 它不做什么（故意的）

- **不创建证书**。证书一旦重建，同一 Team 下旧构建的签名链就断了，而且会在账户里堆孤儿证书。
  脚本只从账户里挑一张 `ACTIVE` 的证书来签描述文件。证书 `.p12` 的 base64 与密码要你自己导出后填进配置。
- **不造 CSR**。本机没有 openssl，PowerShell 也没有原生的 RSA CSR 生成；用 `certreq` 拼出来的
  中间产物很容易变成垃圾证书。真需要新证书时，走 portal 手动流程。
- **不上传构建**。Windows 上没有 Transporter，`altool` 也不存在；上传由 CI 的
  `upload_to_appstore` 开关负责（workflow 第 10 步）。脚本只保证 CI 有东西可签。

## 需要的凭据

1. **App Store Connect API 密钥**：App Store Connect → 用户和访问 → 密钥 → 生成，角色选 **Admin**
   或 App Manager（要能改 App ID 与描述文件）。下载 `AuthKey_XXXXXXXXXX.p8`，只给一次。
   记下 **Key ID** 与 **Issuer ID**。
2. **一张已存在于账户里的签名证书**：从本机钥匙串导出的 `.p12`，base64 后填进配置的
   `certP12Base64Dev` / `certP12Base64Dist`，密码填 `certP12Password`。
3. **GitHub CLI**（`github` 子命令用）：`winget install --id GitHub.cli -e`，
   然后 `gh auth login`，token 需 `repo` + 写 secret 的权限（classic token 勾 `repo`，或 fine-grained 勾
   Secrets/Variables 写权限）。

## 用法

```powershell
# 1. 复制配置骨架，填上 teamId / bundleId / appGroup / apiKey* / githubRepo
Copy-Item tools\appstore_setup.config.example.json tools\appstore_setup.config.json

# 2. 先看：不写任何东西
pwsh -File tools\appstore_setup.ps1 -Command check

# 3. 看它打算发哪些请求（POST 只打印 body）
pwsh -File tools\appstore_setup.ps1 -Command provision

# 4. 真正执行；产出在 tools\appstore_out\
pwsh -File tools\appstore_setup.ps1 -Command provision -Apply
pwsh -File tools\appstore_setup.ps1 -Command provision -Apply -AddDevices

# 5. 写进 GitHub（先不带 -Apply 看清楚它要 set 哪些名字）
pwsh -File tools\appstore_setup.ps1 -Command github
pwsh -File tools\appstore_setup.ps1 -Command github -Apply
```

`devices` 数组填要加入开发描述文件的设备 UDID。不填也能签发布描述文件（`IOS_APP_STORE` 不需要设备）。

## 与 workflow 的对应关系

脚本写的名字就是 `build-ios.yml` 里实际引用的那些：

| 类型 | 名字 |
|---|---|
| secret | `APPLE_TEAM_ID`、`APPSTORE_ISSUER_ID`、`APPSTORE_API_KEY_ID`、`APPSTORE_API_PRIVATE_KEY`、`DEV_CERTIFICATE_P`、`DIST_CERTIFICATE_P`、`P`、`DEV_PROVISION_PROFILE`、`DIST_PROVISION_PROFILE` |
| variable | `APP_GROUP_ID`、`IOS_RUNNER_LABEL` |
| environment | `ios-build`（构建 job 目前没引用，建它是给之后的发布保护规则留位置） |

小组件相关的三个 secret（`DEV_WIDGET_PROVISION_PROFILE`、`DIST_WIDGET_PROVISION_PROFILE`、`WIDGET_PROVISION_PROFILE`）
在 target 删掉后已经不需要了；workflow 也会在工程里找不到 `TiandiLuopanWidget.appex` 时跳过相关逻辑。
老 secret 留着不会报错，想清可以去 Settings 里删。

## 已验证与未验证

- 已验证：脚本语法可解析；JWT 用一把临时生成的 P-256 私钥真的签出来了，请求打到了
  `api.appleconnect` 并返回 401（因为密钥不是你的）——说明签名格式、header、claims 都对。
- 未验证：`POST /v1/bundleIdCapabilities` 的 `APP_GROUPS` payload 字段格式，只能在你账户上第一次跑
  才知道苹果接受不接受；如果被拒，脚本会把苹果的错误原文打出来，App Group 那一步退回 portal 手点也只需一次。
