if status --is-interactive
    # ==========================================================================
    # Interactive shell configuration
    # ==========================================================================

    # --------------------------------------------------------------------------
    # Command aliases for enhanced productivity
    # --------------------------------------------------------------------------
    alias pgrep="pgrep -a"
    alias pkill="pkill -e"
    # alias mv="mv -v"
    # alias cp="cp -v"
    # alias rm="rm -v"
    alias mkdir="mkdir -v"
    alias rmdir="rmdir -v"

    # --------------------------------------------------------------------------
    # Directory operations
    # --------------------------------------------------------------------------
    abbr cdtemp "cd (mktemp -d)"

    # --------------------------------------------------------------------------
    # Network utilities
    # --------------------------------------------------------------------------
    alias getip="wget -qO- icanhazip.com 2>/dev/null"

    # --------------------------------------------------------------------------
    # File management
    # --------------------------------------------------------------------------
    alias trash="gio trash"

    # --------------------------------------------------------------------------
    # Container runtime selection
    # --------------------------------------------------------------------------
    if not exists docker and exists podman
        alias docker="podman"
    end

    # --------------------------------------------------------------------------
    # Terminal multiplexer
    # --------------------------------------------------------------------------
    alias t="exec tmux"

    # --------------------------------------------------------------------------
    # System control
    # --------------------------------------------------------------------------
    alias poweroff="systemctl poweroff"

    # --------------------------------------------------------------------------
    # File viewing
    # --------------------------------------------------------------------------
    alias less="less -R"

    # --------------------------------------------------------------------------
    # GNOME terminal opacity control
    # --------------------------------------------------------------------------
    alias opacity="dconf write /org/gnome/Ptyxis/Profiles/(dconf read /org/gnome/Ptyxis/default-profile-uuid|string trim -c\')/opacity"

    # --------------------------------------------------------------------------
    # QEMU virtualization
    # --------------------------------------------------------------------------
    alias qemu="qemu-system-x86_64"

    # --------------------------------------------------------------------------
    # System logs
    # --------------------------------------------------------------------------
    alias logs="journalctl -eu"

    # --------------------------------------------------------------------------
    # Julia REPL configuration
    # --------------------------------------------------------------------------
    exists julia && alias julia="julia -q"

    # --------------------------------------------------------------------------
    # Bookmark manager
    # --------------------------------------------------------------------------
    alias b="buku --deep"

    # --------------------------------------------------------------------------
    # Secret management
    # --------------------------------------------------------------------------
    function hemlis
        wl-paste | \
            run0 --pipe sh -c "systemd-creds encrypt --user --uid=$(id -u) --with-key=host+tpm2 - $HOME/.secrets/$argv[1] && chown $USER:$USER $HOME/.secrets/$argv[1]"
    end

    # --------------------------------------------------------------------------
    # Diceware password generator
    # --------------------------------------------------------------------------
    if exists diceware
        alias diceware="diceware --no-caps -d ."
    end

    # --------------------------------------------------------------------------
    # Privilege escalation tools
    # --------------------------------------------------------------------------
    if not [ $CONTAINER_ID ] && not [ $SSH_CLIENT ]
        alias run0="run0 --pty"
    end

    # --------------------------------------------------------------------------
    # Modern ls alternatives
    # --------------------------------------------------------------------------
    if exists eza
        functions -e ls
        function ls
            eza -l \
                --color=always \
                --time-style '+%Y-%m-%d %H:%M' \
                --icons=auto \
                --mounts \
                --git \
                --no-permissions \
                --no-time \
                --no-user \
                $argv
        end
        function lsl
            eza -l \
                --color=always \
                --time-style '+%Y-%m-%d %H:%M' \
                --icons=auto \
                --mounts \
                --git \
                -a \
                $argv
        end
    else if exists exa
        functions -e ls
        alias ls="exa -1 --color=always"
    end

    # --------------------------------------------------------------------------
    # Archive utilities
    # --------------------------------------------------------------------------
    if exists bsdtar
        abbr tar bsdtar
        abbr unzip "bsdtar xvf"
    end

    # --------------------------------------------------------------------------
    # Number base conversion utilities
    # --------------------------------------------------------------------------
    function hex; python -c "print(hex($argv[1]))"; end
    function bin; python -c "print(bin($argv[1]))"; end
    function dec; python -c "print($argv[1])"; end

    # --------------------------------------------------------------------------
    # Portage configuration synchronization
    # --------------------------------------------------------------------------
    function sync_portage_stuff
        set basepath $argv[1]
        function RSYNC -V basepath
            set p $basepath$argv
            run0 rsync --delete -av 10.82.77.1:$p (dirname $argv)
        end

        RSYNC /etc/portage/package.use
        RSYNC /etc/portage/package.accept_keywords
        RSYNC /etc/portage/package.mask
        RSYNC /etc/portage/make.conf
        RSYNC /etc/portage/repos.conf

        RSYNC /var/lib/portage/world
        # RSYNC /var/lib/portage/world_sets
    end

    # --------------------------------------------------------------------------
    # Emacs package management
    # --------------------------------------------------------------------------
    function emacs-upgrade-pkgs
        emacsclient -e '(package-upgrade-all)'
    end
