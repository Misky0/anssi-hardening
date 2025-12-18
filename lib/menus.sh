#!/bin/bash
#===============================================================================
# ANSSI Hardening Tool - Module Menus
# @file     menus.sh
# @brief    Interface utilisateur: menus de navigation
# @version  1.1
#===============================================================================


#-------------------------------------------------------------------------------
# @brief    Affiche et gere le menu de configuration systeme
# @return   0 pour retour au menu parent
#-------------------------------------------------------------------------------
menu_system() {
    CURRENT_MENU="system"
    while true; do
        print_banner
        echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${WHITE}              CONFIGURATION SYSTEME (Hardening)                      ${CYAN}│${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│                                                                     │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}1.${NC}  Desactiver services non essentiels                    ${GREEN}[R2]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}2.${NC}  Permissions fichiers systeme                          ${GREEN}[R1]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}3.${NC}  Durcir parametres kernel (sysctl)                     ${GREEN}[R3]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}4.${NC}  Options de montage securisees                         ${GREEN}[R2]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}5.${NC}  Blacklist modules kernel                              ${GREEN}[R2]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}6.${NC}  Securiser GRUB                                        ${GREEN}[R1]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}7.${NC}  Durcir unites systemd                             ${GREEN}[R2,R15]${CYAN}    │${NC}"
        echo -e "${CYAN}│                                                                     │${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│${NC}   ${WHITE}back${NC} - Retour    ${WHITE}help${NC} - Aide    ${WHITE}quit${NC} - Quitter                    ${CYAN}│${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -n -e "  ${WHITE}Votre choix: ${NC}"
        read -r choice
        handle_global_commands "$choice"
        local ret=$?
        [[ $ret -eq 2 || $ret -eq 3 ]] && return 0
        [[ $ret -eq 0 ]] && continue
        case "$choice" in
            1) disable_services ;;
            2) configure_permissions ;;
            3) harden_sysctl ;;
            4) configure_mount_options ;;
            5) disable_kernel_modules ;;
            6) configure_grub ;;
            7) harden_systemd_units ;;
            *) echo -e "  ${RED}Option invalide.${NC}"; sleep 1 ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# @brief    Affiche et gere le menu de gestion des comptes
# @return   0 pour retour au menu parent
#-------------------------------------------------------------------------------
menu_accounts() {
    CURRENT_MENU="accounts"
    while true; do
        print_banner
        echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${WHITE}                 COMPTES & AUTHENTIFICATION                          ${CYAN}│${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│                                                                     │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}1.${NC}  Politique mots de passe + SHA512 rounds              ${GREEN}[R14]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}2.${NC}  pam_pwquality (complexite mots de passe)             ${GREEN}[R14]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}3.${NC}  pam_faillock (anti-bruteforce)                       ${GREEN}[R14]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}4.${NC}  Verrouillage comptes inactifs                        ${GREEN}[R13]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}5.${NC}  Securiser compte root                                ${GREEN}[R11]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}6.${NC}  Auditer comptes utilisateurs                         ${GREEN}[R13]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}7.${NC}  Configurer umask                                     ${GREEN}[R15]${CYAN}    │${NC}"
        echo -e "${CYAN}│                                                                     │${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│${NC}   ${WHITE}back${NC} - Retour    ${WHITE}help${NC} - Aide    ${WHITE}quit${NC} - Quitter                    ${CYAN}│${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -n -e "  ${WHITE}Votre choix: ${NC}"
        read -r choice
        handle_global_commands "$choice"
        local ret=$?
        [[ $ret -eq 2 || $ret -eq 3 ]] && return 0
        [[ $ret -eq 0 ]] && continue
        case "$choice" in
            1) configure_password_policy ;;
            2) configure_pam_pwquality ;;
            3) configure_pam_faillock ;;
            4) lock_inactive_accounts ;;
            5) secure_root_account ;;
            6) audit_users ;;
            7) configure_umask ;;
            *) echo -e "  ${RED}Option invalide.${NC}"; sleep 1 ;;
        esac
    done
}


