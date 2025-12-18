#!/bin/bash
#===============================================================================
# ANSSI Hardening Tool - Module Network
# @file     network.sh
# @brief    Reseau et pare-feu: UFW, nftables, IPv6, TCP Wrappers
# @version  1.1
#===============================================================================

#===============================================================================
# PARE-FEU
#===============================================================================

#-------------------------------------------------------------------------------
# @brief    Configure le pare-feu systeme (UFW ou nftables)
# @details  Detection auto du pare-feu, politique restrictive, autorisation SSH
# @return   void
#-------------------------------------------------------------------------------
configure_firewall() {
    print_section "Configuration du pare-feu" "R10"
    
    local fw_type=""
    
    # Detection pare-feu
    if command -v ufw &>/dev/null; then
        fw_type="ufw"
        echo -e "${WHITE}Pare-feu detecte: UFW${NC}"
    elif command -v nft &>/dev/null; then
        fw_type="nftables"
        echo -e "${WHITE}Pare-feu detecte: nftables${NC}"
    elif command -v iptables &>/dev/null; then
        fw_type="iptables"
        echo -e "${WHITE}Pare-feu detecte: iptables${NC}"
    else
        print_result warn "Aucun pare-feu detecte"
        if ask_yes_no "Installer UFW (recommande) ?"; then
            execute_cmd "Installation UFW" "apt-get update && apt-get install -y ufw"
            fw_type="ufw"
        else
            wait_continue
            return
        fi
    fi
    
    echo ""
    
    case "$fw_type" in
        ufw)
            echo -e "${WHITE}Statut actuel UFW:${NC}"
            ufw status verbose 2>/dev/null
            echo ""
            
            if ! ask_yes_no "Configurer UFW avec politique restrictive ?"; then
                wait_continue
                return
            fi
            
            print_result warn "Cette configuration va:"
            echo "    - Bloquer tout le trafic entrant par defaut"
            echo "    - Autoriser tout le trafic sortant"
            echo "    - Autoriser SSH (port 22)"
            echo ""
            
            if ! ask_yes_no "Confirmer ?"; then
                wait_continue
                return
            fi
            
            if [[ $DRY_RUN -eq 1 ]]; then
                print_result dryrun "Configuration UFW"
                wait_continue
                return
            fi
            
            ufw default deny incoming
            ufw default allow outgoing
            ufw allow ssh
            
            if ask_yes_no "Autoriser d'autres ports ?"; then
                while true; do
                    echo -n "Port a autoriser (ou 'fin'): "
                    read -r port
                    [[ "$port" == "fin" ]] && break
                    [[ "$port" =~ ^[0-9]+$ ]] && ufw allow "$port" && print_result ok "Port $port autorise"
                done
            fi
            
            ufw --force enable
            print_result ok "UFW active"
            ufw status verbose
            log_action "UFW" "Configure et active" "APPLIQUE"
            ;;
            
        nftables)
            if ! ask_yes_no "Creer une configuration nftables de base ?"; then
                wait_continue
                return
            fi
            
            local nft_conf="/etc/nftables.conf"
            [[ -f "$nft_conf" ]] && backup_file "$nft_conf"
            
            if [[ $DRY_RUN -eq 1 ]]; then
                print_result dryrun "Configuration nftables"
                wait_continue
                return
            fi
            
            cat > "$nft_conf" << 'NFTABLES_CONF'
