#!/usr/bin/env python3
"""Build the Edge Connector Chrome Native package (single source of truth).

Run from anywhere:  python tools/build_native_package.py [--skip-tests]

Reads   native-src/      Go native messaging host (+ resources/)
        native-package/  extension files and installer/readme templates
Writes  extension/Edge_Connector_Chrome_Native_v<ver>.zip
        extension/native-version.json

Why this exists: the installer inside the package verifies the host exe against
EXPECTED_HOST_SHA. That value used to be pasted by hand and went stale (v1.1.11,
v1.1.12), making every install fail at "Native Host SHA-256 mismatch". Here the
hash is computed from the exe that is actually packaged, then re-verified.

Requirements: go (1.22+), python 3.8+. Optional: x86_64-w64-mingw32-windres
(adds Windows version info + asInvoker manifest). Optional signing: set
SIGN_CMD to a command template containing {file}, e.g.
  SIGN_CMD='signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /a "{file}"'
"""
import argparse, hashlib, json, os, re, shutil, subprocess, sys, tempfile, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC, PKG, OUT = ROOT / "native-src", ROOT / "native-package", ROOT / "extension"
EXT_ID = "afpojmpdnpchpnomphpphmhbdehpbenl"
HOST_NAME = "com.etech.edgeconnector"


def run(cmd, **kw):
    print("  $", " ".join(map(str, cmd)))
    subprocess.run(cmd, check=True, **kw)


def host_version():
    m = re.search(r'hostVersion\s*=\s*"([0-9.]+)"', (SRC / "main.go").read_text(encoding="utf-8"))
    if not m:
        sys.exit("hostVersion not found in native-src/main.go")
    return m.group(1)


def sha256(path_or_bytes):
    data = path_or_bytes if isinstance(path_or_bytes, bytes) else Path(path_or_bytes).read_bytes()
    return hashlib.sha256(data).hexdigest()


def crlf(text):
    return text.replace("\r\n", "\n").replace("\n", "\r\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-tests", action="store_true")
    args = ap.parse_args()
    ver = host_version()
    print(f"== Edge Connector Native package v{ver}")

    if not args.skip_tests:
        print("[1] go test")
        run(["go", "test", "-count=1", "./..."], cwd=SRC)

    with tempfile.TemporaryDirectory() as td:
        build = Path(td)
        print("[2] prepare build dir")
        for f in SRC.glob("*.go"):
            if not f.name.endswith("_test.go"):
                shutil.copy(f, build / f.name)
        shutil.copy(SRC / "go.mod", build / "go.mod")

        windres = shutil.which("x86_64-w64-mingw32-windres")
        if windres:
            nums = (ver.split(".") + ["0"] * 4)[:4]
            rc = (SRC / "resources" / "host.rc.tpl").read_text().replace("@COMMA@", ",".join(nums)).replace("@VER@", ver)
            (build / "host.rc").write_text(rc)
            shutil.copy(SRC / "resources" / "host.manifest", build / "host.manifest")
            run([windres, "-O", "coff", "-i", "host.rc", "-o", "resource_windows_amd64.syso"], cwd=build)
        else:
            print("  ! windres not found: building without version info / manifest resources")

        print("[3] go build (windows/amd64)")
        exe = build / "EdgeConnectorNativeHost.exe"
        env = dict(os.environ, GOOS="windows", GOARCH="amd64", CGO_ENABLED="0")
        run(["go", "build", "-trimpath", "-o", str(exe), "."], cwd=build, env=env)

        sign = os.environ.get("SIGN_CMD")
        if sign:
            print("[4] sign")
            run(sign.format(file=exe), shell=True)
        else:
            print("[4] SIGN_CMD not set: exe is UNSIGNED (endpoint protection may flag it)")

        exe_bytes = exe.read_bytes()
        host_sha = sha256(exe_bytes).upper()
        print(f"[5] host sha256 {host_sha}")

        print("[6] assemble zip")
        installer_name = f"Install_Edge_Connector_Chrome_Native_v{ver}.cmd"
        installer = (PKG / "Install_Edge_Connector_Chrome_Native.cmd.tpl").read_text(encoding="utf-8")
        installer = installer.replace("{{VERSION}}", ver).replace("{{HOST_SHA}}", host_sha)
        readme = (PKG / "README_KO.txt.tpl").read_text(encoding="utf-8").replace("{{VERSION}}", ver).replace("{{HOST_SHA}}", host_sha)

        OUT.mkdir(exist_ok=True)
        zip_name = f"Edge_Connector_Chrome_Native_v{ver}.zip"
        zip_path = OUT / zip_name
        stamp = (2026, 1, 1, 0, 0, 0)

        def add(zf, name, data):
            zi = zipfile.ZipInfo(name, date_time=stamp)
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.external_attr = 0o644 << 16
            zf.writestr(zi, data)

        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for f in sorted((PKG / "extension").rglob("*")):
                if f.is_file():
                    data = f.read_bytes()
                    rel = f.relative_to(PKG).as_posix()
                    if rel == "extension/manifest.json":
                        data = re.sub(rb'("version"\s*:\s*")[0-9.]+(")', rb"\g<1>" + ver.encode() + rb"\g<2>", data, count=1)
                    add(zf, rel, data)
            add(zf, "native/EdgeConnectorNativeHost.exe", exe_bytes)
            for f in sorted(SRC.glob("*.go")):
                if not f.name.endswith("_test.go"):
                    add(zf, f"native/src/{f.name}", f.read_bytes())
            add(zf, "native/src/go.mod", (SRC / "go.mod").read_bytes())
            add(zf, installer_name, crlf(installer).encode("utf-8"))
            add(zf, "Uninstall_Edge_Connector_Native_Host.cmd", crlf((PKG / "Uninstall_Edge_Connector_Native_Host.cmd").read_text(encoding="utf-8")).encode("utf-8"))
            add(zf, "README_KO.txt", readme.encode("utf-8"))

    zsha = sha256(zip_path)
    meta = {
        "version": ver,
        "package": zip_name,
        "sha256": zsha,
        "installer": installer_name,
        "edgeConnectorVersionSource": "../downloads/version.json",
        "extensionId": EXT_ID,
        "nativeHost": HOST_NAME,
    }
    (OUT / "native-version.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")

    print("[7] verify package")
    with zipfile.ZipFile(zip_path) as z:
        assert z.testzip() is None
        cmd = z.read(installer_name).decode("utf-8")
        expected = re.search(r"EXPECTED_HOST_SHA=([0-9A-Fa-f]{64})", cmd).group(1).upper()
        actual = sha256(z.read("native/EdgeConnectorNativeHost.exe")).upper()
        assert expected == actual, f"installer expects {expected} but exe is {actual}"
        mv = json.loads(z.read("extension/manifest.json"))["version"]
        assert mv == ver, f"manifest version {mv} != {ver}"
        assert "{{" not in cmd and "{{" not in z.read("README_KO.txt").decode("utf-8"), "unreplaced template token"
    assert json.loads((OUT / "native-version.json").read_text())["sha256"] == sha256(zip_path)
    print(f"OK  {zip_path.relative_to(ROOT)}  sha256={zsha}")
    stale = [p.name for p in OUT.glob("Edge_Connector_Chrome_Native_v*.zip") if p.name != zip_name]
    if stale:
        print("NOTE: older packages still present, delete them from the repo:", ", ".join(stale))


if __name__ == "__main__":
    main()
