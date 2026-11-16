#Requires -Version 7.0
<#
App Store 开发者账户与 GitHub 仓库的一次性配置脚本。

它替你做两件人工操作极易出错的事：
  1) 在开发者账户里把 App ID、App Group 能力、开发/发布描述文件配齐，
     并把描述文件转成 CI 需要的 base64；
  2) 把这些值写进 GitHub 的 secrets / variables / environment。

设计原则：
  * 默认 dry-run，只打印将要发出的请求，不发任何写操作；加 -Apply 才真正执行。
  * 不创建证书。证书与私钥一旦重建，线上构建的签名链就断了；脚本只在账户里
    挑一张已存在的证书来签发描述文件，并把「该复用哪个 secret」写清楚。
  * 不用 certutil/openssl 造 CSR——本机没有 openssl，而自动造 CSR 会在你账户里
    堆出一串孤儿证书。

用法（先看再做）：
  pwsh -File tools\appstore_setup.ps1 -Command check
  pwsh -File tools\appstore_setup.ps1 -Command provision
  pwsh -File tools\appstore_setup.ps1 -Command provision -Apply
  pwsh -File tools\appstore_setup.ps1 -Command github -Apply

配置在 tools\appstore_setup.config.json，从 .example.json 复制。
#>

[CmdletBinding()]
param(
    [ValidateSet('check', 'provision', 'github')]
    [string]$Command = 'check',

    [string]$ConfigPath = (Join-Path $PSScriptRoot 'appstore_setup.config.json'),

    # 不加该开关时所有写操作只打印、不执行
    [switch]$Apply,

    # 下载的描述文件与 base64 落盘位置
    [string]$OutDir = (Join-Path $PSScriptRoot 'appstore_out'),

    # 允许脚本在账户里登记新的设备 UDID（配置里 devices 数组）
    [switch]$AddDevices
)

$ErrorActionPreference = 'Stop'
$script:AscBase = 'https://api.appstoreconnect.apple.com'

function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Plan([string]$Message) { Write-Host "    [dry-run] $Message" -ForegroundColor DarkYellow }
function Write-Ok([string]$Message)   { Write-Host "    $Message" -ForegroundColor Green }
function Write-Warn2([string]$Message) { Write-Host "    $Message" -ForegroundColor Yellow }

# ---------------------------------------------------------------- 配置与鉴权

function Read-Config {
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "缺少配置文件：$ConfigPath。先从 tools\appstore_setup.config.example.json 复制一份并填好。"
    }
    $raw = [IO.File]::ReadAllText($ConfigPath)
    $cfg = $raw | ConvertFrom-Json
    foreach ($key in @('teamId', 'bundleId', 'appGroup', 'apiKeyId', 'issuerId', 'apiKeyPath', 'githubRepo')) {
        if (-not $cfg.$key) { throw "配置缺字段：$key" }
    }
    if (-not (Test-Path -LiteralPath $cfg.apiKeyPath)) {
        throw "找不到 API 私钥文件：$($cfg.apiKeyPath)（App Store Connect → 用户和访问 → 密钥 里下载的 AuthKey_*.p8）"
    }
    return $cfg
}

function ConvertTo-Base64Url([byte[]]$Bytes) {
    $b64 = [Convert]::ToBase64String($Bytes)
    return $b64.Replace('+', '-').Replace('/', '_').TrimEnd('=')
}

