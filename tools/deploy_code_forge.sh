#!/bin/bash
# deploy_code_forge.sh — 在 flutter build/run 之后，把 code_forge.framework 部署到 app bundle。
# 用法：
#   flutter build macos --debug && ./deploy_code_forge.sh
#   flutter run --debug   (框架在 run 启动后通过 Makefile 部署)

set -euo pipefail

APP="${FLUTTER_APP:-build/macos/Build/Products/${CONFIGURATION:-Debug}/agent.app}"
PATCH_DIR="$(cd "$(dirname "$0")/../.patches/code_forge" && pwd)"
DYLIB_SRC="$PATCH_DIR/rust/target/release/libcode_forge.dylib"
FWDIR="$APP/Contents/Frameworks/code_forge.framework"

# 1. 编译 code_forge 的 Rust 库（如果还没编译）
if [ ! -f "$DYLIB_SRC" ]; then
  echo "→ 编译 code_forge Rust 库 (from .patches)..."
  (cd "$PATCH_DIR/rust" && cargo build --release)
fi

# 2. 创建 framework 结构
rm -rf "$FWDIR"
mkdir -p "$FWDIR/Versions/A/Resources"
cp "$DYLIB_SRC" "$FWDIR/Versions/A/code_forge"

# 3. Info.plist
cat > "$FWDIR/Versions/A/Resources/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>code_forge</string>
	<key>CFBundleIdentifier</key>
	<string>com.code-forge.rust</string>
	<key>CFBundleName</key>
	<string>code_forge</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>10.8.0</string>
	<key>CFBundleVersion</key>
	<string>10.8.0</string>
	<key>MinimumOSVersion</key>
	<string>10.15</string>
</dict>
</plist>
PLIST

# 4. 软链接（标准 macOS framework 结构）
cd "$FWDIR"
ln -sfh Versions/A/code_forge code_forge
ln -sfh A Versions/Current
ln -sfh Versions/A/Resources Resources

# 5. 改 install name
install_name_tool -id "@rpath/code_forge.framework/code_forge" Versions/A/code_forge 2>/dev/null || true

echo "✅ code_forge.framework 已部署到 $APP"
