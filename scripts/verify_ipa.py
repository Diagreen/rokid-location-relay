"""Inspect an unsigned device IPA; this does not test installation or GPS behavior."""
import plistlib
import sys
import zipfile


def verify(filename):
    with zipfile.ZipFile(filename) as archive:
        bad = archive.testzip()
        if bad:
            raise ValueError(f"Corrupt entry: {bad}")
        infos = [n for n in archive.namelist() if n.startswith("Payload/") and n.count("/") == 2 and n.endswith(".app/Info.plist")]
        if len(infos) != 1:
            raise ValueError("Expected exactly one Payload/*.app/Info.plist")
        info_path = infos[0]
        base = info_path.removesuffix("Info.plist")
        info = plistlib.loads(archive.read(info_path))
        if info.get("CFBundleIdentifier") != "dev.rokid.location":
            raise ValueError("Unexpected bundle identifier")
        if info.get("CFBundlePackageType") != "APPL":
            raise ValueError("Not an application")
        if "location" not in info.get("UIBackgroundModes", []):
            raise ValueError("Missing background location mode")
        for key in ("NSLocationWhenInUseUsageDescription", "NSLocationAlwaysAndWhenInUseUsageDescription", "NSLocalNetworkUsageDescription"):
            if not info.get(key):
                raise ValueError(f"Missing permission description: {key}")
        if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
            raise ValueError("Expected physical iPhone build, not simulator")
        executable = info.get("CFBundleExecutable", "")
        if not executable or "/" in executable or executable in (".", ".."):
            raise ValueError("Invalid executable name")
        magic = archive.read(base + executable)[:4]
        if magic not in (b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca", b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca"):
            raise ValueError("Executable is not Mach-O")
        if any(n == base + "embedded.mobileprovision" or n.startswith(base + "_CodeSignature/") for n in archive.namelist()):
            raise ValueError("Expected unsigned IPA with no embedded signing profile")
        return info["CFBundleIdentifier"]


if __name__ == "__main__":
    print("PASS unsigned iPhone IPA:", verify(sys.argv[1]))
