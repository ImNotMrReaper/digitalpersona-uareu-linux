# Digital Persona U.are.U 4500 Linux Biometric Engine 🛡️

Universal, production-ready biometric driver and multi-device authentication engine for **Digital Persona U.are.U 4500, 4000, and 4000B** optical USB fingerprint readers on Linux.

Works seamlessly on **Ubuntu Desktop, Ubuntu Server, Debian, Linux Mint, Pop!_OS, Fedora, and Arch Linux**.

---

## ⚡ What This Fixes in Linux `libfprint`

Stock Linux `fprintd` and `libfprint` struggle with optical USB readers out-of-the-box due to three architectural bugs:

1. **The Bozorth3 40/40 Match Failure:**
   - NIST Bozorth3 defaults to a threshold of `40` (designed for full 10-print rolled ink cards).
   - Real-world flat touches on consumer optical glass prisms score between **14 and 30**. Genuine fingers get rejected as `verify-no-match`.
   - **Solution:** Our dynamic C shared library (`libfprint_bz3_override.so`) intercepts `fp_device_identify` and dynamically tunes the Bozorth3 threshold to `14` specifically on optical readers, guaranteeing instantaneous authentic matches while reliably rejecting non-matching touches (scores < 10).

2. **The "Single Touch & Blue LED Dies" Lockout:**
   - `fprintd` keeps the device state machine in `ACTION_VERIFY` after emitting `VerifyStatus(done=TRUE)`. Subsequent scan requests throw `AlreadyInUse (36)` and extinguish the blue LED prism.
   - **Solution:** An atomic 50ms `VerifyStop()` $\rightarrow$ `VerifyStart()` cycle that resets the driver state machine, keeping the optical LED continuously illuminated for infinite retry attempts until you authenticate.

3. **Single-Device Starvation:**
   - Upstream `pam_fprintd.so` only connects to a single sensor (whichever has more prints), ignoring secondary or external USB sensors.
   - **Solution:** `dp-auth` concurrently claims and listens to **all** connected sensors (laptop capacitive Match-On-Chip + external USB optical reader) with dynamic USB hotplugging.

---

## 🚀 Quick Start & Installation

### Option 1: Install via Debian Package (`.deb`)
*Ideal for Ubuntu Desktop, Ubuntu Server, Debian, Linux Mint, and Pop!_OS.*

```bash
# 1. Install the debian package
sudo dpkg -i dp4500-fingerprint-auth_1.0.0_amd64.deb

# 2. Resolve any missing package dependencies automatically
sudo apt-get install -f
```

### Option 2: Universal Source Installer (`install.sh`)
*Works on any Linux distribution (Ubuntu, Debian, Fedora, Arch, RHEL).*

```bash
git clone https://github.com/ImNotMrReaper/digitalpersona-uareu-linux.git
cd digitalpersona-uareu-linux
sudo ./install.sh
```

---

## 🎮 CLI Management (`dp-fingerprint`)

The package provides the `dp-fingerprint` command-line utility for managing and testing your sensors:

### 1. List Sensors & Fingerprint Parity
```bash
dp-fingerprint list
```
Displays all connected hardware sensors (capacitive vs. optical), stage counts, and checks if any enrolled finger is missing on other sensors.

### 2. Enroll a Fingerprint
```bash
# Enroll Right Index Finger on USB Reader (6 touches):
dp-fingerprint enroll --device usb --finger right-index-finger

# Enroll Right Thumb on USB Reader:
dp-fingerprint enroll --device usb --finger right-thumb
```
Supported finger names:
`right-index-finger`, `right-thumb`, `right-middle-finger`, `right-ring-finger`, `right-little-finger`,
`left-index-finger`, `left-thumb`, `left-middle-finger`, `left-ring-finger`, `left-little-finger`.

### 3. Live Verification Test
```bash
# Test the USB reader specifically:
dp-fingerprint verify --device usb

# Test multi-sensor concurrent authentication:
dp-fingerprint verify --device both
```

### 4. Delete Fingerprints
```bash
# Clear all prints from the USB reader:
dp-fingerprint delete --device usb
```

---

## 🔐 PAM System Authentication (`sudo`, Login, Lockscreen)

The installer automatically configures your PAM pipeline across:
- **Terminal Sudo:** `/etc/pam.d/sudo`
- **Lockscreen & Login:** `/etc/pam.d/gdm-password` (or lightdm/sddm)
- **Desktop Privilege Elevation:** `/etc/pam.d/polkit-1`
- **Central Common Auth:** `/etc/pam.d/common-auth`

**Zero-Lockout Guarantee:** The standard Unix password prompt (`pam_unix.so try_first_pass`) is always retained as a fallback. You can never be locked out of your system.

---

## 🛠️ Building the Debian Package from Source

To compile and package a fresh `.deb` binary on any machine:

```bash
./build_deb.sh
```
The output package will be generated at `./dp4500-fingerprint-auth_1.0.0_amd64.deb`.

---

## 🗑️ Uninstallation

To completely remove the package and restore stock PAM and systemd configurations:

```bash
# Via script:
sudo ./uninstall.sh

# Or via apt:
sudo apt remove dp4500-fingerprint-auth
```

---

## 📋 Distribution Compatibility Matrix

| Distribution | Status | Installation Method |
|---|:---:|---|
| **Ubuntu 24.04 LTS (Desktop & Server)** | ✅ Fully Verified | `.deb` or `install.sh` |
| **Ubuntu 22.04 LTS (Desktop & Server)** | ✅ Fully Verified | `.deb` or `install.sh` |
| **Debian 12 (Bookworm)** | ✅ Supported | `.deb` or `install.sh` |
| **Linux Mint 21 / 22** | ✅ Supported | `.deb` or `install.sh` |
| **Pop!_OS 22.04 / 24.04** | ✅ Supported | `.deb` or `install.sh` |
| **Fedora 38 / 39 / 40** | ✅ Supported | `install.sh` |
| **Arch Linux** | ✅ Supported | `install.sh` |

---

## 📄 License
MIT License. Open-source and free for personal and enterprise use.
