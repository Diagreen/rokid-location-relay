import importlib.util
import pathlib
import plistlib
import io
import unittest
import zipfile

module_path = pathlib.Path(__file__).parents[1] / "scripts" / "verify_ipa.py"
spec = importlib.util.spec_from_file_location("verify_ipa", module_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PackageVerificationTest(unittest.TestCase):
    def create(self, platform="iPhoneOS", background=True, signed=False):
        file = io.BytesIO()
        info = {"CFBundleIdentifier": "dev.rokid.location", "CFBundleExecutable": "RokidLocation",
                "CFBundlePackageType": "APPL", "CFBundleSupportedPlatforms": [platform],
                "UIBackgroundModes": ["location"] if background else [],
                "NSLocationWhenInUseUsageDescription": "Location", "NSLocationAlwaysAndWhenInUseUsageDescription": "Background location",
                "NSLocalNetworkUsageDescription": "Glasses"}
        with zipfile.ZipFile(file, "w") as archive:
            archive.writestr("Payload/RokidLocation.app/Info.plist", plistlib.dumps(info))
            archive.writestr("Payload/RokidLocation.app/RokidLocation", b"\xcf\xfa\xed\xfe" + b"fixture")
            if signed:
                archive.writestr("Payload/RokidLocation.app/embedded.mobileprovision", b"fixture")
        file.seek(0)
        return file

    def test_accepts_unsigned_device_layout(self):
        self.assertEqual(module.verify(self.create()), "dev.rokid.location")

    def test_rejects_simulator(self):
        with self.assertRaisesRegex(ValueError, "physical iPhone"):
            module.verify(self.create(platform="iPhoneSimulator"))

    def test_rejects_missing_background_mode(self):
        with self.assertRaisesRegex(ValueError, "background location"):
            module.verify(self.create(background=False))

    def test_rejects_unexpected_profile(self):
        with self.assertRaisesRegex(ValueError, "unsigned IPA"):
            module.verify(self.create(signed=True))


if __name__ == "__main__":
    unittest.main()
