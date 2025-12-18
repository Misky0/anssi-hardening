#!/bin/bash
#===============================================================================
# ANSSI Hardening Tool - Module Updates
# @file     updates.sh
# @brief    Mises a jour: automatiques, securite, nettoyage
# @version  1.1
#===============================================================================


#-------------------------------------------------------------------------------
# @brief    Configure les mises a jour automatiques via unattended-upgrades
# @details  Installe et configure unattended-upgrades pour les MAJ de securite
# @return   void
#-------------------------------------------------------------------------------
configure_auto_updates() {
    print_section "Configuration des mises a jour automatiques" "R16"
    
    # Verification installation
    if ! dpkg -l 2>/dev/null | grep -q "unattended-upgrades"; then
        print_result warn "unattended-upgrades n'est pas installe"
        if ask_yes_no "Installer unattended-upgrades ?"; then
            execute_cmd "Installation" "apt-get update && apt-get install -y unattended-upgrades apt-listchanges"
        else
            log_action "AUTO_UPDATES" "Installation refusee" "IGNORE"
            wait_continue
            return
        fi
    fi
    
    echo -e "${WHITE}Configuration des mises a jour automatiques:${NC}"
    echo "  - Mises a jour de securite uniquement"
    echo "  - Nettoyage automatique des anciens paquets"
    echo "  - Pas de redemarrage automatique"
    echo ""
    
    if ! ask_yes_no "Appliquer cette configuration ?"; then
        wait_continue
        return
    fi
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Configuration MAJ automatiques"
        wait_continue
        return
    fi
    
    # Detection distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        distro_id=${ID}
        distro_codename=${VERSION_CODENAME}
    else
        distro_id="debian"
        distro_codename="stable"
    fi

    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'AUTO_UPG'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
AUTO_UPG
    
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << UNATTENDED_UPG
// ANSSI Hardening - Configuration unattended-upgrades

Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::SyslogEnable "true";
UNATTENDED_UPG
    
    systemctl enable unattended-upgrades
    systemctl start unattended-upgrades
    
    print_result ok "Mises a jour automatiques configurees"
    log_action "AUTO_UPDATES" "Configure" "APPLIQUE"

    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Verifie les mises a jour disponibles
# @details  Met a jour la liste des paquets et affiche les MAJ disponibles
# @return   void
#-------------------------------------------------------------------------------
check_updates() {
    print_section "Verification des mises a jour" "R16"
    
    print_result info "Mise a jour de la liste des paquets..."
    apt-get update -qq
    
    echo ""
    echo -e "${WHITE}Paquets pouvant etre mis a jour:${NC}"
    apt list --upgradable 2>/dev/null | head -20
    
    echo ""
    echo -e "${WHITE}Mises a jour de securite:${NC}"
    apt-get -s dist-upgrade 2>/dev/null | grep -i security | head -10 || echo "  Aucune mise a jour de securite en attente"
    
    log_action "CHECK_UPDATES" "Verification effectuee" "INFO"
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Applique les mises a jour systeme
# @details  Execute apt-get update && upgrade, detecte si reboot necessaire
# @return   void
#-------------------------------------------------------------------------------
apply_security_updates() {
    print_section "Application des mises a jour" "R16"
    
    print_result warn "L'application peut necessiter un redemarrage"
    echo ""
    
    if ! ask_yes_no "Appliquer les mises a jour ?"; then
        wait_continue
        return
    fi
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Application des mises a jour"
        wait_continue
        return
    fi
    
    print_result info "Mise a jour en cours..."
    apt-get update
    apt-get upgrade -y
    
    print_result ok "Mises a jour appliquees"
    
    # Detection reboot necessaire
    if [[ -f /var/run/reboot-required ]]; then
        print_result warn "Un REDEMARRAGE est necessaire!"
        cat /var/run/reboot-required.pkgs 2>/dev/null
    fi
    
    log_action "APPLY_UPDATES" "Mises a jour appliquees" "APPLIQUE"
    
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Nettoie les paquets obsoletes et inutilises
# @details  Execute autoremove et autoclean, affiche les kernels installes
# @return   void
#-------------------------------------------------------------------------------
check_obsolete_packages() {
    print_section "Paquets obsoletes et nettoyage" "R16"
    
    echo -e "${WHITE}Paquets pouvant etre supprimes automatiquement:${NC}"
    apt-get --dry-run autoremove 2>/dev/null | grep "^Remv" | head -15 || echo "  Aucun paquet a supprimer"
    
    echo ""
    echo -e "${WHITE}Kernels installes:${NC}"
    dpkg -l | grep "linux-image" | head -10
    
    echo ""
    
    if ! ask_yes_no "Nettoyer les paquets inutilises ?"; then
        wait_continue
        return
    fi
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Nettoyage des paquets"
        wait_continue
        return
    fi
    
    apt-get autoremove -y
    apt-get autoclean -y
    print_result ok "Nettoyage effectue"
    log_action "CLEAN_PACKAGES" "Nettoye" "APPLIQUE"
    
    wait_continue
}
