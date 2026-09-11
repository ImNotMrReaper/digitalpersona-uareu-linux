#!/usr/bin/env bash
#
# Digital Persona U.are.U 4500 Linux Driver & Auth Engine Uninstaller
#

set -e

RED="\033[1;31m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
RESET="\033[0m"

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ Please run this uninstaller with sudo:${RESET}"
    echo -e "   sudo ./uninstall.sh"
    exit 1
fi

echo -e "${BLUE}>>> Removing systemd service override...${RESET}"
rm -f /etc/systemd/system/fprintd.service.d/override.conf
systemctl daemon-reload
systemctl restart fprintd || true

echo -e "${BLUE}>>> Removing installed binaries and libraries...${RESET}"
rm -f /usr/local/bin/dp-auth
rm -f /usr/local/bin/dp-fingerprint
rm -f /usr/local/lib/libfprint_bz3_override.so
rm -f /lib/security/dp_fprint_pam.py

echo -e "${BLUE}>>> Restoring PAM configurations...${RESET}"
for pam_file in /etc/pam.d/sudo /etc/pam.d/polkit-1 /etc/pam.d/common-auth; do
    if [ -f "${pam_file}.bak-dp-auth" ]; then
        mv "${pam_file}.bak-dp-auth" "$pam_file"
        echo -e "    Restored ${pam_file} from backup."
    elif [ -f "$pam_file" ]; then
        sed -i '/dp_fprint_pam\.py/d' "$pam_file"
    fi
done

echo -e "${GREEN}✓ Digital Persona U.are.U 4500 Auth Engine cleanly uninstalled.${RESET}"