end

# ============================================================================
# Package manager aliases by distribution
# ============================================================================

# ----------------------------------------------------------------------------
# Emacs package upgrade
# ----------------------------------------------------------------------------
if exists emacs
    alias eu="emacs -batch -l ~/.emacs.d/init.el -f package-upgrade-all"
end

# ----------------------------------------------------------------------------
# Privilege escalation selection
# ----------------------------------------------------------------------------
if [ $container ]
    set S sudo
    alias yabridgectl="HOME=$HOME/.local/share/yabridge-home /var/home/adam/.local/share/yabridge/yabridgectl"
else
    set S run0
end

# ----------------------------------------------------------------------------
# Termux (Android) package management
# ----------------------------------------------------------------------------
if [ $TERMUX_VERSION ]
    set PKGM apt

    alias i="$PKGM install"
    alias r="$PKGM remove"
    alias s="apt search"
    function u
        sh -c "$PKGM update && $PKGM -u dist-upgrade"
    end
    alias c="sh -c \"$PKGM autoremove && $PKGM clean && $PKGM purge '~c'\""
# ----------------------------------------------------------------------------
# Debian/Ubuntu based systems
# ----------------------------------------------------------------------------
else if exists apt
    set PKGM apt

    alias i="$S $PKGM install"
    alias r="$S $PKGM remove"
    alias s="apt search"
    function u
        $S sh -c "$PKGM update && $PKGM -u dist-upgrade"
    end
    alias c="$S sh -c \"$PKGM autoremove && $PKGM clean && $PKGM purge '~c'\""
# ----------------------------------------------------------------------------
# Arch Linux based systems
# ----------------------------------------------------------------------------
else if exists pacman
    alias i="$S pacman -Sy"
    alias r="$S pacman -Rs"
    alias s="pacman -Ss"
    alias c="$S pacman -Scc --noconfirm"
    alias u="$S pacman -Syu"
# ----------------------------------------------------------------------------
# Gentoo Linux
# ----------------------------------------------------------------------------
else if exists emerge
    alias i="$S emerge --ask --autounmask --buildpkg --getbinpkg"
    alias r="$S emerge --unmerge"
    alias s="emerge --search"
    alias u="$S emaint --auto sync && $S emerge --buildpkg --ask --verbose --update --deep --newuse --getbinpkg @world"
    alias c="$S emerge --ask --depclean"
# ----------------------------------------------------------------------------
# FreeBSD
# ----------------------------------------------------------------------------
else if exists pkg
    alias i="pkg install"
    alias r="pkg remove"
    alias u="pkg upgrade"
    alias c="pkg clean; pkg autoclean"
