function exp
    argparse 'distro=' 'a/app' 'd/delete' -- $argv
    set -l distro $_flag_distro
    [ $distro ] || set -f distro debian

    function dbcmd -V distro
        if not [ $CONTAINER_ID ]
            distrobox-enter -n $distro -- distrobox-export $argv
        else
            distrobox-export $argv
        end
    end

    function getpath -V distro
        if not [ $CONTAINER_ID ]
            echo (string split ' ' (distrobox-enter -n $distro -- whereis $argv[1]))[2]
        else
            command -v $argv[1]
        end
    end

    for a in $argv
        if [ $_flag_app ]
            dbcmd $_flag_delete -a $a
        else
            if [ $_flag_delete ]
                set -l loc ~/.local/bin/$a
                grep -E "^# distrobox_binary\$" $loc > /dev/null 2>&1 && \
                    rm -v $loc
            else
                [ -f ~/.local/bin/$a ] && rm -v ~/.local/bin/$a

                set -l loc (getpath $a)
                if [ $loc ]
                    dbcmd -ep ~/.local/bin -b $loc
                else
                    echo $a not found.
                end
            end
        end
    end
end
