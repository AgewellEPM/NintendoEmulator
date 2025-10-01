#!/bin/bash

# TLS Certificate Setup Script
# Generates and pins TLS certificates for the authentication API

set -e

echo "🔐 Nintendo Emulator - Certificate Pinning Setup"
echo "==============================================="
echo ""

# Default API hostname
API_HOST="${API_HOST:-api.nintendoemulator.app}"
API_PORT="${API_PORT:-443}"

echo "Target API: $API_HOST:$API_PORT"
echo ""

# Check if openssl is available
if ! command -v openssl &> /dev/null; then
    echo "❌ openssl not found. Please install it first:"
    echo "   brew install openssl"
    exit 1
fi

# Create certificates directory
CERT_DIR="$(pwd)/Certificates"
mkdir -p "$CERT_DIR"

echo "📥 Downloading certificate from $API_HOST..."
echo ""

# Download certificate
openssl s_client -connect "$API_HOST:$API_PORT" -showcerts < /dev/null 2>/dev/null | \
    sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > "$CERT_DIR/api-nintendoemulator-app.pem"

if [ ! -s "$CERT_DIR/api-nintendoemulator-app.pem" ]; then
    echo "❌ Failed to download certificate"
    echo ""
    echo "Possible reasons:"
    echo "1. Server is not running at $API_HOST:$API_PORT"
    echo "2. Firewall blocking connection"
    echo "3. DNS resolution failed"
    echo ""
    echo "For local testing, you can skip certificate pinning"
    exit 1
fi

# Convert PEM to DER format (required by iOS/macOS)
openssl x509 -in "$CERT_DIR/api-nintendoemulator-app.pem" \
             -outform der \
             -out "$CERT_DIR/api-nintendoemulator-app.cer"

echo "✅ Certificate downloaded successfully"
echo ""
echo "📋 Certificate info:"
openssl x509 -in "$CERT_DIR/api-nintendoemulator-app.pem" -noout -subject -issuer -dates

echo ""
echo "📝 Next steps:"
echo ""
echo "1. Add certificate to Xcode project:"
echo "   - Open NintendoEmulator.xcodeproj in Xcode"
echo "   - Drag $CERT_DIR/api-nintendoemulator-app.cer to project"
echo "   - Ensure 'Copy items if needed' is checked"
echo "   - Add to target: NintendoEmulator"
echo ""
echo "2. Optional: Create backup certificate for rotation"
echo "   - Download backup from staging/backup server"
echo "   - Name it: api-nintendoemulator-app-backup.cer"
echo ""
echo "3. Verify certificate pinning:"
echo "   - Build and run app"
echo "   - Check console for: '✅ Certificate pinning enabled'"
echo ""
echo "🔄 Certificate rotation:"
echo "- Certificate expires: $(openssl x509 -in $CERT_DIR/api-nintendoemulator-app.pem -noout -enddate)"
echo "- Plan rotation 30 days before expiry"
echo "- Always pin both old and new certs during rotation"
echo ""