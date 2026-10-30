if [ (id -u) = 1000 ]
    if [ -f /tmp/dont-launch-tmux-next-time ]
        rm /tmp/dont-launch-tmux-next-time
    else
        if \
            exists tmux && \
                status --is-interactive && \
                [ -z $CONTAINER_ID ] && \
                not [ $TMUX ] && \
                not [ $SSH_CONNECTION ] && \
                not [ $TERMUX_VERSION ]
            exec tmux new-session fish
        end
    end
end

if [ -f ~/.config/fish/custom.fish ]
    source ~/.config/fish/custom.fish
end
