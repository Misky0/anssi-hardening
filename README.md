<p align="center">
  <img src="https://img.shields.io/badge/Platform-Debian%20%7C%20Ubuntu-orange?style=for-the-badge&logo=linux" alt="Platform">
  <img src="https://img.shields.io/badge/Shell-Bash-green?style=for-the-badge&logo=gnu-bash" alt="Shell">
  <img src="https://img.shields.io/github/license/Misky0/anssi-hardening?style=for-the-badge" alt="License">
  <img src="https://img.shields.io/badge/ANSSI-PA--085-blue?style=for-the-badge" alt="ANSSI">
</p>

<h1 align="center">ANSSI Hardening Tool</h1>

<p align="center">
  <strong>Interactive Linux hardening script based on French ANSSI security guidelines</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#modules">Modules</a> •
  <a href="#references">References</a>
</p>

---

## Overview

**ANSSI Hardening Tool** is a modular Bash script designed to harden Debian/Ubuntu Linux systems following the [ANSSI PA-085](https://cyber.gouv.fr/publications/recommandations-de-securite-relatives-un-systeme-gnulinux) security recommendations from the French National Cybersecurity Agency.

The tool provides an interactive menu-driven interface with dry-run capabilities, automatic backups before any modification, and detailed logging of all actions.

```
╔═══════════════════════════════════════════════════════════════════════════╗
║     █████╗ ███╗   ██╗███████╗███████╗██╗    ██╗  ██╗ █████╗ ██████╗       ║
║    ██╔══██╗████╗  ██║██╔════╝██╔════╝██║    ██║  ██║██╔══██╗██╔══██╗      ║
║    ███████║██╔██╗ ██║███████╗███████╗██║    ███████║███████║██████╔╝      ║
║    ██╔══██║██║╚██╗██║╚════██║╚════██║██║    ██╔══██║██╔══██║██╔══██╗      ║
║    ██║  ██║██║ ╚████║███████║███████║██║    ██║  ██║██║  ██║██║  ██║      ║
║    ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝╚═╝    ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝      ║
║          ╔═══════════════════════════════════════════════════╗            ║
║          ║  HARDENING TOOL - Durcissement Systeme Linux      ║            ║
║          ║  Base sur les recommandations ANSSI-PA-085        ║            ║
║          ╚═══════════════════════════════════════════════════╝            ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

## Features

- **Interactive menu interface** — Easy navigation through security categories
- **Dry-run mode** — Preview changes before applying them
- **Automatic backups** — All modified files are backed up with timestamps
- **Detailed logging** — Complete audit trail in `/var/log/anssi-hardening.log`
- **Modular architecture** — Clean separation of concerns across modules
- **ANSSI reference tags** — Each hardening option shows its ANSSI recommendation level (R1-R3)

## Installation

```bash
git clone https://github.com/Misky0/anssi-hardening.git
cd anssi-hardening
chmod +x anssi-hardening.sh
```

## Usage

Run as root:

```bash
sudo ./anssi-hardening.sh
```

### Available Commands

| Command | Description |
|---------|-------------|
| `help` | Display available commands |
| `back` | Return to previous menu |
| `menu` | Return to main menu |
| `quit` | Exit with summary |

### Recommendation Levels

The tool follows ANSSI recommendation levels:

| Level | Description |
|-------|-------------|
| **R1** | Minimal — Essential security measures |
| **R2** | Intermediate — Recommended for most systems |
| **R3** | Enhanced — For high-security environments |

## Modules

### 1. System Configuration
- Disable non-essential services
- Set secure file permissions
- Harden kernel parameters (sysctl)
- Configure secure mount options
- Blacklist unnecessary kernel modules
- Secure GRUB bootloader
- Harden systemd units

### 2. Accounts & Authentication
- Password policy (login.defs)
- Password complexity (pam_pwquality)
- Account lockout (pam_faillock)
- Inactive account locking
- Root account security
- User accounts audit
- System umask configuration

### 3. SSH Security
- Hardened SSH configuration
- SSH key generation guide
- SSH access group restriction
- Fail2ban installation & setup
- SSH port modification

### 4. Network & Firewall
- Firewall configuration (UFW/nftables)
- IPv6 hardening
- TCP Wrappers setup
- Open ports audit

### 5. Updates & Maintenance
- Automatic updates (unattended-upgrades)
- Security updates check
- System updates
- Package cleanup

### 6. Audit & Logging
- Auditd with ANSSI rules
- Log rotation configuration
- Enhanced bash logging
- Rsyslog verification
- AIDE integrity checker

## File Structure

```
anssi-hardening/
├── anssi-hardening.sh    # Main entry point
└── lib/
    ├── core.sh           # Display, logging, utilities
    ├── system.sh         # System hardening functions
    ├── accounts.sh       # User & authentication management
    ├── ssh.sh            # SSH & fail2ban configuration
    ├── network.sh        # Network & firewall setup
    ├── updates.sh        # Updates management
    ├── audit.sh          # Auditing & logging setup
    └── menus.sh          # Menu interface
```

## Backups & Logs

| Path | Description |
|------|-------------|
| `/var/backups/anssi-hardening/` | Automatic backups of modified files |
| `/var/log/anssi-hardening.log` | Detailed action log |

## Requirements

- Debian 11+ or Ubuntu 20.04+
- Root privileges
- Bash 4.0+

## References

- [ANSSI PA-085 — Recommandations de sécurité relatives à un système GNU/Linux](https://cyber.gouv.fr/publications/recommandations-de-securite-relatives-un-systeme-gnulinux)
- [ANSSI — Agence nationale de la sécurité des systèmes d'information](https://cyber.gouv.fr/)

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  <sub>Made with security in mind</sub>
</p>
