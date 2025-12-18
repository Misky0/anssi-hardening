<p align="center">
  <img src="https://img.shields.io/badge/Plateforme-Debian%20%7C%20Ubuntu-orange?style=for-the-badge&logo=linux" alt="Plateforme">
  <img src="https://img.shields.io/badge/Shell-Bash-green?style=for-the-badge&logo=gnu-bash" alt="Shell">
  <img src="https://img.shields.io/github/license/Misky0/anssi-hardening?style=for-the-badge" alt="Licence">
  <img src="https://img.shields.io/badge/ANSSI-PA--085-blue?style=for-the-badge" alt="ANSSI">
</p>

<h1 align="center">ANSSI Hardening Tool</h1>

<p align="center">
  <strong>Script interactif de durcissement Linux basé sur les recommandations de l'ANSSI</strong>
</p>

<p align="center">
  <a href="#fonctionnalités">Fonctionnalités</a> •
  <a href="#installation">Installation</a> •
  <a href="#utilisation">Utilisation</a> •
  <a href="#modules">Modules</a> •
  <a href="#références">Références</a>
</p>

---

## Présentation

**ANSSI Hardening Tool** est un script Bash modulaire conçu pour durcir les systèmes Linux Debian/Ubuntu en suivant les recommandations de sécurité [ANSSI PA-085](https://cyber.gouv.fr/publications/recommandations-de-securite-relatives-un-systeme-gnulinux) de l'Agence nationale de la sécurité des systèmes d'information.

L'outil propose une interface interactive par menus avec un mode dry-run, des sauvegardes automatiques avant chaque modification, et une journalisation détaillée de toutes les actions.

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

## Fonctionnalités

- **Interface interactive par menus** — Navigation simple entre les catégories de sécurité
- **Mode dry-run** — Prévisualisation des modifications avant application
- **Sauvegardes automatiques** — Tous les fichiers modifiés sont sauvegardés avec horodatage
- **Journalisation détaillée** — Trace complète dans `/var/log/anssi-hardening.log`
- **Architecture modulaire** — Séparation claire des fonctionnalités par modules
- **Références ANSSI** — Chaque option affiche son niveau de recommandation (R1-R3)

## Installation

```bash
git clone https://github.com/Misky0/anssi-hardening.git
cd anssi-hardening
chmod +x anssi-hardening.sh
```

## Utilisation

Exécuter en tant que root :

```bash
sudo ./anssi-hardening.sh
```

### Commandes disponibles

| Commande | Description |
|----------|-------------|
| `help` | Afficher l'aide |
| `back` | Retour au menu précédent |
| `menu` | Retour au menu principal |
| `quit` | Quitter avec résumé |

### Niveaux de recommandation

L'outil suit les niveaux de recommandation du guide ANSSI PA-085 :

| Niveau | Description |
|--------|-------------|
| **R1** | Minimal — Mesures de sécurité essentielles |
| **R2** | Intermédiaire — Recommandé pour la plupart des systèmes |
| **R3** | Renforcé — Pour les environnements haute sécurité |
| **R4+** | Complémentaire — Recommandations spécifiques (R15, R67, etc.) |

## Modules

### 1. Configuration système
- Désactivation des services non essentiels
- Permissions des fichiers système
- Durcissement des paramètres kernel (sysctl)
- Options de montage sécurisées
- Blacklist des modules kernel inutiles
- Sécurisation de GRUB
- Durcissement des unités systemd

### 2. Comptes & authentification
- Politique de mots de passe (login.defs)
- Complexité des mots de passe (pam_pwquality)
- Verrouillage des comptes (pam_faillock)
- Verrouillage des comptes inactifs
- Sécurisation du compte root
- Audit des comptes utilisateurs
- Configuration du umask système

### 3. Sécurité SSH
- Configuration SSH durcie
- Guide de génération de clés SSH
- Restriction d'accès par groupe SSH
- Installation et configuration de fail2ban
- Modification du port SSH

### 4. Réseau & pare-feu
- Configuration du pare-feu (UFW/nftables)
- Durcissement IPv6
- Configuration TCP Wrappers
- Audit des ports ouverts

### 5. Mises à jour & maintenance
- Mises à jour automatiques (unattended-upgrades)
- Vérification des mises à jour de sécurité
- Application des mises à jour système
- Nettoyage des paquets obsolètes

### 6. Audit & journalisation
- Auditd avec règles ANSSI
- Configuration de la rotation des logs
- Journalisation améliorée de bash
- Vérification rsyslog
- Vérification d'intégrité AIDE

## Structure des fichiers

```
anssi-hardening/
├── anssi-hardening.sh    # Point d'entrée principal
└── lib/
    ├── core.sh           # Affichage, logs, utilitaires
    ├── system.sh         # Fonctions de durcissement système
    ├── accounts.sh       # Gestion des comptes et authentification
    ├── ssh.sh            # Configuration SSH et fail2ban
    ├── network.sh        # Réseau et pare-feu
    ├── updates.sh        # Gestion des mises à jour
    ├── audit.sh          # Audit et journalisation
    └── menus.sh          # Interface des menus
```

## Sauvegardes & logs

| Chemin | Description |
|--------|-------------|
| `/var/backups/anssi-hardening/` | Sauvegardes automatiques des fichiers modifiés |
| `/var/log/anssi-hardening.log` | Journal détaillé des actions |

## Prérequis

- Debian 11+ ou Ubuntu 20.04+
- Privilèges root
- Bash 4.0+

## Références

- [ANSSI PA-085 — Recommandations de sécurité relatives à un système GNU/Linux](https://cyber.gouv.fr/publications/recommandations-de-securite-relatives-un-systeme-gnulinux)
- [ANSSI — Agence nationale de la sécurité des systèmes d'information](https://cyber.gouv.fr/)

## Licence

Ce projet est sous licence MIT — voir le fichier [LICENSE](LICENSE) pour plus de détails.

---

<p align="center">
  <sub>Conçu avec la sécurité en tête</sub>
</p>
