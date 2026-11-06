"""Enable LAN networking in generated Flutter host projects, idempotently."""
from pathlib import Path

manifest = Path('android/app/src/main/AndroidManifest.xml')
if manifest.exists():
    text = manifest.read_text()
    if 'android.permission.INTERNET' not in text:
        text = text.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
    if 'android:usesCleartextTraffic=' not in text:
        text = text.replace('<application', '<application android:usesCleartextTraffic="true"', 1)
    manifest.write_text(text)
for filename in ('DebugProfile.entitlements', 'Release.entitlements'):
    path = Path('macos/Runner') / filename
    if path.exists():
        text = path.read_text()
        if 'com.apple.security.network.client' not in text:
            text = text.replace('</dict>', '<key>com.apple.security.network.client</key>\n<true/>\n</dict>')
        path.write_text(text)
