#!/bin/bash
#===============================================================================
# ANSSI Hardening Tool - Module SSH
# @file     ssh.sh
# @brief    Securite SSH: configuration, cles, fail2ban
# @version  1.1
#===============================================================================


#-------------------------------------------------------------------------------
# @brief    Applique une configuration SSH durcie
# @details  Applique: Protocol 2, PermitRootLogin no, chiffrement fort, banniere
# @return   void
#-------------------------------------------------------------------------------
harden_ssh() {
    print_section "Durcissement SSH" "R9, R12"
    
    local sshd_config="/etc/ssh/sshd_config"
    
    if [[ ! -f "$sshd_config" ]]; then
        print_result fail "SSH n'est pas installe"
        wait_continue
        return
    fi
    
    print_result warn "IMPORTANT: Gardez une session SSH ouverte pendant les modifications!"
    echo ""
    
    echo -e "${WHITE}Configuration qui sera appliquee:${NC}"
    echo "  - Protocol 2 uniquement"
    echo "  - PermitRootLogin: no"
    echo "  - Authentification par mot de passe: oui (desactivable)"
    echo "  - Authentification par cle: oui"
    echo "  - MaxAuthTries: 3"
    echo "  - X11/TCP/Agent Forwarding: desactive"
    echo "  - Chiffrement fort (ChaCha20, AES-GCM)"
    echo ""
    
    if ! ask_yes_no "Appliquer cette configuration ?"; then
        log_action "SSH" "Ignore" "IGNORE"
        wait_continue
        return
    fi
    
    backup_file "$sshd_config"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Configuration SSH durcie"
        wait_continue
        return
    fi
    
    cat > "$sshd_config" << 'SSHD_CONF'
# ANSSI Hardening - Configuration SSH
# Reference: ANSSI-PA-085 R9, R12

# Protocole
Protocol 2
Port 22

# Authentification
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Restrictions
MaxAuthTries 3
MaxSessions 2
MaxStartups 10:30:60
LoginGraceTime 60
StrictModes yes

# Securite
IgnoreRhosts yes
HostbasedAuthentication no
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitTunnel no
GatewayPorts no

# Timeouts
ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive no

# Journalisation
LogLevel VERBOSE
SyslogFacility AUTH

# Chiffrement fort
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256

# Banniere
Banner /etc/ssh/banner
SSHD_CONF

    chmod 600 "$sshd_config"
    
    # Creation banniere
    cat > /etc/ssh/banner << 'SSH_BANNER'
***************************************************************************
*                           AVERTISSEMENT                                 *
*                                                                         *
*  Ce systeme est reserve aux utilisateurs autorises.                     *
*  Toute activite est surveillee et enregistree.                         *
*  L'acces non autorise est interdit et sera poursuivi.                  *
*                                                                         *
***************************************************************************
SSH_BANNER
    
    # Validation configuration
    if sshd -t 2>/dev/null; then
        print_result ok "Configuration SSH valide"
        
        if ask_yes_no "Redemarrer le service SSH maintenant ?"; then
            systemctl restart sshd
            print_result ok "Service SSH redemarre"
        fi
        
        log_action "SSH" "Configuration durcie appliquee" "APPLIQUE"
    else
        print_result fail "Erreur dans la configuration SSH!"
        print_result info "Restauration de la sauvegarde..."
        local backup=$(ls -t "$BACKUP_DIR"/sshd_config* 2>/dev/null | head -1)
        if [[ -n "$backup" ]]; then
            cp "$backup" "$sshd_config"
            print_result ok "Sauvegarde restauree"
        fi
    fi
    
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Affiche les instructions pour generer des cles SSH securisees
# @details  Recommandations: Ed25519, RSA 4096 bits
# @return   void
#-------------------------------------------------------------------------------
configure_ssh_keys() {
    print_section "Authentification par cle SSH" "R14"
    
    echo -e "${WHITE}Generation de cles SSH securisees:${NC}"
    echo ""
    echo "  Cle Ed25519 (recommandee):"
    echo -e "    ${CYAN}ssh-keygen -t ed25519 -a 100 -C 'user@host'${NC}"
    echo ""
    echo "  Cle RSA 4096 bits (compatibilite):"
    echo -e "    ${CYAN}ssh-keygen -t rsa -b 4096 -C 'user@host'${NC}"
    echo ""
    echo -e "${WHITE}Desactivation de l'authentification par mot de passe:${NC}"
    echo "  Dans /etc/ssh/sshd_config:"
    echo "    PasswordAuthentication no"
    echo ""
    
    log_action "SSH_KEYS" "Instructions affichees" "INFO"
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Cree un groupe pour restreindre l'acces SSH
# @details  Cree le groupe 'sshusers' pour AllowGroups
# @return   void
#-------------------------------------------------------------------------------
restrict_ssh_users() {
    print_section "Restriction des utilisateurs SSH" "R15"
    
    echo -e "${WHITE}Methodes de restriction:${NC}"
    echo "  1. AllowUsers: liste blanche d'utilisateurs"
    echo "  2. AllowGroups: liste blanche de groupes"
    echo ""
    
    if ! ask_yes_no "Creer un groupe 'sshusers' pour limiter l'acces SSH ?"; then
        wait_continue
        return
    fi
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Creation du groupe sshusers"
        wait_continue
        return
    fi
    
    if ! getent group sshusers >/dev/null; then
        groupadd sshusers
        print_result ok "Groupe 'sshusers' cree"
    else
        print_result info "Groupe 'sshusers' existe deja"
    fi
    
    echo ""
    echo -e "${WHITE}Pour activer la restriction:${NC}"
    echo "  1. Ajoutez les utilisateurs au groupe:"
    echo -e "     ${CYAN}usermod -aG sshusers <utilisateur>${NC}"
    echo ""
    echo "  2. Ajoutez dans /etc/ssh/sshd_config:"
    echo "     AllowGroups sshusers"
    echo ""
    echo "  3. Redemarrez SSH:"
    echo -e "     ${CYAN}systemctl restart sshd${NC}"
    
    log_action "SSH_USERS" "Groupe sshusers cree" "APPLIQUE"
    
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Installe et configure fail2ban pour SSH
# @details  Applique: maxretry=5, bantime=3600, findtime=600
# @return   void
#-------------------------------------------------------------------------------
configure_fail2ban() {
    print_section "Configuration fail2ban" "R9"
    
    # Verification installation
    if ! command -v fail2ban-client &>/dev/null; then
        print_result warn "fail2ban n'est pas installe"
        if ask_yes_no "Installer fail2ban ?"; then
            execute_cmd "Installation de fail2ban" "apt-get update && apt-get install -y fail2ban"
        else
            log_action "FAIL2BAN" "Installation refusee" "IGNORE"
            wait_continue
            return
        fi
    fi
    
    echo -e "${WHITE}Configuration fail2ban pour SSH:${NC}"
    echo "  - Ban apres 5 tentatives"
    echo "  - Duree du ban: 1 heure"
    echo "  - Fenetre de detection: 10 minutes"
    echo ""
    
    if ! ask_yes_no "Appliquer cette configuration ?"; then
        log_action "FAIL2BAN" "Ignore" "IGNORE"
        wait_continue
        return
    fi
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Configuration fail2ban"
        wait_continue
        return
    fi
    
    cat > /etc/fail2ban/jail.local << 'FAIL2BAN_CONF'
# ANSSI Hardening - Configuration fail2ban

[DEFAULT]
# Ban pour 1 heure
bantime = 3600
# Fenetre de detection de 10 minutes
findtime = 600
# 5 tentatives avant ban
maxretry = 5
# Ignorer localhost
ignoreip = 127.0.0.1/8 ::1
# Action par defaut
banaction = iptables-multiport

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
FAIL2BAN_CONF

    chmod 644 /etc/fail2ban/jail.local
    
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    print_result ok "fail2ban configure et active"
    
    # Affichage status
    echo ""
    fail2ban-client status sshd 2>/dev/null || true
    
    log_action "FAIL2BAN" "Configure" "APPLIQUE"
    
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Change le port SSH (securite par obscurite)
# @details  Permet de choisir un port entre 1024-65535
# @return   void
#-------------------------------------------------------------------------------
change_ssh_port() {
    print_section "Changement du port SSH" "R9"
    
    print_result warn "Note: Changer le port n'est pas une mesure de securite forte"
    print_result info "mais peut reduire les attaques automatisees."
    echo ""
    
    local current_port=$(grep "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    echo -e "${WHITE}Port SSH actuel: ${CYAN}${current_port:-22}${NC}"
    echo ""
    
    if ! ask_yes_no "Voulez-vous changer le port SSH ?"; then
        wait_continue
        return
    fi
    
    # Saisie nouveau port
    local new_port
    while true; do
        echo -n -e "${WHITE}Nouveau port (1024-65535): ${NC}"
        read -r new_port
        
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [[ "$new_port" -ge 1024 ]] && [[ "$new_port" -le 65535 ]]; then
            break
        fi
        echo -e "${RED}  Port invalide. Choisissez entre 1024 et 65535.${NC}"
    done
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Changement de port vers $new_port"
        wait_continue
        return
    fi
    
    backup_file "/etc/ssh/sshd_config"
    sed -i "s/^#*Port.*/Port $new_port/" /etc/ssh/sshd_config
    
    if sshd -t 2>/dev/null; then
        print_result ok "Port SSH change vers $new_port"
        print_result warn "N'oubliez pas de mettre a jour votre pare-feu!"
        
        if ask_yes_no "Redemarrer SSH maintenant ?"; then
            systemctl restart sshd
            print_result ok "SSH redemarre sur le port $new_port"
        fi
        
        log_action "SSH_PORT" "Port $new_port" "APPLIQUE"
    else
        print_result fail "Erreur de configuration"
    fi
    
    wait_continue
}
