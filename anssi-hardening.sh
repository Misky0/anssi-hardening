#!/bin/bash

#===============================================================================
# ANSSI Hardening Tool - Durcissement systeme Linux
# @file     anssi-hardening.sh
# @brief    Script principal - Point d'entree du programme
# @version  1.1
# @details  Compatibilite: Debian / Ubuntu
#           Reference: ANSSI-PA-085
#
# Structure modulaire:
#   lib/core.sh     - Fonctions de base (affichage, logs, utilitaires)
#   lib/system.sh   - Configuration systeme (services, sysctl, modules)
#   lib/accounts.sh - Comptes et authentification (PAM, mots de passe)
#   lib/ssh.sh      - Securite SSH et fail2ban
#   lib/network.sh  - Reseau et pare-feu
#   lib/updates.sh  - Mises a jour
#   lib/audit.sh    - Audit et journalisation
#   lib/menus.sh    - Interface utilisateur (menus)
#===============================================================================

set -o pipefail


readonly VERSION="1.1"
readonly SCRIPT_NAME="ANSSI Hardening Tool"
readonly LOG_FILE="/var/log/anssi-hardening.log"
readonly BACKUP_DIR="/var/backups/anssi-hardening"

# Variables d'etat
DRY_RUN=0
SHOW_BANNER=1
declare -A ACTIONS_APPLIED ACTIONS_IGNORED ACTIONS_DRYRUN
CURRENT_MENU="main"


#-------------------------------------------------------------------------------
# @brief    Detecte le repertoire absolu contenant ce script
# @details  Resout les liens symboliques pour trouver le vrai chemin
# @return   Chemin absolu du repertoire du script
#-------------------------------------------------------------------------------
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    local dir
    
    # Resoudre les liens symboliques
    while [[ -L "$source" ]]; do
        dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ "$source" != /* ]] && source="$dir/$source"
    done
    
    dir="$(cd -P "$(dirname "$source")" && pwd)"
    echo "$dir"
}

SCRIPT_DIR="$(get_script_dir)"
LIB_DIR="${SCRIPT_DIR}/lib"


#-------------------------------------------------------------------------------
# @brief    Charge tous les modules depuis le repertoire lib/
# @details  Modules: core, system, accounts, ssh, network, updates, audit, menus
# @return   exit 1 si un module est introuvable
#-------------------------------------------------------------------------------
load_modules() {
    local modules=(
        "core.sh"
        "system.sh"
        "accounts.sh"
        "ssh.sh"
        "network.sh"
        "updates.sh"
        "audit.sh"
        "menus.sh"
    )
    
    for module in "${modules[@]}"; do
        local module_path="${LIB_DIR}/${module}"
        if [[ -f "$module_path" ]]; then
            # shellcheck source=/dev/null
            source "$module_path"
        else
            echo "Erreur: Module introuvable: $module_path" >&2
            exit 1
        fi
    done
}


#-------------------------------------------------------------------------------
# @brief    Fonction principale du script
# @param    $@  Arguments de ligne de commande (--dry-run, --help)
# @return   exit 0 en cas de succes
#-------------------------------------------------------------------------------
main() {
    # Traitement des arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run|-d) 
                DRY_RUN=1
                shift 
                ;;
            --help|-h)
                echo "ANSSI Hardening Tool v$VERSION"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo "  --dry-run, -d    Mode simulation (aucune modification)"
                echo "  --help, -h       Afficher cette aide"
                exit 0 
                ;;
            *) 
                echo "Option inconnue: $1"
                exit 1 
                ;;
        esac
    done
    
    # Charger les modules
    load_modules
    
    # Verifications initiales
    check_root
    init_environment
    
    # Message de bienvenue
    echo -e "${GREEN}Bienvenue dans ANSSI Hardening Tool v$VERSION${NC}"
    
    # Lancer le menu principal
    menu_main
}


trap 'echo ""; echo -e "\033[1;33mUtilisez quit pour quitter proprement.\033[0m"; sleep 1' SIGINT


main "$@"
