function devbox
    argparse -i 'n/name=' 's/run0' 'e/extra-args=' -- $argv
    set -l NAME $_flag_name
    if [ "$_flag_run0" ]
        set RUN0 run0
    end

    set -l PODCMD $RUN0 podman
    set -l CONCMD $PODCMD exec $_flag_extra_args --detach-keys="" -it $NAME

    if $PODCMD container inspect $NAME | jq .[0].State.Running \
        | grep false > /dev/null 2>&1
        $PODCMD start $NAME > /dev/null 2>&1
    end

    $CONCMD sh -c "cd $PWD && $argv"
end
