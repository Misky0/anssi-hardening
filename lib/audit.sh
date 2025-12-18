#!/bin/bash
#===============================================================================
# ANSSI Hardening Tool - Module Audit
# @file     audit.sh
# @brief    Audit et journalisation: auditd, logrotate, rsyslog, AIDE
# @version  1.1
#===============================================================================


#-------------------------------------------------------------------------------
# @brief    Installe et configure auditd avec regles ANSSI
# @details  Surveille: fichiers sensibles, actions admin, modules kernel, montages
# @return   void
#-------------------------------------------------------------------------------
configure_auditd() {
    print_section "Installation et configuration d'auditd" "R19"
    
    # Verification installation
    if ! command -v auditd &>/dev/null; then
        print_result warn "auditd n'est pas installe"
        if ask_yes_no "Installer auditd ?"; then
            execute_cmd "Installation auditd" "apt-get update && apt-get install -y auditd audispd-plugins"
        else
            log_action "AUDITD" "Installation refusee" "IGNORE"
            wait_continue
            return
        fi
    fi
    
    echo -e "${WHITE}Regles d'audit qui seront configurees:${NC}"
    echo "  - Surveillance des fichiers sensibles (passwd, shadow, sudoers)"
    echo "  - Surveillance des modifications systeme"
    echo "  - Surveillance des actions administratives (sudo, su)"
    echo "  - Surveillance des modules kernel"
    echo ""
    
    if ! ask_yes_no "Appliquer ces regles ?"; then
        wait_continue
        return
    fi
    
    local audit_rules="/etc/audit/rules.d/anssi-hardening.rules"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Configuration auditd"
        wait_continue
        return
    fi
    
    [[ -f "$audit_rules" ]] && backup_file "$audit_rules"
    
    cat > "$audit_rules" << 'AUDIT_RULES'
# ANSSI Hardening - Regles d'audit
# Reference: ANSSI-PA-085 R19

# Supprimer les regles existantes
-D

# Buffer
-b 8192

# === FICHIERS SENSIBLES ===

# Fichiers d'identite
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# Sudoers
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers

# SSH
-w /etc/ssh/sshd_config -p wa -k sshd
-w /etc/ssh/sshd_config.d/ -p wa -k sshd

# PAM
-w /etc/pam.d/ -p wa -k pam

# Cron
-w /etc/crontab -p wa -k cron
-w /etc/cron.d/ -p wa -k cron
-w /var/spool/cron/crontabs/ -p wa -k cron

# === ACTIONS ADMINISTRATIVES ===

# Sudo et su
-w /usr/bin/sudo -p x -k privileged
-w /usr/bin/su -p x -k privileged

# Gestion des utilisateurs
-w /usr/sbin/useradd -p x -k user_modification
-w /usr/sbin/userdel -p x -k user_modification
-w /usr/sbin/usermod -p x -k user_modification
-w /usr/sbin/groupadd -p x -k group_modification
-w /usr/sbin/groupdel -p x -k group_modification
-w /usr/sbin/groupmod -p x -k group_modification

# Reseau
-w /etc/hosts -p wa -k network
-w /etc/network/ -p wa -k network

# === APPELS SYSTEME ===

# Changements de date/heure
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time_change
-w /etc/localtime -p wa -k time_change

# Modules kernel
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules
-a always,exit -F arch=b32 -S init_module -S delete_module -k modules

# Montages
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts

# Suppressions de fichiers par les utilisateurs
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
AUDIT_RULES

    chmod 640 "$audit_rules"
    
    # Chargement des regles
    if augenrules --load 2>/dev/null || auditctl -R "$audit_rules" 2>/dev/null; then
        print_result ok "Regles d'audit chargees"
    else
        print_result warn "Certaines regles peuvent ne pas etre supportees"
    fi
    
    systemctl enable auditd
    systemctl restart auditd
    
    print_result ok "auditd configure et actif"
    log_action "AUDITD" "Configure" "APPLIQUE"
    
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Configure la rotation des logs de securite
# @details  Conservation 13 semaines (~90 jours), compression, rotation hebdo
# @return   void
#-------------------------------------------------------------------------------
configure_logrotate() {
    print_section "Configuration de la rotation des logs" "R19"
    
    echo -e "${WHITE}Configuration recommandee:${NC}"
    echo "  - Conservation: 90 jours minimum (13 semaines)"
    echo "  - Compression des anciens logs"
    echo "  - Rotation hebdomadaire"
    echo ""
    
    if ! ask_yes_no "Creer une configuration de rotation renforcee ?"; then
        wait_continue
        return
    fi
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Configuration logrotate"
        wait_continue
        return
    fi
    
    cat > /etc/logrotate.d/anssi-hardening << 'LOGROTATE_CONF'
# ANSSI Hardening - Rotation des logs de securite
# Conservation: 13 semaines (environ 90 jours)

/var/log/auth.log
/var/log/syslog
{
    weekly
    rotate 13
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
    sharedscripts
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate 2>/dev/null || true
    endscript
}

/var/log/sudo.log
{
    weekly
    rotate 52
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
}

/var/log/faillog
/var/log/lastlog
{
    monthly
    rotate 12
    missingok
    notifempty
}
LOGROTATE_CONF

    chmod 644 /etc/logrotate.d/anssi-hardening
    
    print_result ok "Configuration logrotate creee"
    log_action "LOGROTATE" "Configure" "APPLIQUE"
    
    wait_continue
}

#-------------------------------------------------------------------------------
# @brief    Active la journalisation amelioree des commandes bash
# @details  Configure: HISTTIMEFORMAT, HISTSIZE=10000, histappend
# @return   void
#-------------------------------------------------------------------------------
enable_command_logging() {
    print_section "Journalisation des commandes" "R19"
    
    echo -e "${WHITE}Cette configuration active:${NC}"
    echo "  - Historique bash avec horodatage"
    echo "  - Taille d'historique augmentee (10000 lignes)"
    echo "  - Sauvegarde immediate des commandes"
    echo ""
    
    if ! ask_yes_no "Activer la journalisation amelioree des commandes ?"; then
        wait_continue
        return
    fi
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Journalisation commandes"
        wait_continue
        return
    fi
    
    cat > /etc/profile.d/bash-history.sh << 'BASH_HISTORY'
# ANSSI Hardening - Historique bash ameliore

# Format avec date et heure
export HISTTIMEFORMAT="%F %T "

# Taille de l'historique
export HISTSIZE=10000
export HISTFILESIZE=10000

# Eviter les doublons
export HISTCONTROL=ignoredups:erasedups

# Ajouter au lieu d'ecraser
shopt -s histappend

# Sauvegarder apres chaque commande
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a"
BASH_HISTORY

    chmod 644 /etc/profile.d/bash-history.sh
    
    print_result ok "Journalisation des commandes activee"
    print_result info "Effectif pour les nouvelles sessions"
    log_action "CMD_LOGGING" "Active" "APPLIQUE"
    
    wait_continue
}

#-------------------------------------------------------------------------------
# @brief    Verifie et active rsyslog
# @details  Affiche les instructions pour centralisation des logs
# @return   void
#-------------------------------------------------------------------------------
configure_rsyslog() {
    print_section "Verification rsyslog" "R19"
    
    if systemctl is-active rsyslog &>/dev/null; then
        print_result ok "rsyslog est actif"
    else
        print_result warn "rsyslog n'est pas actif"
        if ask_yes_no "Activer rsyslog ?"; then
            execute_cmd "Activation rsyslog" "systemctl enable --now rsyslog"
        fi
    fi
    
    echo ""
    echo -e "${WHITE}Pour centraliser les logs vers un serveur distant:${NC}"
    echo "  Ajoutez dans /etc/rsyslog.conf:"
    echo ""
    echo "  # Envoi TCP (recommande)"
    echo "  *.* @@logserver.example.com:514"
    echo ""
    echo "  # Ou envoi UDP"
    echo "  *.* @logserver.example.com:514"
    echo ""
    
    log_action "RSYSLOG" "Verification effectuee" "INFO"
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Installe et initialise AIDE pour la verification d'integrite
# @details  Cree la base de donnees initiale et configure la verification quotidienne
# @return   void
#-------------------------------------------------------------------------------
configure_aide() {
    print_section "AIDE - Verification d'integrite" "R19"
    
    # Verification installation
    if ! command -v aide &>/dev/null; then
        print_result warn "AIDE n'est pas installe"
        if ask_yes_no "Installer AIDE ?"; then
            execute_cmd "Installation AIDE" "apt-get update && apt-get install -y aide aide-common"
        else
            log_action "AIDE" "Installation refusee" "IGNORE"
            wait_continue
            return
        fi
    fi
    
    echo -e "${WHITE}AIDE detecte les modifications non autorisees des fichiers.${NC}"
    echo ""
    print_result warn "L'initialisation peut prendre plusieurs minutes"
    echo ""
    
    if ! ask_yes_no "Initialiser la base de donnees AIDE ?"; then
        wait_continue
        return
    fi
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Initialisation AIDE"
        wait_continue
        return
    fi
    
    print_result info "Initialisation en cours..."
    
    if aideinit 2>/dev/null || aide --init 2>/dev/null; then
        if [[ -f /var/lib/aide/aide.db.new ]]; then
            cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
        fi
        
        print_result ok "Base de donnees AIDE initialisee"
        echo ""
        echo -e "${WHITE}Commandes utiles:${NC}"
        echo "  Verifier l'integrite: aide --check"
        echo "  Mettre a jour la base: aide --update"
        
        # Tache cron quotidienne
        if ask_yes_no "Creer une verification quotidienne automatique ?"; then
            cat > /etc/cron.daily/aide-check << 'AIDE_CRON'
#!/bin/bash
/usr/bin/aide --check > /var/log/aide/aide-check-$(date +%Y%m%d).log 2>&1
AIDE_CRON
            chmod 755 /etc/cron.daily/aide-check
            mkdir -p /var/log/aide
            print_result ok "Verification quotidienne configuree"
        fi
        
        log_action "AIDE" "Initialise" "APPLIQUE"
    else
        print_result fail "Echec de l'initialisation AIDE"
    fi
    
    wait_continue
}
