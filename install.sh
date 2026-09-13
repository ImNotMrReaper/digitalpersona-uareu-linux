#!/usr/bin/env bash
#
# Digital Persona U.are.U 4500 (and 4000/4000B) Linux Driver & Auth Engine Installer
# Compatible with Ubuntu, Debian, Pop!_OS, Linux Mint, Ubuntu Server, Debian Server, Fedora, Arch
#

set -e

GREEN="\033[1;32m"
BLUE="\033[1;34m"
PURPLE="\033[1;35m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

echo -e "${PURPLE}================================================================${RESET}"
echo -e "${BLUE} 🛡️  Digital Persona U.are.U 4500 Multi-Device Biometric Engine${RESET}"
echo -e "${PURPLE}================================================================${RESET}"

# Require root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ Please run this installer with sudo:${RESET}"
    echo -e "   sudo ./install.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
TARGET_USER="${SUDO_USER:-$USER}"

# Auto-clone repository if executed directly from curl/pipe
if [ ! -d "${SCRIPT_DIR}/src" ] || [ ! -f "${SCRIPT_DIR}/src/libfprint_bz3_override.c" ]; then
    echo ">>> Running from remote pipe. Cloning latest repository..."
    TMP_CLONE="$(mktemp -d /tmp/dp4500-install.XXXXXX)"
    if ! command -v git >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then apt-get update -qq && apt-get install -y -qq git;
        elif command -v dnf >/dev/null 2>&1; then dnf install -y git;
        elif command -v pacman >/dev/null 2>&1; then pacman -Sy --needed --noconfirm git;
        elif command -v zypper >/dev/null 2>&1; then zypper --non-interactive install git; fi
    fi
    git clone --depth 1 https://github.com/ImNotMrReaper/digitalpersona-uareu-linux.git "${TMP_CLONE}"
    SCRIPT_DIR="${TMP_CLONE}"
    trap "rm -rf '${TMP_CLONE}'" EXIT
fi

echo -e "\n${BLUE}>>> Step 1: Detecting Package Manager & Installing Dependencies...${RESET}"
if command -v apt-get >/dev/null 2>&1; then
    echo -e "    Detected Debian/Ubuntu-based distribution."
    apt-get update -qq
    apt-get install -y -qq fprintd libfprint-2-2 libpam-fprintd gcc build-essential python3-gi gir1.2-glib-2.0
    # Optional pam-python if available
    apt-get install -y -qq libpam-python 2>/dev/null || true
elif command -v dnf >/dev/null 2>&1; then
    echo -e "    Detected Fedora/RHEL-based distribution."
    dnf install -y fprintd libfprint gcc glib2-devel python3-gobject
elif command -v pacman >/dev/null 2>&1; then
    echo -e "    Detected Arch Linux distribution."
    pacman -S --needed --noconfirm fprintd libfprint gcc glib2 python-gobject
elif command -v zypper >/dev/null 2>&1; then
    echo -e "    Detected openSUSE distribution."
    zypper --non-interactive install fprintd libfprint-2-2 gcc glib2-devel python3-gobject || true
else
    echo -e "${YELLOW}⚠️  Unknown package manager. Please ensure fprintd, libfprint, and gcc are installed.${RESET}"
fi

echo -e "\n${BLUE}>>> Step 2: Compiling Bozorth3 Match Threshold Tuner...${RESET}"
mkdir -p /usr/local/lib
gcc -O2 -fPIC -shared -o /usr/local/lib/libfprint_bz3_override.so "${SCRIPT_DIR}/src/libfprint_bz3_override.c" -ldl
chmod 755 /usr/local/lib/libfprint_bz3_override.so
echo -e "    ${GREEN}✓ Compiled:${RESET} /usr/local/lib/libfprint_bz3_override.so"

echo -e "\n${BLUE}>>> Step 3: Installing Binaries & PAM Bridge...${RESET}"
mkdir -p /usr/local/bin /lib/security

cp "${SCRIPT_DIR}/bin/dp-auth" /usr/local/bin/dp-auth
chmod 755 /usr/local/bin/dp-auth
ln -sf /usr/local/bin/dp-auth /usr/local/bin/reaper-fprint-auth

