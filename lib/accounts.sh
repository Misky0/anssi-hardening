#!/bin/bash
#===============================================================================
# ANSSI Hardening Tool - Module Accounts
# @file     accounts.sh
# @brief    Comptes et authentification: PAM, mots de passe, umask
# @version  1.1
#===============================================================================



#-------------------------------------------------------------------------------
# @brief    Configure la politique de mots de passe dans login.defs
# @details  Applique: PASS_MAX_DAYS=90, PASS_MIN_LEN=12, SHA512 65536 rounds
# @return   void
#-------------------------------------------------------------------------------

configure_password_policy() {
    print_section "Politique de mots de passe complete" "R14"
    
    local login_defs="/etc/login.defs"
    
    echo -e "${WHITE}Configuration recommandee:${NC}"
    echo "  - PASS_MAX_DAYS: 90 (expiration apres 90 jours)"
    echo "  - PASS_MIN_DAYS: 1 (changement min 1 jour)"
    echo "  - PASS_MIN_LEN: 12 (longueur minimale)"
    echo "  - PASS_WARN_AGE: 14 (avertissement 14 jours avant)"
    echo "  - SHA512 avec 65536 rounds (hashage renforce)"
    echo ""
    
    if ! ask_yes_no "Appliquer cette politique ?"; then
        log_action "PASSWORD_POLICY" "Ignore" "IGNORE"
        wait_continue
        return
    fi
    
    backup_file "$login_defs"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Modification de $login_defs"
        log_action "PASSWORD_POLICY" "Configuration" "DRY-RUN"
        wait_continue
        return
    fi
    
    # Password aging
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' "$login_defs"
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' "$login_defs"
    sed -i 's/^PASS_MIN_LEN.*/PASS_MIN_LEN    12/' "$login_defs"
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/' "$login_defs"
    
    # SHA512 rounds
    if grep -q "^SHA_CRYPT_MIN_ROUNDS" "$login_defs"; then
        sed -i 's/^SHA_CRYPT_MIN_ROUNDS.*/SHA_CRYPT_MIN_ROUNDS 65536/' "$login_defs"
    else
        echo "SHA_CRYPT_MIN_ROUNDS 65536" >> "$login_defs"
    fi
    
    if grep -q "^SHA_CRYPT_MAX_ROUNDS" "$login_defs"; then
        sed -i 's/^SHA_CRYPT_MAX_ROUNDS.*/SHA_CRYPT_MAX_ROUNDS 65536/' "$login_defs"
    else
        echo "SHA_CRYPT_MAX_ROUNDS 65536" >> "$login_defs"
    fi
    
    # Methode de chiffrement
    if grep -q "^ENCRYPT_METHOD" "$login_defs"; then
        sed -i 's/^ENCRYPT_METHOD.*/ENCRYPT_METHOD SHA512/' "$login_defs"
    else
        echo "ENCRYPT_METHOD SHA512" >> "$login_defs"
    fi
    
    print_result ok "Politique de mots de passe configuree"
    print_result ok "Hashing SHA512 avec 65536 rounds active"
    log_action "PASSWORD_POLICY" "Politique complete appliquee" "APPLIQUE"
    
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Configure pam_pwquality pour la complexite des mots de passe
# @details  Applique: minlen=12, credits, maxrepeat=3, dictcheck
# @return   void
#-------------------------------------------------------------------------------
configure_pam_pwquality() {
    print_section "Configuration PAM pam_pwquality" "R14"
    
    echo -e "${WHITE}pam_pwquality impose la complexite des mots de passe:${NC}"
    echo "  - Longueur minimale: 12 caracteres"
    echo "  - Au moins 1 majuscule (ucredit)"
    echo "  - Au moins 1 minuscule (lcredit)"
    echo "  - Au moins 1 chiffre (dcredit)"
    echo "  - Au moins 1 caractere special (ocredit)"
    echo "  - Maximum 3 caracteres consecutifs identiques"
    echo "  - Verification contre dictionnaire"
    echo ""
    
    # Verification installation
    if ! dpkg -l 2>/dev/null | grep -q "libpam-pwquality"; then
        print_result warn "libpam-pwquality n'est pas installe"
        if ask_yes_no "Installer libpam-pwquality ?"; then
            execute_cmd "Installation de libpam-pwquality" "apt-get update && apt-get install -y libpam-pwquality"
        else
            log_action "PAM_PWQUALITY" "Installation refusee" "IGNORE"
            wait_continue
            return
        fi
    fi
    
    local pwquality_conf="/etc/security/pwquality.conf"
    
    if ! ask_yes_no "Configurer pam_pwquality ?"; then
        log_action "PAM_PWQUALITY" "Ignore" "IGNORE"
        wait_continue
        return
    fi
    
    [[ -f "$pwquality_conf" ]] && backup_file "$pwquality_conf"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Configuration de $pwquality_conf"
        log_action "PAM_PWQUALITY" "Configuration" "DRY-RUN"
        wait_continue
        return
    fi
    
    cat > "$pwquality_conf" << 'PWQUALITY_CONF'
# ANSSI Hardening - Configuration pam_pwquality
# Reference: ANSSI-PA-085 R14

# Longueur minimale du mot de passe
minlen = 12

# Credits (nombre minimum de chaque type de caractere)
# Valeur negative = nombre minimum requis
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1

# Maximum de caracteres consecutifs identiques
maxrepeat = 3

# Maximum de caracteres consecutifs de la meme classe
maxclassrepeat = 4

# Verification contre le nom d'utilisateur
usercheck = 1

# Verification contre dictionnaire
dictcheck = 1

# Nombre de caracteres differents du precedent mot de passe
difok = 5

# Appliquer les regles meme pour root
enforce_for_root

# Rejeter les mots de passe trop simples
gecoscheck = 1
PWQUALITY_CONF

    chmod 644 "$pwquality_conf"
    print_result ok "Configuration pam_pwquality appliquee"
    log_action "PAM_PWQUALITY" "Configure" "APPLIQUE"
    
    # Verification PAM
    local common_password="/etc/pam.d/common-password"
    if [[ -f "$common_password" ]]; then
        if ! grep -q "pam_pwquality.so" "$common_password"; then
            print_result warn "pam_pwquality n'est pas active dans PAM"
            print_result info "Ajoutez: password requisite pam_pwquality.so retry=3"
        else
            print_result ok "pam_pwquality est active dans PAM"
        fi
    fi
    
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Configure pam_faillock pour le verrouillage apres echecs
# @details  Applique: deny=5, unlock_time=900, fail_interval=900
# @return   void
#-------------------------------------------------------------------------------
configure_pam_faillock() {
    print_section "Configuration PAM faillock (anti-bruteforce)" "R14"
    
    echo -e "${WHITE}pam_faillock verrouille les comptes apres echecs:${NC}"
    echo "  - 5 tentatives maximum"
    echo "  - Verrouillage de 900 secondes (15 min)"
    echo "  - Applicable a tous les comptes (sauf root optionnel)"
    echo ""
    
    print_result warn "ATTENTION: Une mauvaise configuration peut bloquer l'acces!"
    echo ""
    
    if ! ask_yes_no "Configurer pam_faillock ?"; then
        log_action "PAM_FAILLOCK" "Ignore" "IGNORE"
        wait_continue
        return
    fi
    
    local faillock_conf="/etc/security/faillock.conf"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Configuration faillock"
        wait_continue
        return
    fi
    
    [[ -f "$faillock_conf" ]] && backup_file "$faillock_conf"
    
    cat > "$faillock_conf" << 'FAILLOCK_CONF'
# ANSSI Hardening - Configuration faillock
# Reference: ANSSI-PA-085 R14

# Repertoire des compteurs d'echecs
dir = /var/run/faillock

# Nombre d'echecs avant verrouillage
deny = 5

# Duree du verrouillage en secondes (900 = 15 minutes)
unlock_time = 900

# Fenetre de temps pour compter les echecs (900 secondes)
fail_interval = 900

# Ne pas verrouiller root (a ajuster selon votre politique)
# even_deny_root
# root_unlock_time = 900

# Journalisation
audit
silent
FAILLOCK_CONF

    chmod 644 "$faillock_conf"
    print_result ok "Configuration faillock creee"
    
    echo ""
    echo -e "${WHITE}Pour activer faillock, ajoutez dans /etc/pam.d/common-auth:${NC}"
    echo "  auth required pam_faillock.so preauth"
    echo "  auth [default=die] pam_faillock.so authfail"
    echo ""
    echo -e "${WHITE}Et dans /etc/pam.d/common-account:${NC}"
    echo "  account required pam_faillock.so"
    
    log_action "PAM_FAILLOCK" "Configure" "APPLIQUE"
    
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Configure le verrouillage automatique des comptes inactifs
# @details  Applique: INACTIVE=30 jours, detection comptes sans mot de passe
# @return   void
#-------------------------------------------------------------------------------
lock_inactive_accounts() {
    print_section "Verrouillage des comptes inactifs" "R13"
    
    echo -e "${WHITE}Configuration INACTIVE:${NC}"
    echo "  Les comptes seront verrouilles apres 30 jours d'inactivite"
    echo "  apres expiration du mot de passe."
    echo ""
    
    if ask_yes_no "Configurer INACTIVE a 30 jours ?"; then
        execute_cmd "Configuration INACTIVE=30" "useradd -D -f 30"
        log_action "INACTIVE" "30 jours" "APPLIQUE"
    fi
    
    echo ""
    echo -e "${WHITE}Comptes sans mot de passe:${NC}"
    local found=0
    while IFS=: read -r user pass rest; do
        if [[ -z "$pass" ]] || [[ "$pass" == "!" ]] || [[ "$pass" == "*" ]]; then
            if [[ "$user" != "root" ]]; then
                echo "  - $user"
                ((found++))
            fi
        fi
    done < /etc/shadow
    
    if [[ $found -eq 0 ]]; then
        print_result ok "Aucun compte sans mot de passe"
    else
        print_result warn "$found compte(s) sans mot de passe detecte(s)"
    fi
    
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Securise le compte root (timeout, TTY)
# @details  Applique: TMOUT=300, restriction securetty
# @return   void
#-------------------------------------------------------------------------------
secure_root_account() {
    print_section "Securisation du compte root" "R11"
    
    # Timeout de session
    echo -e "${WHITE}1. Timeout de session (TMOUT)${NC}"
    if ask_yes_no "Configurer un timeout de 300 secondes ?"; then
        local timeout_file="/etc/profile.d/timeout.sh"
        if [[ $DRY_RUN -eq 0 ]]; then
            cat > "$timeout_file" << 'TIMEOUT_CONF'
# ANSSI Hardening - Timeout de session
TMOUT=300
readonly TMOUT
export TMOUT
TIMEOUT_CONF
            chmod 644 "$timeout_file"
            print_result ok "Timeout de 300s configure"
            log_action "TIMEOUT" "300 secondes" "APPLIQUE"
        else
            print_result dryrun "Configuration du timeout"
        fi
    fi
    
    echo ""
    
    # Restriction TTY
    echo -e "${WHITE}2. Restriction des TTY pour root${NC}"
    if ask_yes_no "Restreindre root aux TTY locaux uniquement ?"; then
        local securetty="/etc/securetty"
        if [[ $DRY_RUN -eq 0 ]]; then
            backup_file "$securetty" 2>/dev/null
            cat > "$securetty" << 'SECURETTY_CONF'
# ANSSI Hardening - TTY autorises pour root
tty1
tty2
tty3
tty4
tty5
tty6
console
SECURETTY_CONF
            chmod 600 "$securetty"
            print_result ok "Restriction TTY configuree"
            log_action "SECURETTY" "Configure" "APPLIQUE"
        else
            print_result dryrun "Configuration securetty"
        fi
    fi
    
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Effectue un audit des comptes utilisateurs
# @details  Affiche: utilisateurs UID>=1000, comptes UID=0, groupe sudo, connexions
# @return   void
#-------------------------------------------------------------------------------
audit_users() {
    print_section "Audit des comptes utilisateurs" "R13"
    
    echo -e "${WHITE}Utilisateurs systeme (UID >= 1000):${NC}"
    while IFS=: read -r user x uid gid gecos home shell; do
        if [[ $uid -ge 1000 ]] && [[ $uid -ne 65534 ]]; then
            echo "  - $user (UID:$uid) - Shell: $shell"
        fi
    done < /etc/passwd
    
    echo ""
    echo -e "${WHITE}Comptes avec UID 0 (root):${NC}"
    while IFS=: read -r user x uid rest; do
        if [[ $uid -eq 0 ]]; then
            echo "  - $user"
        fi
    done < /etc/passwd
    
    echo ""
    echo -e "${WHITE}Membres du groupe sudo:${NC}"
    getent group sudo 2>/dev/null | cut -d: -f4 | tr ',' '\n' | while read -r u; do
        [[ -n "$u" ]] && echo "  - $u"
    done
    
    echo ""
    echo -e "${WHITE}Dernieres connexions:${NC}"
    last -n 5 2>/dev/null | head -5
    
    log_action "AUDIT_USERS" "Audit effectue" "INFO"
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Configure le umask systeme a 027
# @details  Modifie: login.defs, /etc/profile, /etc/profile.d/umask.sh
# @return   void
#-------------------------------------------------------------------------------
configure_umask() {
    print_section "Configuration umask" "R15"
    
    echo -e "${WHITE}Valeurs umask:${NC}"
    echo "  022 = fichiers 644, dossiers 755 (standard)"
    echo "  027 = fichiers 640, dossiers 750 (recommande)"
    echo "  077 = fichiers 600, dossiers 700 (restrictif)"
    echo ""
    
    if ! ask_yes_no "Configurer umask a 027 (recommande ANSSI) ?"; then
        log_action "UMASK" "Ignore" "IGNORE"
        wait_continue
        return
    fi
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Configuration umask"
        wait_continue
        return
    fi
    
    # login.defs
    sed -i 's/^UMASK.*/UMASK 027/' /etc/login.defs 2>/dev/null
    
    # /etc/profile
    if grep -q "^umask" /etc/profile; then
        sed -i 's/^umask.*/umask 027/' /etc/profile
    else
        echo "umask 027" >> /etc/profile
    fi
    
    # Fichier profile.d
    echo "umask 027" > /etc/profile.d/umask.sh
    chmod 644 /etc/profile.d/umask.sh
    
    print_result ok "Umask 027 configure"
    log_action "UMASK" "027" "APPLIQUE"
    
    wait_continue
}
