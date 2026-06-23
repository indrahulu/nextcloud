#!/bin/bash
#
# Smoke test untuk Nextcloud Docker Image
# Penggunaan: ./tests/smoke-test.sh <NEXTCLOUD_VERSION>
# Contoh:     ./tests/smoke-test.sh 31.0-apache
#

set -euo pipefail

# ── Warna untuk output ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
IMAGE_NAME="indrahulu/nextcloud"
CONTAINER_NAME="nextcloud-smoke-test"
STARTUP_WAIT=15

# ── Helper functions ──────────────────────────────────────────────────
pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

section() {
    echo ""
    echo -e "${YELLOW}── $1 ──${NC}"
}

cleanup() {
    docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1 || true
}

# ── Validasi input ────────────────────────────────────────────────────
if [ -z "${1:-}" ]; then
    echo "Penggunaan: $0 <NEXTCLOUD_VERSION>"
    echo "Contoh:     $0 31.0-apache"
    exit 1
fi

NEXTCLOUD_VERSION="$1"
TAG="${IMAGE_NAME}:${NEXTCLOUD_VERSION}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "============================================"
echo " Smoke Test: ${TAG}"
echo "============================================"

# ── Cleanup sebelum test ──────────────────────────────────────────────
cleanup
trap cleanup EXIT

# ══════════════════════════════════════════════════════════════════════
# 1 & 2. IMAGE VALIDATION
# ══════════════════════════════════════════════════════════════════════
section "Image Validation"

echo "  Building image..."
if docker build \
    --build-arg NEXTCLOUD_VERSION="$NEXTCLOUD_VERSION" \
    -t "$TAG" \
    "$PROJECT_DIR" > /dev/null 2>&1; then
    pass "Image berhasil di-build"
else
    fail "Image gagal di-build"
    echo ""
    echo -e "${RED}Build gagal, smoke test dihentikan.${NC}"
    exit 1
fi

if docker image inspect "$TAG" > /dev/null 2>&1; then
    pass "Image terdaftar di Docker daemon"
else
    fail "Image tidak ditemukan di Docker daemon"
fi

# ══════════════════════════════════════════════════════════════════════
# 3 & 4. CONTAINER STARTUP
# ══════════════════════════════════════════════════════════════════════
section "Container Startup"

if docker run -d --name "$CONTAINER_NAME" "$TAG" > /dev/null 2>&1; then
    pass "Container berhasil start"
else
    fail "Container gagal start"
    exit 1
fi

echo "  Menunggu ${STARTUP_WAIT} detik agar service siap..."
sleep "$STARTUP_WAIT"

# Cek container masih running
CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
if [ "$CONTAINER_STATUS" = "running" ]; then
    pass "Container masih running (status: $CONTAINER_STATUS)"
else
    fail "Container tidak running (status: $CONTAINER_STATUS)"
    echo ""
    echo "  Logs:"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20 | sed 's/^/    /'
    FAIL_COUNT=$((FAIL_COUNT + 1))
    exit 1
fi

# Cek PID 1 adalah supervisord
PID1_CMD=$(docker exec "$CONTAINER_NAME" cat /proc/1/cmdline 2>/dev/null | tr '\0' ' ' || echo "unknown")
if echo "$PID1_CMD" | grep -q "supervisord"; then
    pass "PID 1 adalah supervisord"
else
    fail "PID 1 bukan supervisord (found: $PID1_CMD)"
fi

# ══════════════════════════════════════════════════════════════════════
# 5, 6, 7, 8, 9, 10. SERVICE HEALTH
# ══════════════════════════════════════════════════════════════════════
section "Service Health"

# 5. Supervisord berjalan
if docker exec "$CONTAINER_NAME" pgrep supervisord > /dev/null 2>&1; then
    pass "Supervisord berjalan"
else
    fail "Supervisord tidak berjalan"
fi

# 6. Apache berjalan
if docker exec "$CONTAINER_NAME" pgrep apache2 > /dev/null 2>&1; then
    pass "Apache berjalan"
else
    fail "Apache tidak berjalan"
fi

# 7. HTTP port 80 merespons
HTTP_CODE=$(docker exec "$CONTAINER_NAME" curl -s -o /dev/null -w "%{http_code}" http://localhost 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    pass "HTTP port 80 merespons (status: $HTTP_CODE)"
else
    fail "HTTP port 80 tidak merespons (status: $HTTP_CODE)"
fi

# 8. HTTPS port 443 merespons
HTTPS_CODE=$(docker exec "$CONTAINER_NAME" curl -sk -o /dev/null -w "%{http_code}" https://localhost 2>/dev/null || echo "000")
if [ "$HTTPS_CODE" = "200" ] || [ "$HTTPS_CODE" = "302" ]; then
    pass "HTTPS port 443 merespons (status: $HTTPS_CODE)"
else
    fail "HTTPS port 443 tidak merespons (status: $HTTPS_CODE)"
fi

# 9. PHP extensions ter-load
for ext in bz2 smbclient; do
    if docker exec "$CONTAINER_NAME" php -m 2>/dev/null | grep -qi "$ext"; then
        pass "PHP extension '$ext' ter-load"
    else
        fail "PHP extension '$ext' tidak ter-load"
    fi
done

# 10. SSL cert ter-generate
if docker exec "$CONTAINER_NAME" test -f /etc/apache2/ssl/cert.pem 2>/dev/null; then
    pass "SSL certificate ada (/etc/apache2/ssl/cert.pem)"
else
    fail "SSL certificate tidak ditemukan"
fi

if docker exec "$CONTAINER_NAME" test -f /etc/apache2/ssl/privkey.pem 2>/dev/null; then
    pass "SSL private key ada (/etc/apache2/ssl/privkey.pem)"
else
    fail "SSL private key tidak ditemukan"
fi

# ══════════════════════════════════════════════════════════════════════
# HASIL
# ══════════════════════════════════════════════════════════════════════
echo ""
echo "============================================"
echo " HASIL: ${GREEN}${PASS_COUNT} passed${NC}, ${RED}${FAIL_COUNT} failed${NC}"
echo "============================================"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
