#!/bin/bash
#===============================================================================
# ANSSI Hardening Tool - Module System
# @file     system.sh
# @brief    Configuration systeme: services, sysctl, modules, GRUB, systemd
# @version  1.1
#===============================================================================

#-------------------------------------------------------------------------------
# @brief    Desactive les services systeme non essentiels
# @details  Services cibles: avahi, cups, bluetooth, rpcbind, nfs, vsftpd, telnet
# @return   void
#-------------------------------------------------------------------------------
disable_services() {
    print_section "Desactivation des services non essentiels" "R2"
    
    local services=("avahi-daemon" "cups" "cups-browsed" "bluetooth" "rpcbind" "nfs-server" "vsftpd" "telnet")
    local disabled=0
    
    for svc in "${services[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}"; then
            local status=$(systemctl is-enabled "$svc" 2>/dev/null || echo "non installe")
            local running=$(systemctl is-active "$svc" 2>/dev/null || echo "inactif")
            
            echo -e "  ${WHITE}Service:${NC} $svc"
            echo -e "    Status: $status | Etat: $running"
            
            if [[ "$status" == "enabled" ]]; then
                if ask_yes_no "    Desactiver $svc ?"; then
                    if execute_cmd "Desactivation de $svc" "systemctl disable --now $svc"; then
                        ((disabled++))
                        log_action "SERVICE_$svc" "Desactive" "APPLIQUE"
                    fi
                else
                    log_action "SERVICE_$svc" "Ignore par utilisateur" "IGNORE"
                fi
            fi
            echo ""
        fi
    done
    
    print_result info "Services desactives: $disabled"
    wait_continue
}
#-------------------------------------------------------------------------------
# @brief    Corrige les permissions des fichiers systeme sensibles
# @details  Fichiers: passwd, shadow, group, gshadow, sshd_config, crontab, sudoers
# @return   void
#-------------------------------------------------------------------------------
configure_permissions() {
    print_section "Permissions des fichiers systeme" "R1"
    
    local files_perms=(
        "/etc/passwd:644"
        "/etc/shadow:600"
        "/etc/group:644"
        "/etc/gshadow:600"
        "/etc/ssh/sshd_config:600"
        "/etc/crontab:600"
        "/etc/sudoers:440"
    )
    local modified=0
    
    for fp in "${files_perms[@]}"; do
        local file="${fp%%:*}"
        local target_perm="${fp#*:}"
        
        if [[ -f "$file" ]]; then
            local current=$(stat -c "%a" "$file" 2>/dev/null)
            
            if [[ "$current" != "$target_perm" ]]; then
                echo -e "  ${WHITE}$file${NC}: $current -> $target_perm"
                if ask_yes_no "    Corriger les permissions ?"; then
                    backup_file "$file"
                    if execute_cmd "chmod $target_perm $file" "chmod $target_perm $file"; then
                        ((modified++))
                        log_action "PERM_$(basename $file)" "Permissions corrigees" "APPLIQUE"
                    fi
                else
                    log_action "PERM_$(basename $file)" "Ignore" "IGNORE"
                fi
            else
                print_result ok "$file: permissions correctes ($current)"
            fi
        fi
    done
    
    print_result info "Fichiers modifies: $modified"
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Configure les parametres kernel via sysctl
# @details  Applique: protection SYN flood, ASLR, rp_filter, restrictions kernel
# @return   void
#-------------------------------------------------------------------------------
harden_sysctl() {
    print_section "Durcissement sysctl (parametres kernel)" "R3"
    
    local sysctl_file="/etc/sysctl.d/99-anssi-hardening.conf"
    
    echo -e "${WHITE}Parametres qui seront configures:${NC}"
    echo "  - Protection SYN flood"
    echo "  - Desactivation routage IP"
    echo "  - Protection spoofing (rp_filter)"
    echo "  - ASLR active"
    echo "  - Restriction dmesg et pointeurs kernel"
    echo "  - Protection liens symboliques"
    echo ""
    
    if ! ask_yes_no "Appliquer cette configuration ?"; then
        log_action "SYSCTL" "Ignore par utilisateur" "IGNORE"
        wait_continue
        return
    fi
    
    [[ -f "$sysctl_file" ]] && backup_file "$sysctl_file"
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Creation de $sysctl_file"
        log_action "SYSCTL" "Configuration sysctl" "DRY-RUN"
        wait_continue
        return
    fi
    
    cat > "$sysctl_file" << 'SYSCTL_CONF'
# ANSSI Hardening Tool - Configuration sysctl
# Reference: ANSSI-PA-085

# === RESEAU ===
net.ipv4.ip_forward = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.log_martians = 1

# === KERNEL ===
kernel.randomize_va_space = 2
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.sysrq = 0
kernel.core_uses_pid = 1
kernel.yama.ptrace_scope = 1

# === FILESYSTEM ===
fs.suid_dumpable = 0
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
SYSCTL_CONF

    chmod 644 "$sysctl_file"
    
    if sysctl -p "$sysctl_file" >/dev/null 2>&1; then
        print_result ok "Configuration sysctl appliquee"
        log_action "SYSCTL" "Configuration appliquee" "APPLIQUE"
    else
        print_result warn "Certains parametres peuvent ne pas etre supportes"
        log_action "SYSCTL" "Applique avec avertissements" "APPLIQUE"
    fi
    
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Affiche les recommandations pour les options de montage
# @details  Recommandations: nodev, nosuid, noexec pour /tmp, /var/tmp, /dev/shm
# @return   void
#-------------------------------------------------------------------------------
configure_mount_options() {
    print_section "Options de montage securisees" "R2"
    
    echo -e "${WHITE}Recommandations pour /etc/fstab:${NC}"
    echo ""
    echo "  # Partitions temporaires avec restrictions"
    echo "  tmpfs  /tmp      tmpfs  defaults,nodev,nosuid,noexec  0 0"
    echo "  tmpfs  /var/tmp  tmpfs  defaults,nodev,nosuid,noexec  0 0"
    echo "  tmpfs  /dev/shm  tmpfs  defaults,nodev,nosuid,noexec  0 0"
    echo ""
    echo "  # Home avec nodev"
    echo "  /dev/xxx  /home  ext4  defaults,nodev  0 2"
    echo ""
    
    print_result warn "Modifiez manuellement /etc/fstab et redemarrez"
    log_action "FSTAB" "Recommandations affichees" "INFO"
    
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Cree une blacklist des modules kernel inutiles
# @details  Modules: dccp, sctp, rds, tipc, cramfs, freevxfs, hfs, hfsplus, udf, usb-storage
# @return   void
#-------------------------------------------------------------------------------
disable_kernel_modules() {
    print_section "Blacklist des modules kernel inutiles" "R2"
    
    local modprobe_file="/etc/modprobe.d/anssi-blacklist.conf"
    local modules=("dccp" "sctp" "rds" "tipc" "cramfs" "freevxfs" "hfs" "hfsplus" "udf" "usb-storage")
    
    echo -e "${WHITE}Modules qui seront blacklistes:${NC}"
    printf '  %s\n' "${modules[@]}"
    echo ""
    
    if ! ask_yes_no "Creer la blacklist ?"; then
        log_action "MODULES" "Ignore" "IGNORE"
        wait_continue
        return
    fi
    
    if [[ $DRY_RUN -eq 1 ]]; then
        print_result dryrun "Creation de $modprobe_file"
        log_action "MODULES" "Blacklist" "DRY-RUN"
        wait_continue
        return
    fi
    
    echo "# ANSSI Hardening - Blacklist modules" > "$modprobe_file"
    for mod in "${modules[@]}"; do
        echo "install $mod /bin/true" >> "$modprobe_file"
        echo "blacklist $mod" >> "$modprobe_file"
    done
    chmod 644 "$modprobe_file"
    
    print_result ok "Blacklist creee: $modprobe_file"
    print_result info "Redemarrage necessaire pour appliquer"
    log_action "MODULES" "Blacklist creee" "APPLIQUE"
    
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Affiche les instructions pour securiser GRUB
# @details  Protection par mot de passe du bootloader
# @return   void
#-------------------------------------------------------------------------------
configure_grub() {
    print_section "Securisation du bootloader GRUB" "R1"
    
    print_result warn "ATTENTION: Une erreur peut empecher le demarrage!"
    echo ""
    echo -e "${WHITE}Etapes pour proteger GRUB par mot de passe:${NC}"
    echo ""
    echo "  1. Generer le hash du mot de passe:"
    echo -e "     ${CYAN}grub-mkpasswd-pbkdf2${NC}"
    echo ""
    echo "  2. Ajouter dans /etc/grub.d/40_custom:"
    echo '     set superusers="root"'
    echo '     password_pbkdf2 root <HASH_GENERE>'
    echo ""
    echo "  3. Mettre a jour GRUB:"
    echo -e "     ${CYAN}update-grub${NC}"
    echo ""
    
    log_action "GRUB" "Instructions affichees" "INFO"
    wait_continue
}


#-------------------------------------------------------------------------------
# @brief    Cree des overrides de durcissement pour les services systemd
# @details  Applique: ProtectSystem, NoNewPrivileges, PrivateTmp, CapabilityBoundingSet
# @return   void
#-------------------------------------------------------------------------------
harden_systemd_units() {
    print_section "Durcissement des unites systemd" "R2, R15"
    
    echo -e "${WHITE}Cette fonction renforce la securite des services systemd avec:${NC}"
    echo "  - ProtectSystem=strict (systeme en lecture seule)"
    echo "  - NoNewPrivileges=yes (pas d'elevation de privileges)"
    echo "  - PrivateTmp=yes (repertoire tmp prive)"
    echo "  - CapabilityBoundingSet= (limitation des capabilities)"
    echo "  - ProtectHome=yes (protection du /home)"
    echo "  - ProtectKernelTunables=yes"
    echo "  - ProtectKernelModules=yes"
    echo ""
    
    # Detection des services
    echo -e "${WHITE}Services pouvant etre durcis:${NC}"
    local services_to_harden=()
    
    for svc in ssh sshd nginx apache2 mysql mariadb postgresql redis; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}.service"; then
            local status=$(systemctl is-enabled "$svc" 2>/dev/null || echo "?")
            echo "  - $svc ($status)"
            services_to_harden+=("$svc")
        fi
    done
    echo ""
    
    if [[ ${#services_to_harden[@]} -eq 0 ]]; then
        print_result info "Aucun service standard detecte"
        wait_continue
        return
    fi
    
    if ! ask_yes_no "Creer des overrides de durcissement pour ces services ?"; then
        log_action "SYSTEMD" "Ignore" "IGNORE"
        wait_continue
        return
    fi
    
    local hardened=0
    
    for svc in "${services_to_harden[@]}"; do
        echo ""
        if ask_yes_no "  Durcir $svc ?"; then
            local override_dir="/etc/systemd/system/${svc}.service.d"
            local override_file="${override_dir}/hardening.conf"
            
            if [[ $DRY_RUN -eq 1 ]]; then
                print_result dryrun "Creation de $override_file"
                continue
            fi
            
            mkdir -p "$override_dir"
            
            cat > "$override_file" << 'SYSTEMD_OVERRIDE'
# ANSSI Hardening - Durcissement systemd
[Service]
# Protection du systeme de fichiers
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes

# Restrictions de privileges
NoNewPrivileges=yes
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_DAC_OVERRIDE

# Protection du kernel
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectKernelLogs=yes
ProtectControlGroups=yes

# Restrictions reseau (ajuster selon le service)
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

# Restrictions systeme
RestrictRealtime=yes
RestrictSUIDSGID=yes
LockPersonality=yes
MemoryDenyWriteExecute=yes

# Espace de noms
PrivateUsers=yes
ProtectHostname=yes
ProtectClock=yes
SYSTEMD_OVERRIDE

            chmod 644 "$override_file"
            print_result ok "Override cree: $override_file"
            ((hardened++))
            log_action "SYSTEMD_$svc" "Durci" "APPLIQUE"
        fi
    done
    
    if [[ $hardened -gt 0 ]] && [[ $DRY_RUN -eq 0 ]]; then
        echo ""
        print_result info "Rechargement de systemd..."
        systemctl daemon-reload
        print_result warn "Redemarrez les services pour appliquer: systemctl restart <service>"
    fi
    
    print_result info "Services durcis: $hardened"
    wait_continue
}
