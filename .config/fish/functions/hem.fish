function hem
    pushd $HEM

    switch $argv[1]
        case stow
            stow --no-folding $argv[2..] .

            if [ -d $HEM.crypt ]
                pushd $HEM.crypt
                stow $argv[2..] .
                popd
            end
        case pull
            git pull
    end

    popd
end
