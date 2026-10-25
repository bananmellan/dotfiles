#!/usr/bin/env fish

function __find_possible_venv
    for d in $argv[2..]
        if [ -d $argv[1]/$d ]
            echo $argv[1]/$d
            return 0
        end
    end

    return 1
end

function __find_venv
    set POSSIBLE_DIRS build_dir/venv venv .venv
    set BASE_DIRS $PWD

    if git rev-parse --is-inside-work-tree > /dev/null 2>&1
        set REPODIR (git rev-parse --show-toplevel)
        if [ $REPODIR != $PWD ]
            set -a BASE_DIRS $REPODIR
        end
    end

    set -a BASE_DIRS ..

    for base_dir in $BASE_DIRS
        set VENVDIR (__find_possible_venv $base_dir $POSSIBLE_DIRS)
        if [ $VENVDIR ]
            echo $VENVDIR
            return 0
        end
    end

    return 1
end

function venv
    argparse -i 'd/dir=' -- $argv

    if not [ $_flag_dir ]
        set VENVDIR (__find_venv)

        if not [ $VENVDIR ]
            echo No venv found

            if [ (count $argv) -eq 0 ]
                if not [ -d .venv ]
                    virtualenv .venv
                    echo;echo Created virtualenv at .venv 🐍
                else
                    echo Virtualenv .venv already created
                end

                return 0
            end

            return 1
        end
    else
        set VENVDIR $_flag_dir
    end

    if [ (count $argv) -gt 0 ]
        $VENVDIR/bin/$argv[1] $argv[2..]
    end
end

complete -c venv -f -n '__fish_is_first_arg' \
    -a '(for f in (__find_venv)/bin/*; echo (basename $f); end)'
