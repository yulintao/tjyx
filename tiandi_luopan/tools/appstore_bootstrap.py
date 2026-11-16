#!/usr/bin/env python3
"""一次性把一个新 App 在 App Store Connect 上需要的东西全部建出来。

编排 appstore_setup.py 里的原子动作，再加上它没有的两件：
  * 需要时生成签名证书（RSA 2048 → CSR → 上传 → 拿回 .cer → 打成 .p12）；
  * 建 App Store Connect 里的 App 记录（出现在「我的 App」里的那一条）。

一条命令的顺序：
  1. Bundle ID（已存在就复用）
  2. App Group 能力（组本身要在 portal 建，公开 API 没有这个端点）
  3. 设备 UDID 登记
  4. 证书：账户里没有可用的就当场生成（需 --create-certificates）
  5. 开发描述文件 + App Store 描述文件
  6. App 记录（需 --create-app-record，缺 sku 会失败）
  7. 产物落盘 + manifest.json
  8. 写 GitHub secrets / variables / environment（可 --skip-github）

默认 dry-run。加 --apply 才发写请求。

用法：
    python tools/appstore_bootstrap.py            # 看全流程计划
    python tools/appstore_bootstrap.py --apply --create-certificates --create-app-record
    python tools/appstore_bootstrap.py selfcheck  # 离线验证证书与 .p12 那段实现
"""
from __future__ import annotations

import argparse
import base64
import json
import secrets
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from appstore_setup import (  # noqa: E402
    AscClient,
    add_app_group_capability,
    create_bundle_id,
    create_profile,
    expand_apps,
    get_bundle_id,
    github,
    list_certificates,
    list_devices,
    list_profiles,
    load_config,
    make_jwt,
    ok,
    plan,
    register_devices,
    save_profile,
    slug_of,
    step,
    warn,
)

ASC_TYPE_DEV = "IOS_DEVELOPMENT"
ASC_TYPE_DIST = "IOS_DISTRIBUTION"
ASC_PROFILE_DEV = "IOS_APP_DEVELOPMENT"
ASC_PROFILE_STORE = "IOS_APP_STORE"


# ------------------------------------------------------------------ 证书

def build_self_signed_p12(common_name: str, password: str, out_path: Path,
                          days: int = 365) -> Path:
    """生成 RSA 密钥 + 自签证书 → PKCS#12。selfcheck 用它证明密码学链路可用。"""
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.hazmat.primitives.serialization import pkcs12
    from cryptography.x509.oid import NameOID

    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, common_name)])
    from datetime import datetime, timedelta, timezone

    now = datetime.now(timezone.utc)
    cert = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(subject)
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now)
        .not_valid_after(now + timedelta(days=days))
        .sign(key, hashes.SHA256())
    )
    bundle = pkcs12.serialize_key_and_certificates(
        name=common_name.encode(),
        key=key,
        cert=cert,
        cas=None,
        encryption_algorithm=serialization.BestAvailableEncryption(password.encode()),
    )
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(bundle)
    return out_path


def create_certificate(client: AscClient, cert_type: str, common_name: str,
                       label: str, out_dir: Path, password: str) -> dict | None:
    """向苹果申请一张证书，并把私钥与证书打成 .p12 落盘。只能 --apply 时执行。"""
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.hazmat.primitives.serialization import pkcs12
    from cryptography.x509.oid import NameOID

    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    csr = (
        x509.CertificateSigningRequestBuilder()
        .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, common_name)]))
        .sign(key, hashes.SHA256())
    )
    body = {
        "data": {
            "type": "certificates",
            "attributes": {
                "csrContent": csr.public_bytes(serialization.Encoding.PEM).decode(),
                "certificateType": cert_type,
            },
        }
    }
    created = client.post("/v1/certificates", body)
    if not created:
        return None

    payload = created["data"]
    certificate = x509.load_der_x509_certificate(base64.b64decode(payload["attributes"]["certificateContent"]))
    bundle = pkcs12.serialize_key_and_certificates(
        name=common_name.encode(),
        key=key,
        cert=certificate,
        cas=None,
        encryption_algorithm=serialization.BestAvailableEncryption(password.encode()),
    )

    p12_path = out_dir / f"certificate.{label}.p12"
    out_dir.mkdir(parents=True, exist_ok=True)
    p12_path.write_bytes(bundle)
    b64_path = out_dir / f"{p12_path.name}.b64"
    b64_path.write_text(base64.b64encode(bundle).decode(), encoding="utf-8")

    ok(f"证书已落盘：{p12_path}（序列号 {certificate.serial_number}）")

    return {
        "id": payload["id"],
        "p12": str(p12_path),
        "b64": b64_path.read_text(encoding="utf-8").strip(),
        "label": label,
    }


