#!/usr/bin/env python3
"""App Store Connect 与 GitHub 的一次性配置脚本（Python 版）。

三个作用：
  1) 用 API 密钥登录 App Store Connect，为配置里的每个 App 建唯一的 Bundle ID，
     并给它配上 App Group 能力、设备与开发/发布描述文件；
  2) 把描述文件导出到本地（.mobileprovision + .b64 + manifest.json），
     再把值写进 GitHub 仓库的 secrets / variables / environment；
  3) 配置说明见 docs/ios-appstore-automation.md。

默认 dry-run：写操作只打印，不加 --apply 不发任何 POST/PATCH。
不创建证书：重建证书会让同一 Team 下已有构建的签名链失效，还会堆孤儿证书。

依赖：Python 3.9+ 与 cryptography（`python -m pip install cryptography`）。
上传构建、提交审核不在本脚本范围内——Windows 上没有 Transporter，上传由 CI 完成。

用法：
    python tools/appstore_setup.py check
    python tools/appstore_setup.py provision
    python tools/appstore_setup.py provision --apply --add-devices
    python tools/appstore_setup.py github --apply
"""
from __future__ import annotations

import argparse
import base64
import json
import plistlib
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ASC_BASE = "https://api.appstoreconnect.apple.com"
DEFAULT_CONFIG = Path(__file__).resolve().parent / "appstore_setup.config.json"
DEFAULT_OUT = Path(__file__).resolve().parent / "appstore_out"


# ------------------------------------------------------------------ 输出

def step(message: str) -> None:
    print(f"==> {message}")


def ok(message: str) -> None:
    print(f"    {message}")


def warn(message: str) -> None:
    print(f"    ! {message}")


def plan(message: str) -> None:
    print(f"    [dry-run] {message}")


# ------------------------------------------------------------------ 配置

REQUIRED = ("teamId", "apiKeyId", "issuerId", "apiKeyPath", "githubRepo")


def read_profile_metadata(path: Path) -> dict:
    """读 .mobileprovision 里的 plist。

    这个文件是 CMS 签名包裹的 plist，plistlib 直接喂会失败，所以先截出 <?xml ... </plist> 那一段。
    """
    raw = path.read_bytes()
    start = raw.find(b"<?xml")
    end = raw.find(b"</plist>")
    if start < 0 or end < 0:
        raise SystemExit(f"{path} 里找不到 plist，不像是 .mobileprovision 文件。")
    return plistlib.loads(raw[start:end + len(b"</plist>")])


def describe_profile(path: Path, bundle_id: str) -> tuple[bool, dict]:
    """核对该描述文件是否覆盖目标 Bundle ID，不覆盖就返回 (False, 元信息)。"""
    meta = read_profile_metadata(path)
    entitlements = meta.get("Entitlements") or {}
    app_identifier = str(entitlements.get("application-identifier") or "")
    team = str(entitlements.get("com.apple.developer.team-identifier") or "")
    info = {
        "name": str(meta.get("Name") or ""),
        "uuid": str(meta.get("UUID") or ""),
        "appIdentifier": app_identifier,
        "team": team,
        "devices": len(meta.get("ProvisionedDevices") or []),
        "getTaskAllow": bool(entitlements.get("get-task-allow")),
        "appGroups": entitlement_groups(entitlements),
    }
    covers = app_identifier.endswith("." + bundle_id) or app_identifier == bundle_id
    return covers, info


def entitlement_groups(entitlements: dict) -> list:
    groups = entitlements.get("com.apple.security.application-groups") or []
    return list(groups)


