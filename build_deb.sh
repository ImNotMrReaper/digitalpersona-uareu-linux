#!/usr/bin/env bash
#
# Builds dp4500-fingerprint-auth_1.0.0_amd64.deb for Ubuntu & Debian
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build/deb"
VERSION="1.0.0"
PKG_NAME="dp4500-fingerprint-auth"
ARCH="$(dpkg --print-architecture 2>/dev/null || echo "amd64")"
DEB_FILE="${PKG_NAME}_${VERSION}_${ARCH}.deb"

echo ">>> Building ${DEB_FILE}..."

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/DEBIAN"
mkdir -p "${BUILD_DIR}/usr/local/bin"
mkdir -p "${BUILD_DIR}/usr/local/lib"
mkdir -p "${BUILD_DIR}/lib/security"
mkdir -p "${BUILD_DIR}/etc/systemd/system/fprintd.service.d"

# 1. Compile shared library
echo "    Compiling libfprint_bz3_override.so..."
gcc -O2 -fPIC -shared -o "${BUILD_DIR}/usr/local/lib/libfprint_bz3_override.so" "${SCRIPT_DIR}/src/libfprint_bz3_override.c" -ldl
chmod 755 "${BUILD_DIR}/usr/local/lib/libfprint_bz3_override.so"

# 2. Copy binaries and PAM scripts
cp "${SCRIPT_DIR}/bin/dp-auth" "${BUILD_DIR}/usr/local/bin/dp-auth"
chmod 755 "${BUILD_DIR}/usr/local/bin/dp-auth"

cp "${SCRIPT_DIR}/bin/dp-fingerprint" "${BUILD_DIR}/usr/local/bin/dp-fingerprint"
chmod 755 "${BUILD_DIR}/usr/local/bin/dp-fingerprint"

cp "${SCRIPT_DIR}/pam/dp_fprint_pam.py" "${BUILD_DIR}/lib/security/dp_fprint_pam.py"
chmod 644 "${BUILD_DIR}/lib/security/dp_fprint_pam.py"

cp "${SCRIPT_DIR}/systemd/override.conf" "${BUILD_DIR}/etc/systemd/system/fprintd.service.d/override.conf"
chmod 644 "${BUILD_DIR}/etc/systemd/system/fprintd.service.d/override.conf"

# 3. Control file
cat << EOF > "${BUILD_DIR}/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: admin
Priority: optional
Architecture: ${ARCH}
Depends: fprintd, libfprint-2-2, python3-gi, gir1.2-glib-2.0
Maintainer: Mr. Reaper <admin@reaper.local>
Description: Digital Persona U.are.U 4500 Multi-Device Biometric Engine for Linux
 High-performance biometric driver suite for Digital Persona U.are.U 4000/4000B/4500
 optical fingerprint readers. Provides dynamic NIST Bozorth3 sensitivity tuning,
 continuous optical illumination loops, concurrent multi-device PAM integration,
 and dynamic USB hotplugging.
EOF

# 4. Post-install script
cat << 'EOF' > "${BUILD_DIR}/DEBIAN/postinst"
#!/bin/sh
set -e

ln -sf /usr/local/bin/dp-auth /usr/local/bin/reaper-fprint-auth
ln -sf /usr/local/bin/dp-fingerprint /usr/local/bin/reaper-fingerprint
ln -sf /lib/security/dp_fprint_pam.py /lib/security/reaper_fprint_pam.py

if [ -d /run/systemd/system ]; then
    systemctl daemon-reload || true
    systemctl restart fprintd || true
fi

configure_pam() {
    file="$1"
    if [ -f "$file" ] && ! grep -q "dp_fprint_pam.py\|reaper_fprint_pam.py" "$file"; then
        cp "$file" "${file}.bak-dp-auth"
        sed -i '/pam_unix\.so/i auth\tsufficient\tpam_python.so /lib/security/dp_fprint_pam.py' "$file"
    fi
}

configure_pam "/etc/pam.d/sudo"
configure_pam "/etc/pam.d/polkit-1"
configure_pam "/etc/pam.d/common-auth"

echo "Digital Persona 4500 Biometric Engine installed successfully!"
echo "Run 'dp-fingerprint list' or 'dp-fingerprint enroll' to get started."
exit 0
EOF
chmod 755 "${BUILD_DIR}/DEBIAN/postinst"

# 5. Pre-remove script
cat << 'EOF' > "${BUILD_DIR}/DEBIAN/prerm"
#!/bin/sh
set -e

rm -f /usr/local/bin/reaper-fprint-auth
rm -f /usr/local/bin/reaper-fingerprint
rm -f /lib/security/reaper_fprint_pam.py

for file in /etc/pam.d/sudo /etc/pam.d/polkit-1 /etc/pam.d/common-auth; do
    if [ -f "${file}.bak-dp-auth" ]; then
        mv "${file}.bak-dp-auth" "$file"
    elif [ -f "$file" ]; then
        sed -i '/dp_fprint_pam\.py/d' "$file"
    fi
done

if [ -d /run/systemd/system ]; then
    systemctl daemon-reload || true
    systemctl restart fprintd || true
fi

exit 0
EOF
chmod 755 "${BUILD_DIR}/DEBIAN/prerm"

# 6. Build Debian package
dpkg-deb --build --root-owner-group "${BUILD_DIR}" "${SCRIPT_DIR}/${DEB_FILE}"

echo -e "\n🎉 Package created: ${SCRIPT_DIR}/${DEB_FILE}"
echo "   Install on any Debian/Ubuntu system with:"
echo "   sudo dpkg -i ${DEB_FILE}"