# ------------------------------------------------------------------ App 记录

def find_app_record(client: AscClient, bundle_id: str) -> dict | None:
    payload = client.get(f"/v1/apps?filter[bundleId]={bundle_id}&limit=10")
    data = payload.get("data") or []
    return data[0] if data else None


def create_app_record(client: AscClient, bundle_id: str, name: str,
                      sku: str, locale: str) -> dict | None:
    """在 ASC 里建 App（出现在「我的 App」列表的那一条）。

    注意：这个端点在公开 API 上属于后加的能力，权限要 Admin；sku 缺失会直接被拒，
    所以失败只当警告，不阻断后面的步骤。
    """
    body = {
        "data": {
            "type": "apps",
            "attributes": {
                "bundleId": bundle_id,
                "name": name,
                "sku": sku,
                "primaryLocale": locale,
            },
        }
    }
    return client.post("/v1/apps", body)


# ------------------------------------------------------------------ selfcheck

def selfcheck(password: str, out_dir: Path) -> int:
    step("离线验证：RSA → 自签证书 → PKCS#12 → 回读")
    p12 = build_self_signed_p12("TJYX selfcheck", password, out_dir / "selfcheck.p12")

    from cryptography.hazmat.primitives.serialization import pkcs12
    loaded_key, loaded_cert, extra = pkcs12.load_key_and_certificates(
        p12.read_bytes(), password.encode())
    ok(f"写入 {p12}（{p12.stat().st_size} 字节）")
    ok(f"回读成功：证书 CN={loaded_cert.subject.rfc4514_string()}，私钥 {loaded_key.key_size} 位")
    if extra:
        warn(f"附带证书链 {len(extra)} 张")
    p12.unlink()
    ok("临时文件已删除")
    return 0


# ------------------------------------------------------------------ 主流程

