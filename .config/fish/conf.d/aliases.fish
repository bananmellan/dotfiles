if status --is-interactive
    # Aliases
    alias pgrep="pgrep -a"
    alias pkill="pkill -e"
    # alias mv="mv -v"
    # alias cp="cp -v"
    # alias rm="rm -v"
    alias mkdir="mkdir -v"
    alias rmdir="rmdir -v"
    abbr cdtemp "cd (mktemp -d)"
    alias trash="gio trash"
    alias docker="podman"
    alias t="exec tmux"
    alias poweroff="systemctl poweroff"
    alias reboot="systemctl reboot"
    alias grep="grep --color=always"
    alias less="less -R"
    alias python="python -q"
    alias julia="julia -q"
    # alias stow="stow --no-folding"
    if exists diceware
        alias diceware="diceware --no-caps -d ."
    end

    # function rclone
        # pass rclone/config
        # rclone $argv
    # end

    if not [ $CONTAINER_ID ] && not [ $SSH_CLIENT ]
        if exists systemd-run && not exists run0
            alias run0="systemd-run -qdt"
        end

        if exists run0
            abbr sudo run0
        end
    end

    if exists eza
        functions -e ls
        alias ls="eza -1 --color=always"
    end

    if exists bsdtar
        abbr tar bsdtar
        abbr unzip "bsdtar xvf"
    end

    function hex; python -c "print(hex($argv[1]))"; end
    function bin; python -c "print(bin($argv[1]))"; end
    function dec; python -c "print($argv[1])"; end

    # Flatpak aliases
    alias vlc="flatpak run org.videolan.VLC"
    alias firefox="flatpak run org.mozilla.firefox"
end

if exists rpm-ostree
    function i
        rpm-ostree install $argv
        # sudo rpm-ostree apply-live --allow-replacement
    end
    alias r="rpm-ostree remove"
    alias s="rpm-ostree search"
    alias u="rpm-ostree upgrade && distrobox upgrade --all && flatpak update -y"
    alias c="rpm-ostree cleanup -b -p -r -m"

    alias apt="distrobox    enter -n debian     -- sudo apt"
    alias zyp="distrobox    enter -n tumbleweed -- sudo zypper"
    alias dnf="distrobox    enter -n box        -- sudo dnf"
    alias yay="distrobox    enter -n archlinux  -- yay"
    alias pac="distrobox    enter -n archlinux  -- pacman"
    alias pacman="distrobox enter -n archlinux  -- pacman"
else if exists pkg
    alias i="pkg install"
    alias r="pkg remove"
    alias u="pkg upgrade"
    alias c="pkg clean; pkg autoclean"
else if exists nixos-rebuild && [ -z $CONTAINER_ID ]
    function u
        pushd /etc/nixos
        sudo nix flake update || return
        sudo nixos-rebuild --flake '.#bikupa' switch || return
        popd
    end
    alias c="sudo nix-collect-garbage -d && sudo nix-store --optimise"
    alias nix-shell="nix-shell --command fish"
    alias shell="nix-shell -p"

    # For nextcloud
    alias occ="sudo -u root podman exec -u 33 -it nextcloud-apache /var/www/html/occ"
else if exists nala
    alias i="sudo nala install"
    alias r="sudo nala remove"
    alias s="nala search"
    alias u="sudo nala upgrade"
    alias c="sudo nala autoremove && sudo nala autopurge"
else if exists apt
    alias i="sudo apt install"
    alias r="sudo apt remove"
    alias s="apt search"
    alias u="sudo apt update && sudo apt -yu dist-upgrade"
    alias c="sudo apt autoremove && sudo apt clean"
else if exists zypper
    alias i="sudo zypper install"
    alias r="sudo zypper remove"
    alias s="zypper search"
    alias c="sudo zypper clean"
    alias u="sudo zypper update -y"
else if exists dnf5
    alias i="sudo dnf5 install"
    alias r="sudo dnf5 remove"
    alias s="dnf5 search"
    alias c="sudo dnf5 clean all"
    alias u="sudo dnf5 upgrade --refresh"
else if exists dnf
    alias i="sudo dnf install"
    alias r="sudo dnf remove"
    alias s="dnf search"
    alias c="sudo dnf clean all"
    alias u="sudo dnf upgrade --refresh"
else if exists pacman
    alias i="sudo pacman -Sy"
    alias r="sudo pacman -Rs"
    alias s="pacman -Ss"
    alias c="sudo pacman -Scc"
    alias u="sudo pacman -Syu"
else if exists xbps-install
    alias i="sudo xbps-install"
    alias r="sudo xbps-remove"
    alias s="xbps-query -Rs"
    alias u="sudo xbps-install -Suy"
end
