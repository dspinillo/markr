#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Markr"
APP_BUNDLE="${PROJECT_DIR}/build/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

cd "${PROJECT_DIR}"

if [ ! -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]; then
    echo "🎨 Gerando AppIcon.icns..."
    swift "${PROJECT_DIR}/scripts/generate-icon.swift"
fi

echo "🔨 Compilando ${APP_NAME} (Release)..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"

# Atualiza in-place (sem rm -rf no .app) para preservar inode no TCC do macOS
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

if [ -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]; then
    cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

cat > "${CONTENTS_DIR}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>pt-BR</string>
    <key>CFBundleExecutable</key>
    <string>Markr</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.dhiego.Markr</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Markr</string>
    <key>CFBundleDisplayName</key>
    <string>Markr</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>O Markr usa a Acessibilidade para ler o texto marcado, verificar se o campo é editável e identificar o site ou aplicativo de origem.</string>
</dict>
</plist>
EOF

touch "${APP_BUNDLE}"

# Detecta automaticamente certificado Apple Development no Keychain local (preserva TCC entre builds)
AUTO_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -n 1 || true)"
SIGN_IDENTITY="${MARKR_SIGN_IDENTITY:-${AUTO_IDENTITY}}"

if [ -n "${SIGN_IDENTITY}" ]; then
    codesign --force --deep --sign "${SIGN_IDENTITY}" "${APP_BUNDLE}"
    echo "🔐 Assinado com certificado estável do Keychain"
else
    codesign --force --deep --sign - "${APP_BUNDLE}"
    echo "⚠️ Nenhum certificado Apple Development encontrado; assinado em modo ad-hoc."
fi

echo "✅ App gerado em: ${APP_BUNDLE}"
