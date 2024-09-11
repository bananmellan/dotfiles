function devbox
    argparse -i 'n/name=' 's/sudo' 'e/extra-args=' -- $argv
    set -l NAME $_flag_name
    if [ "$_flag_sudo" ]
        set SUDO sudo
    end

    set -l PODCMD $SUDO podman
    set -l CONCMD $PODCMD exec $_flag_extra_args --detach-keys="" -it $NAME

    if $PODCMD container inspect $NAME | jq .[0].State.Running \
        | grep false > /dev/null 2>&1
        $PODCMD start $NAME > /dev/null 2>&1
    end

    $CONCMD sh -c "cd $PWD && $argv"
end