#!/usr/sbin/nft -f
# ANSSI Hardening - Configuration nftables

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        
        # Loopback
        iif lo accept
        
        # Connexions etablies
        ct state established,related accept
        
        # ICMP
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept
        
        # SSH
        tcp dport 22 accept
        
        # Journaliser et rejeter
        log prefix "nftables-drop: " counter drop
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
NFTABLES_CONF
            
            chmod 755 "$nft_conf"
            nft -f "$nft_conf"
            systemctl enable nftables
            
            print_result ok "nftables configure"
            log_action "NFTABLES" "Configure" "APPLIQUE"
            ;;
    esac
    
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Desactive IPv6 sur le systeme
# @details  Configure sysctl pour desactiver IPv6 sur toutes les interfaces
# @return   void
#-------------------------------------------------------------------------------
disable_ipv6() {
    print_section "Desactivation d'IPv6" "R2"
    
    print_result warn "Ne desactivez IPv6 que si vous n'en avez pas besoin"
    print_result info "Certains services modernes peuvent necessiter IPv6"
    echo ""
    
    # Status actuel
    local ipv6_status=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)
    if [[ "$ipv6_status" == "1" ]]; then
        echo -e "${WHITE}IPv6 est actuellement: ${RED}Desactive${NC}"
    else
        echo -e "${WHITE}IPv6 est actuellement: ${GREEN}Active${NC}"
    fi
    echo ""
    
    if ! ask_yes_no "Desactiver IPv6 ?"; then
        wait_continue
        return
    fi
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Desactivation IPv6"
        wait_continue
        return
    fi
    
    cat > /etc/sysctl.d/99-disable-ipv6.conf << 'IPV6_CONF'
# ANSSI Hardening - Desactivation IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
IPV6_CONF
    
    sysctl -p /etc/sysctl.d/99-disable-ipv6.conf >/dev/null 2>&1
    
    print_result ok "IPv6 desactive"
    log_action "IPV6" "Desactive" "APPLIQUE"
    
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Configure TCP Wrappers (hosts.allow/hosts.deny)
# @details  Politique restrictive: deny all, allow SSH depuis reseaux prives
# @return   void
#-------------------------------------------------------------------------------
configure_tcp_wrappers() {
    print_section "Configuration TCP Wrappers" "R10"
    
    echo -e "${WHITE}TCP Wrappers controle l'acces aux services via:${NC}"
    echo "  /etc/hosts.allow - Services autorises"
    echo "  /etc/hosts.deny  - Services refuses"
    echo ""
    
    # Configuration actuelle
    echo -e "${WHITE}Configuration actuelle:${NC}"
    echo "hosts.allow:"
    grep -v "^#" /etc/hosts.allow 2>/dev/null | grep -v "^$" | head -5 || echo "  (vide)"
    echo "hosts.deny:"
    grep -v "^#" /etc/hosts.deny 2>/dev/null | grep -v "^$" | head -5 || echo "  (vide)"
    echo ""
    
    if ! ask_yes_no "Configurer une politique restrictive ?"; then
        wait_continue
        return
    fi
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Configuration TCP Wrappers"
        wait_continue
        return
    fi
    
    backup_file "/etc/hosts.allow"
    backup_file "/etc/hosts.deny"
    
    cat > /etc/hosts.deny << 'HOSTS_DENY'
# ANSSI Hardening - Politique par defaut: refuser tout
ALL: ALL
HOSTS_DENY
    
    cat > /etc/hosts.allow << 'HOSTS_ALLOW'
# ANSSI Hardening - Services autorises
# Ajustez selon vos besoins

# SSH depuis localhost et reseaux prives
sshd: 127.0.0.1
sshd: 10.0.0.0/8
sshd: 172.16.0.0/12
sshd: 192.168.0.0/16
HOSTS_ALLOW
    
    print_result ok "TCP Wrappers configure"
    print_result warn "Verifiez /etc/hosts.allow selon vos besoins"
    log_action "TCP_WRAPPERS" "Configure" "APPLIQUE"
    
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Affiche un audit des ports ouverts et connexions
# @details  Utilise ss/netstat pour lister TCP/UDP en ecoute et connexions etablies
# @return   void
#-------------------------------------------------------------------------------
audit_open_ports() {
    print_section "Audit des ports ouverts" "R2"
    
    echo -e "${WHITE}Ports TCP en ecoute:${NC}"
    ss -tlnp 2>/dev/null | head -20 || netstat -tlnp 2>/dev/null | head -20
    
    echo ""
    echo -e "${WHITE}Ports UDP en ecoute:${NC}"
    ss -ulnp 2>/dev/null | head -15 || netstat -ulnp 2>/dev/null | head -15
    
    echo ""
    echo -e "${WHITE}Connexions etablies:${NC}"
    ss -tnp 2>/dev/null | head -10 || netstat -tnp 2>/dev/null | head -10
    
    log_action "AUDIT_PORTS" "Audit effectue" "INFO"
    wait_continue
}
