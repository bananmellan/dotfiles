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
        run0 --pipe "echo -n $(wl-paste --type text/plain) | systemd-creds --user --uid=$(id -u) encrypt --with-key=host+tpm2 - $HOME/.secrets/$argv[1] && chown $USER:$USER $HOME/.secrets/$argv[1]"
    end

    # --------------------------------------------------------------------------
    # Diceware password generator
    # --------------------------------------------------------------------------
    if exists diceware
        alias diceware="diceware --no-caps -d ."
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
    # Emacs package management
    # --------------------------------------------------------------------------
    function emacs-upgrade-pkgs
        emacsclient -e '(package-upgrade-all)'
    end

    if exists flatpak
        alias fu="flatpak --user"
    end

    if exists systemctl
        if [ $USER = root ]
            alias sy="systemctl"
            alias syr="systemctl daemon-reload && systemctl restart -v"
            alias sys="systemctl daemon-reload && systemctl start -v"
            alias syo="systemctl daemon-reload && systemctl stop -v"
            alias syi="systemctl daemon-reload && systemctl stop -v"
        else
            alias sy="systemctl --user daemon-reload && systemctl --user"
            alias syr="systemctl --user daemon-reload && systemctl --user restart -v"
            alias sys="systemctl --user daemon-reload && systemctl --user start -v"
            alias syo="systemctl --user daemon-reload && systemctl --user stop -v"
            alias syi="systemctl --user daemon-reload && systemctl --user stop -v"
            alias jo="journalctl --user"
        end
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
set S sudo
if [ $container ]
    alias yabridgectl="HOME=$HOME/.local/share/yabridge-home /var/home/adam/.local/share/yabridge/yabridgectl"
else if exists systemctl && test (systemctl --version | string match -r 'systemd (\d+)' | tail -1) -ge 258
    if not [ $CONTAINER_ID ]
        alias run0="run0 --pty -i"
    end

    set S (command -v run0)
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
# Fedora Silverblue (system extensions)
# ----------------------------------------------------------------------------
else if uname -r | grep -q secureblue && exists systemd-sysext
    function __sysext_validate
        set SYSEXT $argv[1]
        if not string match -r -- '^[A-Za-z0-9._-]+$' "$SYSEXT" > /dev/null
            echo "Invalid extension name: $SYSEXT"
            return 1
        end
        return 0
    end

    function __sysext_install_script
        echo '#!/usr/bin/env bash'
        echo 'set -e'
        echo 'SYSEXT="$1"'
        echo 'TMP="$2"'
        echo 'install -d -m 0755 -o 0 -g 0 "/etc/sysupdate.$SYSEXT.d"'
        echo 'restorecon -RFv "/etc/sysupdate.$SYSEXT.d"'
        echo 'install -m 0644 -o 0 -g 0 "$TMP" "/etc/sysupdate.$SYSEXT.d/$SYSEXT.conf"'
        echo '/usr/lib/systemd/systemd-sysupdate update --component "$SYSEXT"'
        echo 'systemctl restart systemd-sysext.service'
    end

    function __sysext_remove_script
        echo '#!/usr/bin/env bash'
        echo 'set -e'
        echo 'SYSEXT="$1"'
        echo 'rm -f "/var/lib/extensions/$SYSEXT.raw"'
        echo 'rm -f /var/lib/extensions.d/"$SYSEXT"-*.raw'
        echo 'rm -f "/etc/sysupdate.$SYSEXT.d/$SYSEXT.conf"'
        echo 'rmdir "/etc/sysupdate.$SYSEXT.d/" 2>/dev/null || true'
        echo 'systemctl restart systemd-sysext.service'
    end

    function __sysext_upgrade_script
        echo '#!/usr/bin/env bash'
        echo 'set -e'
        echo 'SYSEXTS="$1"'
        echo 'COMPONENT_COUNT=$(echo "$SYSEXTS" | wc -w)'
        echo 'if [ "$COMPONENT_COUNT" -eq 0 ]; then'
        echo '    echo "No sysexts installed, nothing to do."'
        echo '    exit 0'
        echo 'fi'
        echo 'echo "Updating $COMPONENT_COUNT sysext(s): $SYSEXTS"'
        echo 'for c in $SYSEXTS; do'
        echo '    echo "=== $c ==="'
        echo '    /usr/lib/systemd/systemd-sysupdate update --component "$c"'
        echo 'done'
        echo 'systemctl restart systemd-sysext.service'
        echo '/usr/bin/systemd-sysext status || true'
    end

    function i
        set SYSEXT $argv[1]
        __sysext_validate "$SYSEXT"; or return 1
        set URL "https://extensions.fcos.fr/fedora"

        set CONF (mktemp)
        set SCRIPT (mktemp)
        if not curl --silent --fail --location "$URL/$SYSEXT.conf" -o "$CONF"
            echo "Failed to fetch $SYSEXT.conf"
            rm -f "$CONF" "$SCRIPT"
            return 1
        end
        __sysext_install_script > "$SCRIPT"

        # One run0 prompt; plain file path + two simple tokens as arguments
        run0 bash "$SCRIPT" "$SYSEXT" "$CONF"
        set STATUS $status
        rm -f "$CONF" "$SCRIPT"
        return $STATUS
    end

    function r
        set SYSEXT $argv[1]
        __sysext_validate "$SYSEXT"; or return 1

        set SCRIPT (mktemp)
        __sysext_remove_script > "$SCRIPT"
        run0 bash "$SCRIPT" "$SYSEXT"
        set STATUS $status
        rm -f "$SCRIPT"
        return $STATUS
    end

    function u
        # Enumerate installed components unprivileged
        set COMPONENTS (/usr/lib/systemd/systemd-sysupdate components --json=short \
            | jq -r '.components[]' \
            | string match -r -- '^[A-Za-z0-9._-]+$')

        if test (count $COMPONENTS) -eq 0
            echo "No sysexts installed, nothing to do."
            return 0
        end

        echo "Updating "(count $COMPONENTS)" sysext(s): "(string join ' ' -- $COMPONENTS)

        set SCRIPT (mktemp)
        __sysext_upgrade_script > "$SCRIPT"
        # Single run0 prompt for the whole upgrade run
        run0 bash "$SCRIPT" (string join ' ' -- $COMPONENTS)
        set STATUS $status
        rm -f "$SCRIPT"
        return $STATUS
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
        $S nixos-rebuild --flake '.#main' switch || return
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