def load_config(path: Path, require_api: bool = True) -> dict:
    if not path.is_file():
        raise SystemExit(f"缺少配置文件：{path}。先从 appstore_setup.config.example.json 复制一份。")
    with path.open(encoding="utf-8") as handle:
        cfg = json.load(handle)
    for key in REQUIRED:
        if not cfg.get(key):
            raise SystemExit(f"配置缺字段：{key}")
    if not cfg.get("bundleId") and not cfg.get("apps"):
        raise SystemExit("配置缺字段：bundleId（或改用 apps 数组）")
    if not cfg.get("appGroup") and not any(a.get("appGroup") for a in (cfg.get("apps") or [])):
        raise SystemExit("配置缺字段：appGroup（也可以在 apps 的每个条目里单独写）")
    key_path = Path(cfg["apiKeyPath"]).expanduser()
    if require_api and not key_path.is_file():
        raise SystemExit(f"找不到 API 私钥文件：{key_path}（App Store Connect → 用户和访问 → 密钥 下载的 AuthKey_*.p8）")
    # profile 子命令只读本地描述文件、不碰 API，所以跳过下面这组检查。
    if require_api:
        key_id = str(cfg.get("apiKeyId") or "").strip()
        if re.fullmatch(r"[Xx]{6,}", key_id):
            raise SystemExit(
                f"apiKeyId 还是示例里的占位符（{key_id}）。填 App Store Connect → 用户和访问 → 密钥 里那一行的 Key ID，"
                "它同时也是 .p8 文件名里 AuthKey_ 之后的那一段。"
            )
        if not re.fullmatch(r"[A-Z0-9]{10}", key_id):
            warn(f"apiKeyId（{key_id}）不像 Key ID：Apple 的 Key ID 是 10 位大写字母数字。")

        issuer = str(cfg.get("issuerId") or "").strip()
        if not re.fullmatch(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", issuer):
            warn(f"issuerId（{issuer}）不像 Issuer ID：它应是形如 xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx 的 UUID。")

        # 文件名交叉核对。App Store Connect 下载的密钥叫 AuthKey_<10 位 Key ID>.p8；
        # 文件名里的标识若不是 10 位，这个 .p8 很可能来自别的服务（APNs 推送密钥也是 EC P-256，
        # 签名能过，但这套鉴权不认），比「密钥无效」有用得多。
        prefix, _, candidate = key_path.stem.partition("_")
        if candidate:
            if len(candidate) != 10:
                warn(f".p8 文件名里的标识「{candidate}」是 {len(candidate)} 位，不是 10 位 Key ID。"
                     "App Store Connect 下载的文件形如 AuthKey_<10 位 Key ID>.p8，"
                     "这个文件可能来自别的服务（比如 APNs 推送密钥），那种密钥签出来的 JWT 会被判 401。")
            elif candidate.upper() != key_id:
                warn(f"配置的 apiKeyId（{key_id}）与文件名里的（{candidate}）不一致，确认哪个才是密钥页上的 Key ID。")

    cfg["_keyPath"] = key_path
    return cfg


def slug_of(bundle_id: str) -> str:
    return "".join(ch if ch.isalnum() else "_" for ch in bundle_id)


def expand_apps(cfg: dict) -> list[dict]:
    """把配置展开成逐 App 的条目；顶层单 App 写法与 apps 数组等价。"""
    defaults_group = cfg.get("appGroup") or ""
    default_devices = cfg.get("devices") or []

    apps = []
    raw = cfg.get("apps") or []
    if raw:
        for entry in raw:
            bundle_id = entry.get("bundleId")
            if not bundle_id:
                raise SystemExit("apps 里有条目缺 bundleId")
            slug = slug_of(bundle_id)
            apps.append({
                "bundleId": bundle_id,
                "appName": entry.get("appName") or bundle_id,
                "appGroup": entry.get("appGroup") or defaults_group,
                "devProfileName": entry.get("devProfileName") or f"{slug}_dev",
                "distProfileName": entry.get("distProfileName") or f"{slug}_appstore",
                "devices": list(entry.get("devices") or default_devices),
                "sku": entry.get("sku") or "",
                "primaryLocale": entry.get("primaryLocale") or "",
            })
    else:
        bundle_id = cfg["bundleId"]
        slug = slug_of(bundle_id)
        apps.append({
            "bundleId": bundle_id,
            "appName": cfg.get("appName") or bundle_id,
            "appGroup": defaults_group,
            "devProfileName": cfg.get("devProfileName") or f"{slug}_dev",
            "distProfileName": cfg.get("distProfileName") or f"{slug}_appstore",
            "devices": list(default_devices),
            "sku": cfg.get("sku") or "",
            "primaryLocale": cfg.get("primaryLocale") or "",
        })

    seen = {}
    for app in apps:
        seen[app["bundleId"]] = seen.get(app["bundleId"], 0) + 1
    dupes = [name for name, count in seen.items() if count > 1]
    if dupes:
        raise SystemExit("配置里 Bundle ID 重复：" + "、".join(dupes) + "。每个 App 的 Bundle ID 必须唯一。")
    return apps


# ------------------------------------------------------------------ 鉴权

def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


def make_jwt(key_id: str, issuer_id: str, key_path: Path, lifetime: int = 1200) -> str:
    try:
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import ec, utils
    except ImportError:
        raise SystemExit("缺少依赖 cryptography：python -m pip install cryptography")

    key = serialization.load_pem_private_key(key_path.read_bytes(), password=None)
    if not isinstance(key, ec.EllipticCurvePrivateKey):
        raise SystemExit("API 私钥不是 EC 密钥（.p8 应是 PKCS#8 的 ES256 私钥）")

    header = json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}, separators=(",", ":")).encode()
    now = int(time.time())
    claims = json.dumps(
        {"iss": issuer_id, "iat": now, "exp": now + lifetime, "aud": "appstoreconnect-v1"},
        separators=(",", ":"),
    ).encode()
    signing_input = f"{b64url(header)}.{b64url(claims)}".encode()

    der_signature = key.sign(signing_input, ec.ECDSA(hashes.SHA256()))
    r, s = utils.decode_dss_signature(der_signature)
    # JWT 要的是 r||s 各 32 字节，不是 DER
    raw_signature = r.to_bytes(32, "big") + s.to_bytes(32, "big")
    return f"{signing_input.decode()}.{b64url(raw_signature)}"


# ------------------------------------------------------------------ REST