#-------------------------------------------------------------------------------
# @brief    Affiche et gere le menu de securite SSH
# @return   0 pour retour au menu parent
#-------------------------------------------------------------------------------
menu_ssh() {
    CURRENT_MENU="ssh"
    while true; do
        print_banner
        echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${WHITE}                         SECURITE SSH                                ${CYAN}│${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│                                                                     │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}1.${NC}  Durcir configuration SSH                          ${GREEN}[R9,R12]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}2.${NC}  Authentification par cle SSH                         ${GREEN}[R14]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}3.${NC}  Restreindre utilisateurs SSH                         ${GREEN}[R15]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}4.${NC}  Configurer fail2ban                                   ${GREEN}[R9]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}5.${NC}  Changer port SSH                                      ${GREEN}[R9]${CYAN}    │${NC}"
        echo -e "${CYAN}│                                                                     │${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│${NC}   ${WHITE}back${NC} - Retour    ${WHITE}help${NC} - Aide    ${WHITE}quit${NC} - Quitter                    ${CYAN}│${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -n -e "  ${WHITE}Votre choix: ${NC}"
        read -r choice
        handle_global_commands "$choice"
        local ret=$?
        [[ $ret -eq 2 || $ret -eq 3 ]] && return 0
        [[ $ret -eq 0 ]] && continue
        case "$choice" in
            1) harden_ssh ;;
            2) configure_ssh_keys ;;
            3) restrict_ssh_users ;;
            4) configure_fail2ban ;;
            5) change_ssh_port ;;
            *) echo -e "  ${RED}Option invalide.${NC}"; sleep 1 ;;
        esac
    done
}

-------------------------------------------------------------------------------
# @brief    Affiche et gere le menu reseau et pare-feu
# @return   0 pour retour au menu parent
#-------------------------------------------------------------------------------
menu_network() {
    CURRENT_MENU="network"
    while true; do
        print_banner
        echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${WHITE}                       RESEAU & PARE-FEU                             ${CYAN}│${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│                                                                     │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}1.${NC}  Configurer pare-feu (UFW/nftables)                   ${GREEN}[R10]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}2.${NC}  Desactiver IPv6                                       ${GREEN}[R2]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}3.${NC}  Configurer TCP Wrappers                              ${GREEN}[R10]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}4.${NC}  Auditer ports ouverts                                 ${GREEN}[R2]${CYAN}    │${NC}"
        echo -e "${CYAN}│                                                                     │${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│${NC}   ${WHITE}back${NC} - Retour    ${WHITE}help${NC} - Aide    ${WHITE}quit${NC} - Quitter                    ${CYAN}│${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -n -e "  ${WHITE}Votre choix: ${NC}"
        read -r choice
        handle_global_commands "$choice"
        local ret=$?
        [[ $ret -eq 2 || $ret -eq 3 ]] && return 0
        [[ $ret -eq 0 ]] && continue
        case "$choice" in
            1) configure_firewall ;;
            2) disable_ipv6 ;;
            3) configure_tcp_wrappers ;;
            4) audit_open_ports ;;
            *) echo -e "  ${RED}Option invalide.${NC}"; sleep 1 ;;
        esac
    done
}


#-------------------------------------------------------------------------------
# @brief    Affiche et gere le menu des mises a jour
# @return   0 pour retour au menu parent
#-------------------------------------------------------------------------------
menu_updates() {
    CURRENT_MENU="updates"
    while true; do
        print_banner
        echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${WHITE}                      MISES A JOUR & MCS                             ${CYAN}│${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│                                                                     │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}1.${NC}  Configurer mises a jour automatiques                 ${GREEN}[R16]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}2.${NC}  Verifier mises a jour disponibles                    ${GREEN}[R16]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}3.${NC}  Appliquer mises a jour securite                      ${GREEN}[R16]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}4.${NC}  Nettoyer paquets obsoletes                           ${GREEN}[R16]${CYAN}    │${NC}"
        echo -e "${CYAN}│                                                                     │${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│${NC}   ${WHITE}back${NC} - Retour    ${WHITE}help${NC} - Aide    ${WHITE}quit${NC} - Quitter                    ${CYAN}│${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -n -e "  ${WHITE}Votre choix: ${NC}"
        read -r choice
        handle_global_commands "$choice"
        local ret=$?
        [[ $ret -eq 2 || $ret -eq 3 ]] && return 0
        [[ $ret -eq 0 ]] && continue
        case "$choice" in
            1) configure_auto_updates ;;
            2) check_updates ;;
            3) apply_security_updates ;;
            4) check_obsolete_packages ;;
            *) echo -e "  ${RED}Option invalide.${NC}"; sleep 1 ;;
        esac
    done
}

