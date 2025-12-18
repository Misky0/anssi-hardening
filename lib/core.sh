#!/bin/bash
#===============================================================================
# ANSSI Hardening Tool - Module Core
# @file     core.sh
# @brief    Fonctions de base: affichage, logs, utilitaires
# @version  1.1
#===============================================================================

# Couleurs et formatage
readonly RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m' CYAN='\033[0;36m' PURPLE='\033[0;35m'
readonly WHITE='\033[1;37m' NC='\033[0m' BOLD='\033[1m'

#-------------------------------------------------------------------------------
# @brief    Affiche la banniere ASCII du script
# @return   void
#-------------------------------------------------------------------------------
print_banner() {
    echo ""
    echo -e "${CYAN}"
    cat << 'BANNER'
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                                                                           ║
    ║     █████╗ ███╗   ██╗███████╗███████╗██╗    ██╗  ██╗ █████╗ ██████╗       ║
    ║    ██╔══██╗████╗  ██║██╔════╝██╔════╝██║    ██║  ██║██╔══██╗██╔══██╗      ║
    ║    ███████║██╔██╗ ██║███████╗███████╗██║    ███████║███████║██████╔╝      ║
    ║    ██╔══██║██║╚██╗██║╚════██║╚════██║██║    ██╔══██║██╔══██║██╔══██╗      ║
    ║    ██║  ██║██║ ╚████║███████║███████║██║    ██║  ██║██║  ██║██║  ██║      ║
    ║    ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝╚═╝    ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝      ║
    ║                                                                           ║
    ║          ╔═══════════════════════════════════════════════════╗            ║
    ║          ║  HARDENING TOOL - Durcissement Systeme Linux      ║            ║
    ║          ║  Base sur les recommandations ANSSI-PA-085        ║            ║
    ║          ╚═══════════════════════════════════════════════════╝            ║
    ║                                                                           ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
    echo -e "                         ${WHITE}Version ${VERSION}${NC}"
    [[ $DRY_RUN -eq 1 ]] && echo -e "                    ${YELLOW}[!] MODE DRY-RUN ACTIF${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# @brief    Affiche un titre de section avec reference ANSSI optionnelle
# @param    $1  Titre de la section
# @param    $2  Reference ANSSI (optionnel)
# @return   void
#-------------------------------------------------------------------------------
print_section() {
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  $1${NC}"
    [[ -n "$2" ]] && echo -e "${CYAN}  Reference ANSSI: $2${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# @brief    Affiche un message de resultat formate
# @param    $1  Type: ok|fail|skip|dryrun|info|warn
# @param    $2  Message a afficher
# @return   void
#-------------------------------------------------------------------------------
print_result() {
    local status="$1" msg="$2"
    case "$status" in
        ok)     echo -e "  ${GREEN}[OK]${NC} $msg" ;;
        fail)   echo -e "  ${RED}[ECHEC]${NC} $msg" ;;
        skip)   echo -e "  ${YELLOW}[IGNORE]${NC} $msg" ;;
        dryrun) echo -e "  ${BLUE}[DRY-RUN]${NC} $msg" ;;
        info)   echo -e "  ${WHITE}[INFO]${NC} $msg" ;;
        warn)   echo -e "  ${YELLOW}[ATTENTION]${NC} $msg" ;;
    esac
}


#-------------------------------------------------------------------------------
# @brief    Verifie que le script est execute en tant que root
# @return   0 si root, exit 1 sinon
#-------------------------------------------------------------------------------
check_root() {
    [[ $EUID -ne 0 ]] && { echo -e "${RED}Erreur: Executez en tant que root (sudo)${NC}"; exit 1; }
    return 0
}

#-------------------------------------------------------------------------------
# @brief    Initialise l'environnement (dossiers, fichiers de log)
# @return   void
#-------------------------------------------------------------------------------
init_environment() {
    [[ ! -d "$BACKUP_DIR" ]] && mkdir -p "$BACKUP_DIR" && chmod 700 "$BACKUP_DIR"
    [[ ! -f "$LOG_FILE" ]] && touch "$LOG_FILE" && chmod 600 "$LOG_FILE"
    log_action "SESSION" "Demarrage $SCRIPT_NAME v$VERSION"
}


#-------------------------------------------------------------------------------
# @brief    Enregistre une action dans le journal et les compteurs
# @param    $1  Identifiant de l'action
# @param    $2  Description de l'action
# @param    $3  Statut: INFO|APPLIQUE|IGNORE|DRY-RUN (defaut: INFO)
# @return   void
#-------------------------------------------------------------------------------
log_action() {
    local action="$1" desc="$2" status="${3:-INFO}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$status] [$action] $desc" >> "$LOG_FILE"
    case "$status" in
        "APPLIQUE") ACTIONS_APPLIED["$action"]="$desc" ;;
        "IGNORE")   ACTIONS_IGNORED["$action"]="$desc" ;;
        "DRY-RUN")  ACTIONS_DRYRUN["$action"]="$desc" ;;
    esac
}