cp "${SCRIPT_DIR}/bin/dp-fingerprint" /usr/local/bin/dp-fingerprint
chmod 755 /usr/local/bin/dp-fingerprint
ln -sf /usr/local/bin/dp-fingerprint /usr/local/bin/reaper-fingerprint

cp "${SCRIPT_DIR}/pam/dp_fprint_pam.py" /lib/security/dp_fprint_pam.py
chmod 644 /lib/security/dp_fprint_pam.py
ln -sf /lib/security/dp_fprint_pam.py /lib/security/reaper_fprint_pam.py

echo -e "    ${GREEN}✓ Installed:${RESET} /usr/local/bin/dp-auth (CLI: dp-auth)"
echo -e "    ${GREEN}✓ Installed:${RESET} /usr/local/bin/dp-fingerprint (CLI: dp-fingerprint)"
echo -e "    ${GREEN}✓ Installed:${RESET} /lib/security/dp_fprint_pam.py"

echo -e "\n${BLUE}>>> Step 4: Configuring Systemd Service Override...${RESET}"
mkdir -p /etc/systemd/system/fprintd.service.d
cp "${SCRIPT_DIR}/systemd/override.conf" /etc/systemd/system/fprintd.service.d/override.conf
chmod 644 /etc/systemd/system/fprintd.service.d/override.conf

systemctl daemon-reload
systemctl restart fprintd || true
echo -e "    ${GREEN}✓ Configured & Reloaded:${RESET} fprintd.service with Bozorth3 sensitivity override"

echo -e "\n${BLUE}>>> Step 5: Configuring PAM Security Authentication...${RESET}"
# Ensure pam configuration exists
configure_pam_service() {
    local pam_file="$1"
    if [ -f "$pam_file" ]; then
        if ! grep -q "dp_fprint_pam.py\|reaper_fprint_pam.py" "$pam_file"; then
            cp "$pam_file" "${pam_file}.bak-dp-auth"
            # Add before pam_unix
            sed -i '/pam_unix\.so/i auth\tsufficient\tpam_python.so /lib/security/dp_fprint_pam.py' "$pam_file"
            echo -e "    ${GREEN}✓ Updated:${RESET} ${pam_file}"
        else
            echo -e "    ${YELLOW}ℹ️  Already configured:${RESET} ${pam_file}"
        fi
    fi
}

configure_pam_service "/etc/pam.d/sudo"
configure_pam_service "/etc/pam.d/polkit-1"
configure_pam_service "/etc/pam.d/common-auth"

echo -e "\n${GREEN}================================================================${RESET}"
echo -e "${GREEN} 🎉 INSTALLATION COMPLETED SUCCESSFULLY!${RESET}"
echo -e "${GREEN}================================================================${RESET}"
echo -e "Your Digital Persona U.are.U 4500 is now armed with:"
echo -e "  • Tuned Bozorth3 matching threshold (14/40) for fast, authentic touch matches"
echo -e "  • Continuous blue LED illumination with atomic 50ms re-arm loops"
echo -e "  • Seamless multi-device concurrency (built-in laptop sensors + external USB)"
echo -e "  • Dynamic USB hotplugging and zero-lockout password fallbacks"
echo -e "\n${BLUE}Quick Commands:${RESET}"
echo -e "  ${PURPLE}dp-fingerprint list${RESET}          - View all detected devices & enrolled prints"
echo -e "  ${PURPLE}dp-fingerprint enroll${RESET}        - Enroll a finger on the USB scanner (6 touches)"
echo -e "  ${PURPLE}dp-fingerprint verify${RESET}        - Test live verification on the USB scanner"
echo -e "  ${PURPLE}dp-auth${RESET}                      - Test concurrent multi-sensor authentication"
echo -e ""

# Interactive enrollment prompt if attached to a terminal
if [ -t 0 ] || [ -r /dev/tty ]; then
    echo -ne "\033[1;33mWould you like to enroll a fingerprint now on your scanner? [Y/n]: \033[0m"
    read -r ENROLL_PROMPT < /dev/tty || ENROLL_PROMPT="y"
    if [[ "$ENROLL_PROMPT" =~ ^[Yy]?$ ]]; then
        echo -e "\nStarting interactive fingerprint enrollment for \033[1m${TARGET_USER}\033[0m...\n"
        dp-fingerprint enroll || true
    fi
fi