def run(cfg: dict, apply: bool, out_dir: Path, create_certs: bool,
        create_record: bool, skip_github: bool, password: str,
        add_devices: bool) -> int:
    apps = expand_apps(cfg)

    step("凭据")
    jwt = make_jwt(cfg["apiKeyId"], cfg["issuerId"], cfg["_keyPath"])
    ok(f"JWT 已签发（{len(jwt)} 字节）")
    client = AscClient(jwt, apply)

    step("现有证书")
    dev_cert = next((c for c in list_certificates(client, ASC_TYPE_DEV)
                     if c["attributes"]["status"] == "ACTIVE"), None)
    dist_cert = next((c for c in list_certificates(client, ASC_TYPE_DIST)
                      if c["attributes"]["status"] == "ACTIVE"), None)
    if dev_cert:
        ok(f"开发证书：{dev_cert['id']}")
    if dist_cert:
        ok(f"发布证书：{dist_cert['id']}")
    if not dev_cert or not dist_cert:
        if not create_certs:
            warn("账户里缺少可用的开发/发布证书；加 --create-certificates 让脚本当场生成")
        elif not apply:
            plan("将生成缺失的证书（RSA 2048 → CSR → POST /v1/certificates → .p12）")
        else:
            for cert_type, label in ((ASC_TYPE_DEV, "开发"), (ASC_TYPE_DIST, "发布")):
                existing = dev_cert if cert_type == ASC_TYPE_DEV else dist_cert
                if existing:
                    continue
                step(f"生成{label}证书")
                try:
                    made = create_certificate(client, cert_type, f"TJYX {label} {int(time.time())}",
                                              "dev" if cert_type == ASC_TYPE_DEV else "dist",
                                              out_dir, password)
                except Exception as error:  # 证书额度、CSR 校验等都可能在这里失败
                    warn(f"{label}证书生成失败：{error}")
                    warn("团队证书额度已满时（发布证书常见上限 2 张），去 portal 吊销一张旧的再跑。")
                    continue
                if made:
                    ok(f"已生成：{made['id']} → {made['p12']}")
                    if cert_type == ASC_TYPE_DEV:
                        dev_cert = {"id": made["id"]}
                        cfg["certP12Base64Dev"] = made["b64"]
                    else:
                        dist_cert = {"id": made["id"]}
                        cfg["certP12Base64Dist"] = made["b64"]

    manifest = []
    for app in apps:
        print()
        step(f"=== {app['bundleId']}  ({app['appName']})")
        record = {"bundleId": app["bundleId"], "appName": app["appName"], "appGroup": app["appGroup"],
                  "appBundleIdId": "", "groupCapability": False, "appRecordId": "",
                  "devProfileId": "", "distProfileId": "", "files": []}

        step(f"1) Bundle ID")
        try:
            bundle = get_bundle_id(client, app["bundleId"])
        except RuntimeError as error:
            warn(f"查询失败：{error}")
            return 1
        if bundle:
            record["appBundleIdId"] = bundle["id"]
            ok(f"已存在：{bundle['id']}")
        elif apply:
            created = create_bundle_id(client, app["bundleId"], app["appName"])
            record["appBundleIdId"] = ((created or {}).get("data") or {}).get("id", "")
            ok(f"已创建：{record['appBundleIdId']}")
        else:
            plan(f"将创建 Bundle ID {app['bundleId']}")
            warn("没有 Bundle ID 的 id 走不下去，加 --apply 再来。")
            return 0

        step("2) App Group 能力")
        if apply:
            try:
                add_app_group_capability(client, record["appBundleIdId"], app["appGroup"])
                record["groupCapability"] = True
                ok("已挂上")
            except RuntimeError as error:
                warn(f"没挂上：{error}")
                warn("组本身要在 portal 的 Identifiers → App Groups 里先建好；建好后这里重跑即可。")
        else:
            plan(f"将挂上 {app['appGroup']}")

        step("3) 设备")
        device_ids = register_devices(client, app["devices"], add_devices)

        step("4) 描述文件")
        if dev_cert:
            found = [p for p in list_profiles(client, ASC_PROFILE_DEV)
                     if p["attributes"]["name"] == app["devProfileName"]]
            if found:
                record["devProfileId"] = found[0]["id"]
                ok(f"开发描述文件已存在：{record['devProfileId']}")
            elif apply:
                made = create_profile(client, app["devProfileName"], ASC_PROFILE_DEV,
                                      record["appBundleIdId"], dev_cert["id"], device_ids)
                record["devProfileId"] = ((made or {}).get("data") or {}).get("id", "")
                ok(f"已创建开发描述文件：{record['devProfileId']}")
            else:
                plan(f"将创建开发描述文件 {app['devProfileName']}")
            if record["devProfileId"]:
                record["files"] += save_profile(client, record["devProfileId"],
                                                f"{slug_of(app['bundleId'])}.dev.mobileprovision", out_dir)
        else:
            warn("没有开发证书，开发描述文件跳过")

        if dist_cert:
            found = [p for p in list_profiles(client, ASC_PROFILE_STORE)
                     if p["attributes"]["name"] == app["distProfileName"]]
            if found:
                record["distProfileId"] = found[0]["id"]
                ok(f"发布描述文件已存在：{record['distProfileId']}")
            elif apply:
                made = create_profile(client, app["distProfileName"], ASC_PROFILE_STORE,
                                      record["appBundleIdId"], dist_cert["id"], [])
                record["distProfileId"] = ((made or {}).get("data") or {}).get("id", "")
                ok(f"已创建发布描述文件：{record['distProfileId']}")
            else:
                plan(f"将创建发布描述文件 {app['distProfileName']}")
            if record["distProfileId"]:
                record["files"] += save_profile(client, record["distProfileId"],
                                                f"{slug_of(app['bundleId'])}.appstore.mobileprovision", out_dir)
        else:
            warn("没有发布证书，发布描述文件跳过")

        step("5) App 记录")
        if not create_record:
            plan("跳过（要建「我的 App」里那一条，加 --create-app-record，且配置里要有 sku）")
        else:
            try:
                existing = find_app_record(client, app["bundleId"])
                if existing:
                    record["appRecordId"] = existing["id"]
                    ok(f"已存在：{existing['id']}")
                else:
                    sku = app.get("sku") or f"{app['bundleId']}-{int(time.time())}"
                    locale = app.get("primaryLocale") or "zh-Hans"
                    if not apply:
                        plan(f"将创建 App 记录 sku={sku} primaryLocale={locale}")
                    else:
                        made = create_app_record(client, app["bundleId"], app["appName"], sku, locale)
                        record["appRecordId"] = ((made or {}).get("data") or {}).get("id", "")
                        if record["appRecordId"]:
                            ok(f"已创建：{record['appRecordId']}")
            except RuntimeError as error:
                warn(f"App 记录这一步失败：{error}")
                warn("这个端点要求 Admin 角色且 sku 必填；失败不影响 Bundle ID 与描述文件。")

        manifest.append(record)

    out_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = out_dir / "manifest.json"
    data = {
        "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "teamId": cfg["teamId"],
        "appCount": len(manifest),
        "certificates": {"dev": (dev_cert or {}).get("id", ""), "dist": (dist_cert or {}).get("id", "")},
        "apps": manifest,
    }
    manifest_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print()
    step("产物")
    ok(str(manifest_path))

    if skip_github:
        step("GitHub 已跳过")
        return 0
    print()
    return github(cfg, apply, out_dir)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="新 App 在 App Store Connect 上的一次性建档")
    parser.add_argument("command", nargs="?", default="run", choices=("run", "selfcheck"))
    parser.add_argument("--apply", action="store_true", help="真正发写请求")
    parser.add_argument("--create-certificates", action="store_true", help="账户缺证书时当场生成")
    parser.add_argument("--create-app-record", action="store_true", help="建「我的 App」里的那一条（需 sku）")
    parser.add_argument("--skip-github", action="store_true")
    parser.add_argument("--add-devices", action="store_true")
    parser.add_argument("--password", default="", help="生成的 .p12 密码；空则随机生成并写进配置")
    parser.add_argument("--config", type=Path, default=Path(__file__).resolve().parent / "appstore_setup.config.json")
    parser.add_argument("--out-dir", type=Path, default=Path(__file__).resolve().parent / "appstore_out")
    args = parser.parse_args(argv)

    password = args.password or secrets.token_urlsafe(12)
    if args.command == "selfcheck":
        return selfcheck(password, args.out_dir)

    cfg = load_config(args.config)
    cfg["certP12Password"] = password
    if not args.password:
        if args.skip_github or not args.apply:
            print(f"    本次 .p12 密码（只在需要时抄走）：{password}")
        else:
            print("    .p12 密码由脚本随机生成，会写进 GitHub secret P；不在这里打印。")
    return run(cfg, args.apply, args.out_dir, args.create_certificates,
               args.create_app_record, args.skip_github, password, args.add_devices)


if __name__ == "__main__":
    sys.exit(main())