# ----------------------------------------------------------------------------
# Fedora Silverblue (system extensions)
# ----------------------------------------------------------------------------
else if exists systemd-sysext
    function i
        set SYSEXT $argv[1]
        set URL "https://extensions.fcos.fr/fedora"
        install -d -m 0755 -o 0 -g 0 "/etc/sysupdate.$SYSEXT.d"
        restorecon -RFv "/etc/sysupdate.$SYSEXT.d"
        curl --silent --fail --location "$URL/$SYSEXT.conf" \
            | tee "/etc/sysupdate.$SYSEXT.d/$SYSEXT.conf"
        /usr/lib/systemd/systemd-sysupdate update --component "$SYSEXT"
        systemctl restart systemd-sysext.service
    end

    function r
        set SYSEXT $argv[1]
        rm "/var/lib/extensions/$SYSEXT.raw"
        rm "/var/lib/extensions.d/$SYSEXT-"*".raw"
        rm "/etc/sysupdate.$SYSEXT.d/$SYSEXT.conf"
        rmdir "/etc/sysupdate.$SYSEXT.d/"
        systemctl restart systemd-sysext.service
    end

    function s
        if test (count $argv) -eq 0
            echo "Usage: sysext-search <search term>"
            return 1
        end

        curl -fsSL https://api.github.com/repos/fedora-sysexts/fedora/contents/ \
            | jq -r '.[] | select(.type == "dir") | .name' \
            | string match -i -- "*"(string join ' ' -- $argv)"*"
    end
# ----------------------------------------------------------------------------
# Fedora Silverblue (rpm-ostree)
# ----------------------------------------------------------------------------
else if exists rpm-ostree
    function i
        rpm-ostree install $argv
        # $S rpm-ostree apply-live --allow-replacement
    end
    alias r="rpm-ostree remove"
    alias s="rpm-ostree search"
    alias u="rpm-ostree upgrade && distrobox upgrade --all && flatpak update -y"
    alias c="rpm-ostree cleanup -b -p -r -m"

    alias apt="distrobox    enter -n debian     -- $S apt"
    alias zyp="distrobox    enter -n tumbleweed -- $S zypper"
    alias dnf="distrobox    enter -n box        -- $S dnf"
    alias yay="distrobox    enter -n archlinux  -- yay"
    alias pac="distrobox    enter -n archlinux  -- pacman"
    alias pacman="distrobox enter -n archlinux  -- pacman"
# ----------------------------------------------------------------------------
# NixOS
# ----------------------------------------------------------------------------
else if exists nixos-rebuild && [ -z $CONTAINER_ID ]
    function u
        pushd /etc/nixos
        $S nix flake update || return
        $S nixos-rebuild --flake '.#bikupa' switch || return
        popd
    end
    alias c="$S nix-collect-garbage -d && $S nix-store --optimise"
    alias nix-shell="nix-shell --command fish"
    alias shell="nix-shell -p"

    # For nextcloud
    alias occ="$S -u root podman exec -u 33 -it nextcloud-apache /var/www/html/occ"
# ----------------------------------------------------------------------------
# Debian/Ubuntu with nala
# ----------------------------------------------------------------------------
else if exists nala
    alias i="$S nala install"
    alias r="$S nala remove"
    alias s="nala search"
    alias u="$S nala upgrade"
    alias c="$S nala autoremove && $S nala autopurge"
# ----------------------------------------------------------------------------
# openSUSE
# ----------------------------------------------------------------------------
else if exists zypper
    alias i="$S zypper install"
    alias r="$S zypper remove"
    alias s="zypper search"
    alias c="$S zypper clean"
    alias u="$S zypper update -y"
# ----------------------------------------------------------------------------
# Fedora (dnf5)
# ----------------------------------------------------------------------------
else if exists dnf5
    alias i="$S dnf5 install"
    alias r="$S dnf5 remove"
    alias s="dnf5 search"
    alias c="$S dnf5 clean all"
    alias u="$S dnf5 upgrade --refresh"
# ----------------------------------------------------------------------------
# Fedora (dnf)
# ----------------------------------------------------------------------------
else if exists dnf
    alias i="$S dnf install"
    alias r="$S dnf remove"
    alias s="dnf search"
    alias c="$S dnf clean all"
    alias u="$S dnf upgrade --refresh"
# ----------------------------------------------------------------------------
# Void Linux
# ----------------------------------------------------------------------------
else if exists xbps-install
    alias i="$S xbps-install"
    alias r="$S xbps-remove"
    alias s="xbps-query -Rs"
    alias u="$S xbps-install -Suy"
end