#-------------------------------------------------------------------------------
# @brief    Sauvegarde un fichier avec horodatage
# @param    $1  Chemin du fichier a sauvegarder
# @return   0 si succes, 1 si echec ou fichier inexistant
#-------------------------------------------------------------------------------
backup_file() {
    local file="$1"
    [[ ! -f "$file" ]] && return 1
    
    local bak="${BACKUP_DIR}/$(basename "$file")_$(date +%Y%m%d_%H%M%S).bak"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Sauvegarde de $file"
        return 0
    fi
    
    if cp -p "$file" "$bak" 2>/dev/null; then
        print_result ok "Sauvegarde: $bak"
        return 0
    fi
    
    print_result fail "Sauvegarde de $file"
    return 1
}

#-------------------------------------------------------------------------------
# @brief    Execute une commande avec gestion dry-run et journalisation
# @param    $1  Description de l'action
# @param    $@  Commande a executer
# @return   0 si succes ou dry-run, 1 si echec
#-------------------------------------------------------------------------------
execute_cmd() {
    local desc="$1"; shift
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "$desc"
        log_action "CMD" "$desc" "DRY-RUN"
        return 0
    fi
    
    if eval "$@" 2>/dev/null; then
        print_result ok "$desc"
        log_action "CMD" "$desc" "APPLIQUE"
        return 0
    fi
    
    print_result fail "$desc"
    return 1
}


#-------------------------------------------------------------------------------
# @brief    Pose une question oui/non a l'utilisateur
# @param    $1  Question a poser
# @return   0=oui, 1=non, 2=menu, 3=back
#-------------------------------------------------------------------------------
ask_yes_no() {
    local q="$1" r
    while true; do
        echo -n -e "${WHITE}$q ${CYAN}[o/n]${NC}: "
        read -r r
        r=$(echo "$r" | tr '[:upper:]' '[:lower:]')
        case "$r" in
            oui|o|yes|y) return 0 ;;
            non|n|no)    return 1 ;;
            help)        show_help ;;
            menu)        return 2 ;;
            back)        return 3 ;;
            quit|exit)   clean_exit ;;
            *) echo -e "${RED}  Reponse invalide. Tapez 'o' pour oui ou 'n' pour non.${NC}" ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# @brief    Traite les commandes globales (help, menu, back, quit)
# @param    $1  Commande saisie par l'utilisateur
# @return   0=commande traitee, 1=commande inconnue, 2=menu, 3=back
#-------------------------------------------------------------------------------
handle_global_commands() {
    local cmd=$(echo "$1" | tr '[:upper:]' '[:lower:]' | xargs)
    case "$cmd" in
        help)      show_help; wait_continue; return 0 ;; 
        menu)      return 2 ;;
        back)      return 3 ;;
        quit|exit) clean_exit ;;
        *)         return 1 ;;
    esac
}

#-------------------------------------------------------------------------------
# @brief    Affiche l'aide des commandes disponibles
# @return   void
#-------------------------------------------------------------------------------
show_help() {
    echo ""
    echo -e "${CYAN}=== AIDE ===${NC}"
    echo -e "  ${GREEN}help${NC}  - Afficher cette aide"
    echo -e "  ${GREEN}menu${NC}  - Retourner au menu principal"
    echo -e "  ${GREEN}back${NC}  - Retourner au menu precedent"
    echo -e "  ${GREEN}quit${NC}  - Quitter le script"
    echo -e "  Reponses: ${GREEN}oui/o/y${NC} pour confirmer, ${RED}non/n${NC} pour refuser"
    echo ""
}

#-------------------------------------------------------------------------------
# @brief    Attend que l'utilisateur appuie sur Entree
# @return   void
#-------------------------------------------------------------------------------
wait_continue() {
    echo ""
    read -r -p "Appuyez sur Entree pour continuer..."
}



#-------------------------------------------------------------------------------
# @brief    Affiche le resume des actions effectuees
# @return   void
#-------------------------------------------------------------------------------
show_summary() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${WHITE}RESUME DES ACTIONS${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}Actions appliquees:${NC}  ${#ACTIONS_APPLIED[@]}                                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}Actions ignorees:${NC}    ${#ACTIONS_IGNORED[@]}                                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}Actions dry-run:${NC}     ${#ACTIONS_DRYRUN[@]}                                       ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  Journal: ${WHITE}$LOG_FILE${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  Sauvegardes: ${WHITE}$BACKUP_DIR${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# @brief    Termine proprement le script avec resume
# @return   exit 0
#-------------------------------------------------------------------------------
clean_exit() {
    log_action "SESSION" "Fin de session"
    show_summary
    echo -e "${GREEN}Merci d'avoir utilise $SCRIPT_NAME !${NC}"
    exit 0
}

#-------------------------------------------------------------------------------
# @brief    Bascule le mode dry-run on/off
# @return   void
#-------------------------------------------------------------------------------
toggle_dryrun() {
    if [[ $DRY_RUN -eq 0 ]]; then
        DRY_RUN=1
        print_result ok "Mode DRY-RUN active (simulation sans modification)"
    else
        DRY_RUN=0
        print_result ok "Mode DRY-RUN desactive (modifications reelles)"
    fi
    log_action "DRY-RUN" "Mode dry-run: $DRY_RUN" "INFO"
    echo ""
    read -r -p "Appuyez sur Entree pour continuer..."
}