===============================================================================

#-------------------------------------------------------------------------------
# @brief    Affiche et gere le menu audit et journalisation
# @return   0 pour retour au menu parent
#-------------------------------------------------------------------------------
menu_audit() {
    CURRENT_MENU="audit"
    while true; do
        print_banner
        echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${WHITE}                    AUDIT & JOURNALISATION                           ${CYAN}│${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│                                                                     │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}1.${NC}  Configurer auditd                                    ${GREEN}[R19]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}2.${NC}  Rotation des logs                                    ${GREEN}[R19]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}3.${NC}  Journalisation commandes bash                        ${GREEN}[R19]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}4.${NC}  Verifier rsyslog                                     ${GREEN}[R19]${CYAN}    │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}5.${NC}  AIDE (integrite fichiers)                            ${GREEN}[R19]${CYAN}    │${NC}"
        echo -e "${CYAN}│                                                                     │${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│${NC}   ${WHITE}back${NC} - Retour    ${WHITE}help${NC} - Aide          ${WHITE}quit${NC} - Quitter              ${CYAN}│${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -n -e "  ${WHITE}Votre choix: ${NC}"
        read -r choice
        handle_global_commands "$choice"
        local ret=$?
        [[ $ret -eq 2 || $ret -eq 3 ]] && return 0
        [[ $ret -eq 0 ]] && continue
        case "$choice" in
            1) configure_auditd ;;
            2) configure_logrotate ;;
            3) enable_command_logging ;;
            4) configure_rsyslog ;;
            5) configure_aide ;;
            *) echo -e "  ${RED}Option invalide.${NC}"; sleep 1 ;;
        esac
    done
}


#-------------------------------------------------------------------------------
# @brief    Affiche et gere le menu principal
# @return   Ne retourne jamais (boucle infinie jusqu'a quit)
#-------------------------------------------------------------------------------
menu_main() {
    CURRENT_MENU="main"
    while true; do
        print_banner
        echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${WHITE}                        MENU PRINCIPAL                               ${CYAN}│${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│                                                                     │${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}1.${NC}  Configuration systeme (hardening)                             ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}2.${NC}  Comptes & authentification                                    ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}3.${NC}  Securite SSH                                                  ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}4.${NC}  Reseau & pare-feu                                             ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}5.${NC}  Mises a jour & MCS                                            ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}   ${YELLOW}6.${NC}  Audit & journalisation                                        ${CYAN}│${NC}"
        echo -e "${CYAN}│                                                                     │${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        if [[ $DRY_RUN -eq 1 ]]; then
        echo -e "${CYAN}│${NC}   ${YELLOW}7.${NC}  Mode dry-run                               ${GREEN}[ACTIF]${CYAN}            │${NC}"
        else
        echo -e "${CYAN}│${NC}   ${YELLOW}7.${NC}  Mode dry-run                             ${RED}[INACTIF]${CYAN}            │${NC}"
        fi
        echo -e "${CYAN}│${NC}   ${YELLOW}8.${NC}  Afficher resume des actions                                   ${CYAN}│${NC}"
        echo -e "${CYAN}│                                                                     │${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│${NC}   ${WHITE}help${NC} - Aide                           ${WHITE}quit${NC} - Quitter              ${CYAN}│${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -n -e "  ${WHITE}Votre choix: ${NC}"
        read -r choice
        handle_global_commands "$choice"
        [[ $? -eq 0 ]] && continue
        case "$choice" in
            1) menu_system ;;
            2) menu_accounts ;;
            3) menu_ssh ;;
            4) menu_network ;;
            5) menu_updates ;;
            6) menu_audit ;;
            7) toggle_dryrun ;;
            8) show_summary; wait_continue ;;
            *) echo -e "  ${RED}Option invalide. Tapez 'help' pour l'aide.${NC}"; sleep 1 ;;
        esac
    done
}
