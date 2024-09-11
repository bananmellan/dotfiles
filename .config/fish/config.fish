if exists tmux && [ -z $CONTAINER_ID ] && \
    status --is-interactive && not [ $TMUX ] && \
    not [ $SSH_CONNECTION ] && not [ $TERMUX_VERSION ]
    exec tmux new-session -n '' fish
end

if [ -f ~/.config/fish/custom.fish ]
    source ~/.config/fish/custom.fish
end

if status --is-interactive
    set TERM xterm-256color
    set EDITOR "emacsclient -t -a ''"
    set SUDO_EDITOR $EDITOR
    set VISUAL "emacsclient -c -a emacs"
    alias edit="$EDITOR"
end
