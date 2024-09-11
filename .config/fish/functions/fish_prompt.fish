function prompt_suffix
    set -l fgp (fish_git_prompt)
    # set -l ppwd (prompt_pwd --full-length-dirs 1)
    set -l ppwd (dirs)

    if [ $fgp ]
        set_color -o bryellow
        printf '%s ' $ppwd
        set_color -o magenta
        printf '%s  ' $fgp
    else
        set_color -o bryellow
        printf '%s  ' $ppwd
    end

    set_color normal

    # if [ $TMUX ]
        # tmux select-pane -T (prompt_pwd)
    # end
end

function fish_prompt
    if [ $CONTAINER_ID ]
        set_color -o magenta
        printf "📦  $CONTAINER_ID  "
    else if [ $container ]
        set_color -o magenta
        printf "📦  "
    else if [ $SSH_CONNECTION ]
        set_color yellow
        printf "💻 ssh"
        set_color normal
        printf ":"
        set_color red
        printf "$(hostname) "
        set_color normal
    else
        set_color -o bryellow
        printf '%s  ' $EMOJI
    end

    prompt_suffix
end