function New-AscJwt {
    param(
        [Parameter(Mandatory = $true)][string]$KeyId,
        [Parameter(Mandatory = $true)][string]$IssuerId,
        [Parameter(Mandatory = $true)][string]$P8Content,
        [int]$LifetimeSeconds = 1200
    )

    $pem = $P8Content -replace '-----BEGIN PRIVATE KEY-----', '' `
                       -replace '-----END PRIVATE KEY-----', '' -replace '\s', ''
    $pkcs8 = [Convert]::FromBase64String($pem)

    $ecdsa = [System.Security.Cryptography.ECDsa]::Create()
    try {
        $read = 0
        $ecdsa.ImportPkcs8PrivateKey($pkcs8, [ref]$read)
    }
    catch {
        throw "API 私钥不是 PKCS#8 格式的 EC 密钥（.p8 文件应是 ES256）。解析失败：$($_.Exception.Message)"
    }

    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $header = @{ alg = 'ES256'; kid = $KeyId; typ = 'JWT' } | ConvertTo-Json -Compress
    $claims = @{
        iss = $IssuerId
        iat = $now
        exp = $now + $LifetimeSeconds
        aud = 'appstoreconnect-v1'
    } | ConvertTo-Json -Compress

    $signingInput = (ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($header))) + '.' +
                    (ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($claims)))
    # IEEE P1363 就是 JWT 要的 r||s 拼接；DER 签名需要转换，这里直接取裸格式。
    $signature = $ecdsa.SignData(
        [Text.Encoding]::UTF8.GetBytes($signingInput),
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.DSASignatureFormat]::IeeeP1363FixedFieldConcatenation)
    return $signingInput + '.' + (ConvertTo-Base64Url $signature)
}

function Invoke-Asc {
    param(
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Path,
        $Body,
        [string]$Jwt
    )

    $headers = @{ Authorization = "Bearer $Jwt" }
    $uri = $script:AscBase + $Path
    if (-not $Apply -and $Method -in @('POST', 'PATCH', 'DELETE')) {
        Write-Plan "$Method $Path"
        if ($Body) { Write-Plan ($Body | ConvertTo-Json -Depth 8 -Compress) }
        return $null
    }
    $params = @{ Method = $Method; Uri = $uri; Headers = $headers }
    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 8 -Compress)
        $params.ContentType = 'application/json'
    }
    return Invoke-RestMethod @params
}

# ---------------------------------------------------------------- App Store 侧

function Get-BundleId($Jwt, $Identifier) {
    $filtered = Invoke-Asc -Method GET -Path "/v1/bundleIds?filter[identifier]=$Identifier" -Jwt $Jwt
    if ($filtered -and @($filtered.data).Count -gt 0) { return @($filtered.data)[0] }
    return $null
}

function New-BundleId($Jwt, $Cfg) {
    $body = @{
        data = @{
            type = 'bundleIds'
            attributes = @{
                identifier = $Cfg.bundleId
                name       = $Cfg.appName
                platform   = 'IOS'
            }
        }
    }
    return Invoke-Asc -Method POST -Path '/v1/bundleIds' -Body $body -Jwt $Jwt
}

function Set-AppGroupCapability($Jwt, $BundleIdId, $GroupId) {
    # App Group 能力在 API 里是「能力 + settings」两步结构，settings 的 key 随能力类型固定。
    $body = @{
        data = @{
            type          = 'bundleIdCapabilities'
            attributes    = @{
                capabilityType = 'APP_GROUPS'
                settings       = @(@{ key = 'groups'; options = @($GroupId) })
            }
            relationships = @{
                bundleId = @{ data = @{ type = 'bundleIds'; id = $BundleIdId } }
            }
        }
    }
    return Invoke-Asc -Method POST -Path '/v1/bundleIdCapabilities' -Body $body -Jwt $Jwt
}

function Get-Devices($Jwt) {
    $result = Invoke-Asc -Method GET -Path '/v1/devices?limit=200' -Jwt $Jwt
    if ($result) { return @($result.data) }
    return @()
}

function Confirm-Devices($Jwt, [string[]]$Udids) {
    if (-not $Udids -or $Udids.Count -eq 0) { return @() }
    $existing = Get-Devices $Jwt
    $names = @{}
    foreach ($d in $existing) { $names[$d.attributes.udid] = $d.id }

    $ids = @()
    foreach ($udid in $Udids) {
        if ($names.ContainsKey($udid)) {
            Write-Ok "设备已在账户里：$udid → $($names[$udid])"
            $ids += $names[$udid]
            continue
        }
        if (-not $AddDevices) {
            Write-Warn2 "设备未登记：$udid（要自动登记请加 -AddDevices）"
            continue
        }
        $body = @{ data = @{ type = 'devices'; attributes = @{ name = "test-$udid"; platform = 'IOS'; udid = $udid } } }
        $created = Invoke-Asc -Method POST -Path '/v1/devices' -Body $body -Jwt $Jwt
        if ($created) {
            Write-Ok "已登记设备：$udid → $($created.data.id)"
            $ids += $created.data.id
        }
    }
    return $ids
}

function Get-Certificates($Jwt, [string]$Type) {
    $result = Invoke-Asc -Method GET -Path "/v1/certificates?filter[certificateType]=$Type&limit=50" -Jwt $Jwt
    if ($result) { return @($result.data) }
    return @()
}

function Get-Profiles($Jwt, [string]$Type) {
    $result = Invoke-Asc -Method GET -Path "/v1/profiles?filter[profileType]=$Type&limit=50" -Jwt $Jwt
    if ($result) { return @($result.data) }
    return @()
}

function New-Profile($Jwt, [string]$Name, [string]$Type, $BundleIdId, $CertId, $DeviceIds) {
    $attributes = @{
        name        = $Name
        profileType = $Type
    }
    $relationships = @{
        bundleId    = @{ data = @{ type = 'bundleIds'; id = $BundleIdId } }
        certificates = @{ data = @(@{ type = 'certificates'; id = $CertId }) }
    }
    if ($Type -eq 'IOS_APP_DEVELOPMENT') {
        $relationships.devices = @{ data = @($DeviceIds | ForEach-Object { @{ type = 'devices'; id = $_ } }) }
    }
    $body = @{ data = @{ type = 'profiles'; attributes = $attributes; relationships = $relationships } }
    return Invoke-Asc -Method POST -Path '/v1/profiles' -Body $body -Jwt $Jwt
}

function Save-Profile($Jwt, $ProfileId, [string]$FileName) {
    $detail = Invoke-Asc -Method GET -Path "/v1/profiles/$ProfileId" -Jwt $Jwt
    if (-not $detail) { return $null }
    $content = $detail.data.attributes.profileContent
    if (-not $content) { throw "描述文件 $ProfileId 没有返回内容" }

    $dir = $OutDir
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $bin = Join-Path $dir $FileName
    [IO.File]::WriteAllBytes($bin, [Convert]::FromBase64String($content))
    $b64 = Join-Path $dir ($FileName + '.b64')
    [IO.File]::WriteAllText($b64, $content, (New-Object Text.UTF8Encoding $false))
    Write-Ok "描述文件已保存：$bin"
    Write-Ok "base64 已保存：$b64"
    return $content
}

function Invoke-Provision {
    $cfg = Read-Config
    Write-Step "校验 API 凭据"
    $jwt = New-AscJwt -KeyId $cfg.apiKeyId -IssuerId $cfg.issuerId -P8Content ([IO.File]::ReadAllText($cfg.apiKeyPath))
    Write-Ok ("JWT 已签发（{0} 字节）" -f $jwt.Length)

    Write-Step "App ID：$($cfg.bundleId)"
    $bundle = Get-BundleId $jwt $cfg.bundleId
    if ($bundle) {
        Write-Ok "已存在：$($bundle.id)"
    }
    else {
        Write-Warn2 "不存在，需要新建"
        if ($Apply) {
            $bundle = New-BundleId $jwt $cfg
            Write-Ok "已创建：$($bundle.data.id)"
        }
        else {
            New-BundleId $jwt $cfg | Out-Null
            throw "dry-run 到此为止：App ID 尚未创建，创建后再跑一次才能拿到 id 继续配 App Group 与描述文件。"
        }
    }

    Write-Step "App Group 能力：$($cfg.appGroup)"
    Set-AppGroupCapability $jwt $bundle.id $cfg.appGroup | Out-Null
    if (-not $Apply) { Write-Plan "（-Apply 时执行上面这条；若账户里已挂过同一个组，API 会返回 409，属正常）" }

    Write-Step "证书（只挑现有的，不新建）"
    $devCerts = Get-Certificates $jwt 'IOS_DEVELOPMENT'
    $distCerts = Get-Certificates $jwt 'IOS_DISTRIBUTION'
    $devCert = @($devCerts | Where-Object { $_.attributes.status -eq 'ACTIVE' }) | Select-Object -First 1
    $distCert = @($distCerts | Where-Object { $_.attributes.status -eq 'ACTIVE' }) | Select-Object -First 1
    if (-not $devCert) { Write-Warn2 "账户里没有可用的开发证书；开发描述文件无法签发，请先在 portal 生成并上传 .p12 到 DEV_CERTIFICATE_P。" }
    else { Write-Ok "开发证书：$($devCert.id)（$($devCert.attributes.displayName)）" }
    if (-not $distCert) { Write-Warn2 "账户里没有可用的发布证书；发布描述文件无法签发。" }
    else { Write-Ok "发布证书：$($distCert.id)（$($distCert.attributes.displayName)）" }

    Write-Step "设备"
    $deviceIds = Confirm-Devices $jwt $cfg.devices

    Write-Step "描述文件"
    if ($devCert) {
        $existing = Get-Profiles $jwt 'IOS_APP_DEVELOPMENT' | Where-Object { $_.attributes.name -eq $cfg.devProfileName }
        if ($existing) {
            Write-Ok "开发描述文件已存在：$($existing.id)"
            Save-Profile $jwt $existing.id 'dev_profile.mobileprovision' | Out-Null
        }
        else {
            $created = New-Profile $jwt $cfg.devProfileName 'IOS_APP_DEVELOPMENT' $bundle.id $devCert.id $deviceIds
            if ($created) {
                Write-Ok "已创建开发描述文件：$($created.data.id)"
                Save-Profile $jwt $created.data.id 'dev_profile.mobileprovision' | Out-Null
            }
            else { Write-Plan "将创建开发描述文件 $($cfg.devProfileName)（含 $($deviceIds.Count) 台设备）" }
        }
    }
    if ($distCert) {
        $existing = Get-Profiles $jwt 'IOS_APP_STORE' | Where-Object { $_.attributes.name -eq $cfg.distProfileName }
        if ($existing) {
            Write-Ok "发布描述文件已存在：$($existing.id)"
            Save-Profile $jwt $existing.id 'dist_profile.mobileprovision' | Out-Null
        }
        else {
            $created = New-Profile $jwt $cfg.distProfileName 'IOS_APP_STORE' $bundle.id $distCert.id @()
            if ($created) {
                Write-Ok "已创建发布描述文件：$($created.data.id)"
                Save-Profile $jwt $created.data.id 'dist_profile.mobileprovision' | Out-Null
            }
            else { Write-Plan "将创建发布描述文件 $($cfg.distProfileName)" }
        }
    }

    Write-Step "下一步"
    Write-Host "    描述文件的 base64 在 $OutDir 下。证书的 .p12 base64 与密码不在脚本产出范围内：" -ForegroundColor DarkGray
    Write-Host "    用你本地导出证书时的那份 .p12，base64 后写进 DEV_CERTIFICATE_P / DIST_CERTIFICATE_P，密码写进 P。" -ForegroundColor DarkGray
}

# ---------------------------------------------------------------- GitHub 侧

function Get-GhPath {
    $cmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Invoke-Gh {
    param([Parameter(Mandatory = $true)][string[]]$GhArgs)
    $gh = Get-GhPath
    if (-not $gh) { throw "未安装 GitHub CLI。" }
    $display = 'gh ' + ($GhArgs -join ' ')
    if (-not $Apply) {
        # 值一律打码，只显示长度，避免把密钥贴进终端历史
        Write-Plan $display
        return $null
    }
    & $gh @GhArgs
    if ($LASTEXITCODE -ne 0) { throw "gh 失败（exit $LASTEXITCODE）：$display" }
}

function Set-RepoSecret([string]$Repo, [string]$Name, [string]$Value) {
    if (-not $Value) { Write-Warn2 "跳过 $Name（无值）"; return }
    Write-Step "secret $Name（$($Value.Length) 字符）"
    Invoke-Gh @('secret', 'set', $Name, '--repo', $Repo, '--body', $Value)
}

function Set-RepoVariable([string]$Repo, [string]$Name, [string]$Value) {
    if (-not $Value) { Write-Warn2 "跳过变量 $Name（无值）"; return }
    Write-Step "variable $Name = $Value"
    Invoke-Gh @('variable', 'set', $Name, '--repo', $Repo, '--body', $Value)
}

function Invoke-Github {
    $cfg = Read-Config
    $gh = Get-GhPath
    if (-not $gh) {
        Write-Warn2 "本机没有 gh。装法：winget install --id GitHub.cli -e"
        Write-Warn2 "装好后执行 gh auth login（token 需 repo + admin:org 权限）。"
        return
    }
    Write-Step "GitHub 目标：$($cfg.githubRepo)"

    # workflow 里实际引用的 secrets（见 .github/workflows/build-ios.yml）
    Set-RepoSecret $cfg.githubRepo 'APPLE_TEAM_ID' $cfg.teamId
    Set-RepoSecret $cfg.githubRepo 'APPSTORE_ISSUER_ID' $cfg.issuerId
    Set-RepoSecret $cfg.githubRepo 'APPSTORE_API_KEY_ID' $cfg.apiKeyId
    Set-RepoSecret $cfg.githubRepo 'APPSTORE_API_PRIVATE_KEY' ([IO.File]::ReadAllText($cfg.apiKeyPath))

    $outDev = Join-Path $OutDir 'dev_profile.mobileprovision.b64'
    $outDist = Join-Path $OutDir 'dist_profile.mobileprovision.b64'
    if (Test-Path -LiteralPath $outDev) { Set-RepoSecret $cfg.githubRepo 'DEV_PROVISION_PROFILE' ([IO.File]::ReadAllText($outDev).Trim()) }
    else { Write-Warn2 "缺少 $outDev：先跑 -Command provision -Apply" }
    if (Test-Path -LiteralPath $outDist) { Set-RepoSecret $cfg.githubRepo 'DIST_PROVISION_PROFILE' ([IO.File]::ReadAllText($outDist).Trim()) }
    else { Write-Warn2 "缺少 $outDist：先跑 -Command provision -Apply" }

    if ($cfg.certP12Base64Dev) { Set-RepoSecret $cfg.githubRepo 'DEV_CERTIFICATE_P' $cfg.certP12Base64Dev }
    else { Write-Warn2 "DEV_CERTIFICATE_P 未提供（证书 .p12 的 base64，由你导出后填进配置）" }
    if ($cfg.certP12Base64Dist) { Set-RepoSecret $cfg.githubRepo 'DIST_CERTIFICATE_P' $cfg.certP12Base64Dist }
    else { Write-Warn2 "DIST_CERTIFICATE_P 未提供" }
    if ($cfg.certP12Password) { Set-RepoSecret $cfg.githubRepo 'P' $cfg.certP12Password }
    else { Write-Warn2 "P（.p12 密码）未提供" }

    # workflow 里用到的仓库变量
    Set-RepoVariable $cfg.githubRepo 'APP_GROUP_ID' $cfg.appGroup
    if ($cfg.runnerLabel) { Set-RepoVariable $cfg.githubRepo 'IOS_RUNNER_LABEL' $cfg.runnerLabel }

    Write-Step "环境（environments）"
    $envName = $cfg.githubEnvironment
    if ($envName) {
        Invoke-Gh @('api', '--method', 'PUT', "repos/$($cfg.githubRepo)/environments/$envName")
        Write-Host "    构建 job 目前没有引用 environment；建它是留个位置，之后要加保护规则（如仅 main 可发布）时直接用。" -ForegroundColor DarkGray
    }
    else { Write-Warn2 "未配置 githubEnvironment，跳过" }

    Write-Step "完成"
}

# ---------------------------------------------------------------- 入口

switch ($Command) {
    'check' {
        $cfg = Read-Config
        Write-Step "配置"
        Write-Ok "teamId        : $($cfg.teamId)"
        Write-Ok "bundleId      : $($cfg.bundleId)"
        Write-Ok "appGroup      : $($cfg.appGroup)"
        Write-Ok "apiKeyPath    : $($cfg.apiKeyPath)"
        Write-Ok "githubRepo    : $($cfg.githubRepo)"
        Write-Step "JWT 自检"
        $jwt = New-AscJwt -KeyId $cfg.apiKeyId -IssuerId $cfg.issuerId -P8Content ([IO.File]::ReadAllText($cfg.apiKeyPath))
        Write-Ok ("可签发 JWT（{0} 字节），鉴权链路正常" -f $jwt.Length)
        Write-Step "App Store Connect 连通性"
        $bundle = Get-BundleId $jwt $cfg.bundleId
        if ($bundle) { Write-Ok "App ID 已存在：$($bundle.id)" } else { Write-Warn2 "App ID 尚未创建" }
        $certs = @(Get-Certificates $jwt 'IOS_DISTRIBUTION')
        Write-Ok "发布证书 $($certs.Count) 张"
        Write-Step "GitHub CLI"
        if (Get-GhPath) { Write-Ok "已安装" } else { Write-Warn2 "未安装：winget install --id GitHub.cli -e" }
    }
    'provision' { Invoke-Provision }
    'github'    { Invoke-Github }
}
