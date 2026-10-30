if status --is-interactive
    # if [ -d $HOME/Dokument ]
        # set CDPATH $HOME/Dokument
    # end

    set -x LANG en_US.UTF-8
    set -x LANGUAGE $LANG
    set -x LC_ALL $LANG
    if exists emacsclient && [ -S "$XDG_RUNTIME_DIR/emacs/server" ]
        # set -x EDITOR (command -v emacs)" -nw -Q -l $HOME/.emacs.d/minit.el"
        set -x EDITOR (command -v editor)
        set -x SUDO_EDITOR $EDITOR
        set -x VISUAL $EDITOR
        alias edit="$EDITOR"
        alias sedit="run0edit --editor=$EDITOR"
        alias e="edit"
        alias nano="edit"
    end

    set -x GPG_TTY (tty)

    set -a PATH /sbin \
        /usr/sbin \
    $HOME/.local/share/pnpm/bin
end