class AscClient:
    def __init__(self, jwt: str, apply: bool):
        self.jwt = jwt
        self.apply = apply

    def _request(self, method: str, path: str, body: dict | None) -> dict | None:
        if method in ("POST", "PATCH", "DELETE") and not self.apply:
            plan(f"{method} {path}")
            if body:
                plan(json.dumps(body, ensure_ascii=False, separators=(",", ":")))
            return None
        data = json.dumps(body).encode() if body else None
        request = urllib.request.Request(
            ASC_BASE + path,
            data=data,
            method=method,
            headers={"Authorization": f"Bearer {self.jwt}", "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                payload = response.read()
                return json.loads(payload) if payload else {}
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")
            raise RuntimeError(f"HTTP {error.code} {path}\n{detail}") from error

    def get(self, path: str) -> dict:
        return self._request("GET", path, None) or {}

    def post(self, path: str, body: dict) -> dict | None:
        return self._request("POST", path, body)

    def delete(self, path: str) -> dict | None:
        """删除资源。描述文件绑错 Bundle ID 时用它回滚，避免占着名字又签不上。"""
        return self._request("DELETE", path, None)


def get_bundle_id(client: AscClient, identifier: str) -> dict | None:
    # filter[identifier] 不是精确匹配：账户里同时存在 com.tjyx.compass 与
    # com.tjyx.compass.9ZK328P458 时，它会把后者排在前面返回，于是描述文件绑到
    # 带团队后缀的那个标识上——包还是签不上。必须自己再按 identifier 全等挑一次。
    payload = client.get(f"/v1/bundleIds?filter[identifier]={identifier}")
    data = payload.get("data") or []
    for row in data:
        if ((row.get("attributes") or {}).get("identifier")) == identifier:
            return row
    return None


def create_bundle_id(client: AscClient, bundle_id: str, name: str) -> dict | None:
    body = {
        "data": {
            "type": "bundleIds",
            "attributes": {"identifier": bundle_id, "name": name, "platform": "IOS"},
        }
    }
    return client.post("/v1/bundleIds", body)


def add_app_group_capability(client: AscClient, bundle_id_id: str, group: str) -> dict | None:
    """给 Bundle ID 挂上 App Groups 能力。

    注意：这个端点在当前账户只接受 ICLOUD_VERSION / DATA_PROTECTION_PERMISSION_LEVEL /
    APPLE_ID_AUTH_APP_CONSENT 三种 settings key，`APP_GROUPS` 会被 409 拒掉
    （"'groups' is not a valid value for the attribute 'settings/0/key'"）。
    也就是说 App Groups 能力只能去 portal 的 Identifiers → Capabilities 手点，
    公开 API 这条路不通。没有 entitlements、也不读写共享容器的工程本来就不需要它。
    """
    body = {
        "data": {
            "type": "bundleIdCapabilities",
            "attributes": {
                "capabilityType": "APP_GROUPS",
                "settings": [{"key": "groups", "options": [group]}],
            },
            "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle_id_id}}},
        }
    }
    return client.post("/v1/bundleIdCapabilities", body)


def list_devices(client: AscClient) -> list[dict]:
    return client.get("/v1/devices?limit=200").get("data") or []


def register_devices(client: AscClient, udids: list[str], add_missing: bool) -> list[str]:
    if not udids:
        return []
    existing = {d["attributes"]["udid"]: d["id"] for d in list_devices(client)}
    ids = []
    for udid in udids:
        if udid in existing:
            ok(f"设备已在账户里：{udid} -> {existing[udid]}")
            ids.append(existing[udid])
            continue
        if not add_missing:
            warn(f"设备未登记：{udid}（要自动登记加 --add-devices）")
            continue
        body = {"data": {"type": "devices", "attributes": {"name": f"test-{udid}", "platform": "IOS", "udid": udid}}}
        created = client.post("/v1/devices", body)
        if created:
            ok(f"已登记设备：{udid} -> {created['data']['id']}")
            ids.append(created["data"]["id"])
    return ids


def list_certificates(client: AscClient, cert_type: str) -> list[dict]:
    return client.get(f"/v1/certificates?filter[certificateType]={cert_type}&limit=50").get("data") or []


def list_profiles(client: AscClient, profile_type: str) -> list[dict]:
    return client.get(f"/v1/profiles?filter[profileType]={profile_type}&limit=50").get("data") or []


def cert_usable(cert: dict, today: str | None = None) -> bool:
    """证书能不能用：看 status（缺字段视为可用）与到期日。

    证书列表接口偶尔不回 status，直接取 c["attributes"]["status"] 会 KeyError 把整条链路弄断。
    """
    attributes = cert.get("attributes") or {}
    status = attributes.get("status")
    if status and status not in ("ACTIVE", "DEVELOPMENT_ACTIVE"):
        return False
    expires = attributes.get("expirationDate")
    if expires:
        today = today or time.strftime("%Y-%m-%d")
        return str(expires)[:10] >= today
    return True


def create_profile(client: AscClient, name: str, profile_type: str, bundle_id_id: str,
                   cert_id: str, device_ids: list[str]) -> dict | None:
    relationships = {
        "bundleId": {"data": {"type": "bundleIds", "id": bundle_id_id}},
        "certificates": {"data": [{"type": "certificates", "id": cert_id}]},
    }
    if profile_type == "IOS_APP_DEVELOPMENT":
        relationships["devices"] = {"data": [{"type": "devices", "id": device} for device in device_ids]}
    body = {
        "data": {
            "type": "profiles",
            "attributes": {"name": name, "profileType": profile_type},
            "relationships": relationships,
        }
    }
    return client.post("/v1/profiles", body)


def save_profile(client: AscClient, profile_id: str, file_name: str, out_dir: Path) -> list[str]:
    detail = client.get(f"/v1/profiles/{profile_id}")
    content = (detail.get("data") or {}).get("attributes", {}).get("profileContent")
    if not content:
        raise RuntimeError(f"描述文件 {profile_id} 没有返回内容")
    out_dir.mkdir(parents=True, exist_ok=True)
    binary = out_dir / file_name
    binary.write_bytes(base64.b64decode(content))
    text = out_dir / f"{file_name}.b64"
    text.write_text(content, encoding="utf-8")
    ok(f"描述文件已保存：{binary}")
    ok(f"base64 已保存：{text}")
    return [binary.name, text.name]


# ------------------------------------------------------------------ provision

def provision_one(client: AscClient, app: dict, dev_cert: dict | None, dist_cert: dict | None,
                  out_dir: Path, apply: bool, add_devices: bool) -> dict:
    slug = slug_of(app["bundleId"])
    record = {
        "bundleId": app["bundleId"],
        "appName": app["appName"],
        "appGroup": app["appGroup"],
        "appBundleIdId": "",
        "groupCapability": False,
        "devProfileId": "",
        "distProfileId": "",
        "files": [],
    }

    step(f"App ID：{app['bundleId']}")
    try:
        bundle = get_bundle_id(client, app["bundleId"])
    except RuntimeError as error:
        warn(f"查询失败：{error}")
        return record
    if bundle:
        ok(f"已存在：{bundle['id']}")
    elif apply:
        created = create_bundle_id(client, app["bundleId"], app["appName"])
        bundle = (created or {}).get("data") or {}
        ok(f"已创建：{bundle.get('id')}")
    else:
        plan(f"将创建 App ID {app['bundleId']}（{app['appName']}）")
        warn("dry-run 停在 App ID 之前：没有它的 id 走不完后面的步骤，加 --apply 再跑。")
        return record
    record["appBundleIdId"] = bundle.get("id", "")

    step(f"App Group 能力：{app['appGroup']}")
    if apply:
        try:
            add_app_group_capability(client, record["appBundleIdId"], app["appGroup"])
            ok("已挂上（返回 409 说明账户里本来就有，属正常）")
            record["groupCapability"] = True
        except RuntimeError as error:
            warn(f"没挂上：{error}")
            warn("到 portal 里手动勾一次 App Groups 也能继续，描述文件照样能签。")
    else:
        plan(f"将挂上 App Group 能力 {app['appGroup']}（API 若拒收该 payload，退回 portal 手点一次）")

    step("设备")
    device_ids = register_devices(client, app["devices"], add_devices)

    step("描述文件")
    if dev_cert:
        existing = [p for p in list_profiles(client, "IOS_APP_DEVELOPMENT")
                    if p["attributes"]["name"] == app["devProfileName"]]
        profile_id = existing[0]["id"] if existing else ""
        if profile_id:
            ok(f"开发描述文件已存在：{profile_id}")
        elif apply:
            created = create_profile(client, app["devProfileName"], "IOS_APP_DEVELOPMENT",
                                     record["appBundleIdId"], dev_cert["id"], device_ids)
            profile_id = ((created or {}).get("data") or {}).get("id", "")
            if profile_id:
                ok(f"已创建开发描述文件：{profile_id}")
        else:
            plan(f"将创建开发描述文件 {app['devProfileName']}（含 {len(device_ids)} 台设备）")
        if profile_id:
            record["devProfileId"] = profile_id
            record["files"] = save_profile(client, profile_id, f"{slug}.dev.mobileprovision", out_dir)
    else:
        warn("跳过：没有可用的开发证书")

    if dist_cert:
        existing = [p for p in list_profiles(client, "IOS_APP_STORE")
                    if p["attributes"]["name"] == app["distProfileName"]]
        profile_id = existing[0]["id"] if existing else ""
        if profile_id:
            ok(f"发布描述文件已存在：{profile_id}")
        elif apply:
            created = create_profile(client, app["distProfileName"], "IOS_APP_STORE",
                                     record["appBundleIdId"], dist_cert["id"], [])
            profile_id = ((created or {}).get("data") or {}).get("id", "")
            if profile_id:
                ok(f"已创建发布描述文件：{profile_id}")
        else:
            plan(f"将创建发布描述文件 {app['distProfileName']}")
        if profile_id:
            record["distProfileId"] = profile_id
            record["files"] += save_profile(client, profile_id, f"{slug}.appstore.mobileprovision", out_dir)
    else:
        warn("跳过：没有可用的发布证书")

    return record


def provision(cfg: dict, apply: bool, out_dir: Path, add_devices: bool) -> int:
    apps = expand_apps(cfg)

    step("校验 API 凭据")
    jwt = make_jwt(cfg["apiKeyId"], cfg["issuerId"], cfg["_keyPath"])
    ok(f"JWT 已签发（{len(jwt)} 字节）")

    client = AscClient(jwt, apply)

    step("证书（只挑现有的，不新建；取一次给所有 App 共用）")
    try:
        dev_cert = next((c for c in list_certificates(client, "IOS_DEVELOPMENT") if cert_usable(c)), None)
        dist_cert = next((c for c in list_certificates(client, "IOS_DISTRIBUTION") if cert_usable(c)), None)
    except RuntimeError as error:
        warn(f"中断：{error}")
        warn("API 密钥或角色权限不对时，这一步就会失败；先改好再跑。")
        return 1
    if dev_cert:
        ok(f"开发证书：{dev_cert['id']}")
    else:
        warn("账户里没有可用的开发证书，开发描述文件会被跳过")
    if dist_cert:
        ok(f"发布证书：{dist_cert['id']}")
    else:
        warn("账户里没有可用的发布证书，发布描述文件会被跳过")

    manifest = []
    try:
        for app in apps:
            print()
            step(f"--- {app['bundleId']}  ({app['appName']})")
            manifest.append(provision_one(client, app, dev_cert, dist_cert, out_dir, apply, add_devices))
    except RuntimeError as error:
        warn(f"中断：{error}")
        return 1

    manifest_path = out_dir / "manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(
        json.dumps({
            "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%S"),
            "teamId": cfg["teamId"],
            "appCount": len(manifest),
            "apps": manifest,
        }, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print()
    step("导出清单")
    ok(str(manifest_path))

    step("下一步")
    print(f"    描述文件与 base64 都在 {out_dir}。")
    print("    接着跑 `python tools/appstore_setup.py secrets --apply`：它把这批产物整理成 GitHub secrets 清单，")
    print("    有 gh 就直接写进仓库，没有 gh 就导出 JSON + 一份可直接执行的 PowerShell 脚本。")
    return 0


# ------------------------------------------------------------------ github

GH_PATH: str | None = None


def resolve_gh() -> str | None:
    """shutil.which 会按 PATHEXT 找 gh.exe / gh.cmd；直接 subprocess 找不到无扩展名的 .cmd。"""
    global GH_PATH
    if GH_PATH is None:
        GH_PATH = shutil.which("gh") or shutil.which("gh.exe") or shutil.which("gh.cmd") or ""
    return GH_PATH or None


def has_gh() -> bool:
    path = resolve_gh()
    if not path:
        return False
    result = subprocess.run([path, "--version"], capture_output=True, text=True)
    return result.returncode == 0


def gh(args: list[str], apply: bool) -> None:
    display = "gh " + " ".join(a if not a.startswith("-----") and len(a) < 80 else f"<{len(a)} 字符>" for a in args)
    if not apply:
        plan(display)
        return
    path = resolve_gh()
    if not path:
        raise SystemExit("未安装 GitHub CLI（gh）。")
    result = subprocess.run([path] + args, capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(f"gh 失败（exit {result.returncode}）：{display}\n{result.stderr.strip()}")


def set_secret(repo: str, name: str, value: str | None, apply: bool) -> None:
    if not value:
        warn(f"跳过 {name}（无值）")
        return
    step(f"secret {name}（{len(value)} 字符）")
    gh(["secret", "set", name, "--repo", repo, "--body", value], apply)


def set_variable(repo: str, name: str, value: str | None, apply: bool) -> None:
    if not value:
        warn(f"跳过变量 {name}（无值）")
        return
    step(f"variable {name} = {value}")
    gh(["variable", "set", name, "--repo", repo, "--body", value], apply)


def build_secret_bundle(cfg: dict, out_dir: Path, dev_profile: Path | None = None,
                        dist_profile: Path | None = None) -> list[dict]:
    """把「CI 需要的一切」整理成 {name, value, kind} 清单。

    workflow（.github/workflows/build-ios.yml）里真正读到的名字必须逐字对得上，
    所以这里集中一处生成，避免再出现 DEV_CERTIFICATE_P 这种少半截的键。
    """
    apps = expand_apps(cfg)
    primary = apps[0]
    slug = slug_of(primary["bundleId"])
    entries: list[dict] = []

    def add(name: str, value: str | None, kind: str, note: str = "") -> None:
        if value:
            entries.append({"name": name, "value": value, "kind": kind, "note": note})

    add("APPLE_TEAM_ID", cfg.get("teamId"), "secret", "团队 ID，与描述文件里的 TeamIdentifier 一致")
    add("APPSTORE_API_KEY_ID", cfg.get("apiKeyId"), "secret", "ASC 集成密钥的 Key ID（10 位）")
    add("APPSTORE_ISSUER_ID", cfg.get("issuerId"), "secret", "ASC 密钥的 Issuer ID")
    key_path = cfg.get("_keyPath")
    if key_path and Path(key_path).is_file():
        add("APPSTORE_API_PRIVATE_KEY", Path(key_path).read_text(encoding="utf-8"),
            "secret", "AuthKey_<KeyID>.p8 的 PEM 原文")

    def profile_bytes(explicit: Path | None, generated: Path, label: str) -> None:
        path = explicit if explicit and explicit.is_file() else generated
        if not path.is_file():
            warn(f"缺少 {label} 描述文件（{path}），对应 secret 跳过")
            return
        covers, info = describe_profile(path, primary["bundleId"])
        if not covers:
            warn(f"{label} 描述文件的 App ID 是 {info['appIdentifier']}，覆盖不到 {primary['bundleId']}，不写进 secret")
            return
        b64_path = path.with_name(path.name + ".b64") if path.suffix != ".b64" else path
        value = b64_path.read_text(encoding="utf-8").strip() if b64_path.is_file() \
            else base64.b64encode(path.read_bytes()).decode()
        add("DEV_PROVISION_PROFILE" if label == "开发" else "DIST_PROVISION_PROFILE", value,
            "secret", f"{info['name']} / {info['uuid']} / App ID {info['appIdentifier']}")

    profile_bytes(dev_profile, out_dir / f"{slug}.dev.mobileprovision", "开发")
    profile_bytes(dist_profile, out_dir / f"{slug}.appstore.mobileprovision", "发布")

    p12 = cfg.get("distP12Path") or (out_dir / "certificate.dist.p12")
    if Path(p12).is_file():
        b64_file = Path(str(p12) + ".b64")
        add("DIST_CERTIFICATE_P12",
            b64_file.read_text(encoding="utf-8").strip() if b64_file.is_file()
            else base64.b64encode(Path(p12).read_bytes()).decode(),
            "secret", "发布证书 .p12 的 base64")
    else:
        warn(f"缺少发布证书 {p12}：先在 bootstrap 里 --create-certificates 生成，或手动导出 .p12")
    add("DIST_P12_PASSWORD", cfg.get("p12Password") or cfg.get("certP12Password"), "secret", ".p12 的密码")

    group = primary["appGroup"]
    add("APP_GROUP_ID", group if cfg.get("writeAppGroupVariable") else "", "variable",
        "工程没有 entitlements 时留空：填了会让构建硬失败")
    add("IOS_RUNNER_LABEL", cfg.get("runnerLabel") or "xcode-27", "variable", "CI 用的自托管/云 runner 标签")
    return entries


def export_secrets(cfg: dict, out_dir: Path, dev_profile: Path | None = None,
                   dist_profile: Path | None = None) -> int:
    """没有 gh 也能走：把清单落盘，给出一份可以直接粘/直接跑的配置说明。"""
    entries = build_secret_bundle(cfg, out_dir, dev_profile, dist_profile)
    if not entries:
        warn("没有可导出的条目，先跑 provision --apply 生成证书与描述文件")
        return 1

    out_dir.mkdir(parents=True, exist_ok=True)
    secrets = {e["name"]: e["value"] for e in entries if e["kind"] == "secret"}
    variables = {e["name"]: e["value"] for e in entries if e["kind"] == "variable"}
    bundle = out_dir / "github_secrets.json"
    bundle.write_text(json.dumps({"repository": cfg["githubRepo"], "secrets": secrets,
                                  "variables": variables}, ensure_ascii=False, indent=2),
                      encoding="utf-8")
    bundle.chmod(0o600) if hasattr(bundle, "chmod") else None

    # 逐条拆成单文件，避免命令行长度与引号问题；PowerShell 脚本按文件喂给 gh。
    payload_dir = out_dir / "github_secret_files"
    payload_dir.mkdir(parents=True, exist_ok=True)
    for name, value in list(secrets.items()) + list(variables.items()):
        (payload_dir / f"{name}.txt").write_text(value, encoding="utf-8", newline="")

    step(f"已导出 {len(secrets)} 个 secret、{len(variables)} 个 variable")
    for entry in entries:
        label = "secret" if entry["kind"] == "secret" else "variable"
        ok(f"{entry['name']:<28} {label:<8} {len(entry['value']):>6} 字符   {entry['note']}")

    repo = cfg["githubRepo"]
    kind_cmd = {
        "secret": 'gh secret set {name} --repo %s --body-file "{{file}}"' % repo,
        "variable": 'gh variable set {name} --repo %s --body-file "{{file}}"' % repo,
    }
    lines = [
        "# 由 tools/appstore_setup.py secrets --apply 生成。",
        "# 1) 先装 gh 并登录（只需一次）：winget install --id GitHub.cli -e ; gh auth login",
        "# 2) 在仓库根执行本脚本：powershell -ExecutionPolicy Bypass -File tools\\appstore_out\\apply_github_secrets.ps1",
        "# 没有 gh 时，用网页逐条填：https://github.com/%s/settings/secrets/actions" % repo,
        '$ErrorActionPreference = "Stop"',
        '$gh = (Get-Command gh -ErrorAction SilentlyContinue)',
        'if (-not $gh) { throw "没找到 gh：winget install --id GitHub.cli -e" }',
        '$files = "%s"' % payload_dir,
        '$repo = "%s"' % repo,
        "",
    ]
    for entry in entries:
        cmd = ("gh secret set " if entry["kind"] == "secret" else "gh variable set ") + entry["name"] + \
              ' --repo $repo --body-file (Join-Path $files "' + entry["name"] + '.txt")'
        lines.append(cmd)
    script = out_dir / "apply_github_secrets.ps1"
    script.write_text("\r\n".join(lines) + "\r\n", encoding="utf-8")

    step("落盘")
    ok(str(bundle))
    ok(str(script))
    print()
    print("    注意：这个目录已在 .gitignore 里，明文密钥不会进仓库；用完记得删。")
    return 0


def github(cfg: dict, apply: bool, out_dir: Path,
           dev_profile: Path | None = None, dist_profile: Path | None = None) -> int:
    if not has_gh():
        warn("本机没有 gh：winget install --id GitHub.cli -e，然后 gh auth login")
        warn("改成导出清单，你可以用导出的脚本或网页把它们填上去。")
        return export_secrets(cfg, out_dir, dev_profile, dist_profile)

    apps = expand_apps(cfg)
    primary = apps[0]
    if len(apps) > 1:
        warn(f"配置里有 {len(apps)} 个 App，但本仓库只构建一个：GitHub 侧按 {primary['bundleId']} 的产物填。")
    slug = slug_of(primary["bundleId"])

    step(f"GitHub 目标：{cfg['githubRepo']}")
    set_secret(cfg["githubRepo"], "APPLE_TEAM_ID", cfg["teamId"], apply)
    set_secret(cfg["githubRepo"], "APPSTORE_ISSUER_ID", cfg["issuerId"], apply)
    set_secret(cfg["githubRepo"], "APPSTORE_API_KEY_ID", cfg["apiKeyId"], apply)
    set_secret(cfg["githubRepo"], "APPSTORE_API_PRIVATE_KEY",
               cfg["_keyPath"].read_text(encoding="utf-8"), apply)

    dev_b64 = out_dir / f"{slug}.dev.mobileprovision.b64"
    dist_b64 = out_dir / f"{slug}.appstore.mobileprovision.b64"

    def push_profile(secret_name: str, explicit: Path | None, generated: Path) -> None:
        """优先用手工下载的描述文件；推之前先核对 App ID，避免又推一个旧 bundle id 上去。"""
        if explicit:
            if not explicit.is_file():
                raise SystemExit(f"找不到描述文件：{explicit}")
            covers, info = describe_profile(explicit, primary["bundleId"])
            step(f"描述文件 {explicit.name}")
            plan(f"Name={info['name']}  UUID={info['uuid']}  AppID={info['appIdentifier']}")
            plan(f"设备 {info['devices']} 台  get-task-allow={info['getTaskAllow']}  App Group={info['appGroups']}")
            if not covers:
                raise SystemExit(
                    f"这个描述文件的 App ID 是 {info['appIdentifier']}，覆盖不到 {primary['bundleId']}。"
                    "在 portal 里为当前 Bundle ID 重新生成一个，再指过来。"
                )
            if info["team"] and info["team"] != cfg["teamId"]:
                warn(f"描述文件的 Team（{info['team']}）与配置的 {cfg['teamId']} 不一致。")
            if info["appGroups"] and primary["appGroup"] not in info["appGroups"]:
                warn(f"描述文件没带 {primary['appGroup']}，装上后读写 App Group 会失败。")
            set_secret(cfg["githubRepo"], secret_name,
                       base64.b64encode(explicit.read_bytes()).decode(), apply)
            return
        if generated.is_file():
            set_secret(cfg["githubRepo"], secret_name, generated.read_text(encoding="utf-8").strip(), apply)
        else:
            warn(f"缺少 {generated}：先跑 provision --apply，或用 --dev-profile/--dist-profile 指一个现成的。")

    push_profile("DEV_PROVISION_PROFILE", dev_profile, dev_b64)
    push_profile("DIST_PROVISION_PROFILE", dist_profile, dist_b64)

    set_secret(cfg["githubRepo"], "DEV_CERTIFICATE_P12", cfg.get("certP12Base64Dev"), apply)
    set_secret(cfg["githubRepo"], "DIST_CERTIFICATE_P12", cfg.get("certP12Base64Dist"), apply)
    set_secret(cfg["githubRepo"], "DIST_P12_PASSWORD", cfg.get("p12Password") or cfg.get("certP12Password"), apply)

    set_variable(cfg["githubRepo"], "APP_GROUP_ID", primary["appGroup"], apply)
    set_variable(cfg["githubRepo"], "IOS_RUNNER_LABEL", cfg.get("runnerLabel"), apply)

    step("环境（environments）")
    environment = cfg.get("githubEnvironment")
    if environment:
        gh(["api", "--method", "PUT", f"repos/{cfg['githubRepo']}/environments/{environment}"], apply)
        print("    构建 job 目前没有引用 environment；建它是给之后的发布保护规则留位置。")
    else:
        warn("未配置 githubEnvironment，跳过")

    step("完成")
    return 0


# ------------------------------------------------------------------ check

def check(cfg: dict) -> int:
    apps = expand_apps(cfg)
    step("配置")
    ok(f"teamId      : {cfg['teamId']}")
    ok(f"apiKeyPath  : {cfg['_keyPath']}")
    ok(f"githubRepo  : {cfg['githubRepo']}")
    ok(f"App 数量    : {len(apps)}")
    for app in apps:
        ok(f"  - {app['bundleId']}  group={app['appGroup']}  dev={app['devProfileName']}  dist={app['distProfileName']}")

    step("JWT 自检")
    jwt = make_jwt(cfg["apiKeyId"], cfg["issuerId"], cfg["_keyPath"])
    ok(f"可签发 JWT（{len(jwt)} 字节），鉴权链路正常")

    step("App Store Connect 连通性")
    client = AscClient(jwt, apply=False)
    for app in apps:
        try:
            bundle = get_bundle_id(client, app["bundleId"])
        except RuntimeError as error:
            warn(f"查询失败：{error}")
            return 1
        if bundle:
            ok(f"{app['bundleId']} 已存在：{bundle['id']}")
        else:
            warn(f"{app['bundleId']} 尚未创建")
    certs = list_certificates(client, "IOS_DISTRIBUTION")
    ok(f"发布证书 {len(certs)} 张")

    step("「我的 App」记录")
    try:
        records = client.get("/v1/apps?limit=50").get("data") or []
    except RuntimeError as error:
        warn(f"查询失败：{error}")
        records = []
    by_bundle = {((r.get("attributes") or {}).get("bundleId")): r for r in records}
    for app in apps:
        record = by_bundle.get(app["bundleId"])
        if record:
            ok(f"{app['bundleId']} 已有 App 记录：{record['id']}（{((record.get('attributes') or {}).get('name'))}）")
        else:
            warn(f"{app['bundleId']} 没有 App 记录，TestFlight 上传会被拒（No app record found）")
            warn("这一步 API 做不了：/v1/apps 只允许 GET/UPDATE，CREATE 返回 403。要在 App Store Connect 网页里")
            warn("「App → 新建 App」里手建一次（平台 iOS、名称、主要语言、套装 ID、SKU 必填）。建好后重跑本命令确认。")
            if app.get("sku"):
                print(f"    建议填：名称={app['appName']}  SKU={app['sku']}  语言={app.get('primaryLocale') or '按需'}")

    step("GitHub CLI")
    ok("已安装") if has_gh() else warn("未安装：winget install --id GitHub.cli -e")
    return 0


# ------------------------------------------------------------------ 手工描述文件

def write_profile_b64(cfg: dict, out_dir: Path, dev_profile: Path | None,
                      dist_profile: Path | None) -> int:
    """校验手工下载的描述文件，并写出可直接粘进 GitHub secrets 的 base64 文件。

    这条路径不需要 gh，也不需要 API 密钥 —— 在 portal 能下载、但 API 还登不进去的时候用。
    """
    apps = expand_apps(cfg)
    primary = apps[0]
    slug = slug_of(primary["bundleId"])
    out_dir.mkdir(parents=True, exist_ok=True)

    tasks = [("dev", dev_profile, f"{slug}.dev.mobileprovision"),
             ("appstore", dist_profile, f"{slug}.appstore.mobileprovision")]
    produced = 0
    for label, path, name in tasks:
        if not path:
            continue
        if not path.is_file():
            raise SystemExit(f"找不到描述文件：{path}")
        covers, info = describe_profile(path, primary["bundleId"])
        step(f"描述文件 {path.name}")
        ok(f"Name={info['name']}  UUID={info['uuid']}  AppID={info['appIdentifier']}")
        ok(f"设备 {info['devices']} 台  get-task-allow={info['getTaskAllow']}  App Group={info['appGroups']}")
        if not covers:
            raise SystemExit(
                f"这个描述文件的 App ID 是 {info['appIdentifier']}，覆盖不到 {primary['bundleId']}。"
                "在 portal 里为当前 Bundle ID 重新生成一个。"
            )
        if label == "dev" and not info["getTaskAllow"]:
            warn("这是发布描述文件，get-task-allow=false，不能用来装到测试设备。")
        if label == "dev" and info["devices"] == 0:
            warn("开发描述文件里没有设备，装不到真机。")
        if info["appGroups"] and primary["appGroup"] not in info["appGroups"]:
            warn(f"描述文件没带 {primary['appGroup']}，App Group 会失效。")

        target = out_dir / f"{name}.b64"
        target.write_text(base64.b64encode(path.read_bytes()).decode(), encoding="utf-8")
        ok(f"写出 {target}（{target.stat().st_size} 字节）")
        produced += 1

    if not produced:
        raise SystemExit("没给 --dev-profile 也没给 --dist-profile，没有可写的东西。")
    print()
    step("下一步")
    ok("GitHub → Settings → Secrets and variables → Actions → New repository secret，")
    ok("名字用 DEV_PROVISION_PROFILE（或 DIST_PROVISION_PROFILE），值粘贴上面 .b64 文件的全部内容。")
    return 0


# ------------------------------------------------------------------ 入口

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="App Store 开发者账户与 GitHub 配置")
    parser.add_argument("command", choices=("check", "provision", "github", "profile", "secrets"))
    parser.add_argument("--apply", action="store_true", help="真正执行写操作（默认只打印计划）")
    parser.add_argument("--add-devices", action="store_true", help="允许在账户里登记配置中缺失的设备 UDID")
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--dev-profile", type=Path, default=None,
                        help="手工下载的开发描述文件；给了就直接用它，跳过 API 产物")
    parser.add_argument("--dist-profile", type=Path, default=None,
                        help="手工下载的 App Store 描述文件")
    args = parser.parse_args(argv)

    cfg = load_config(args.config, require_api=args.command != "profile")
    if args.command == "check":
        return check(cfg)
    if args.command == "provision":
        return provision(cfg, args.apply, args.out_dir, args.add_devices)
    if args.command == "profile":
        return write_profile_b64(cfg, args.out_dir, args.dev_profile, args.dist_profile)
    if args.command == "secrets":
        return export_secrets(cfg, args.out_dir, args.dev_profile, args.dist_profile)
    return github(cfg, args.apply, args.out_dir, args.dev_profile, args.dist_profile)


if __name__ == "__main__":
    sys.exit(main())
