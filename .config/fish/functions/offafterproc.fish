function offafterproc
    set c 0

    while pgrep $argv >/dev/null 2>&1
        echo -n \r'Waiting '$c' seconds for'\
            $argv \(\#(count pgrep argv | wc -l)\)\
            'to finish...'
        set c (math $c + 1)
        sleep 1
    end

    echo \nPowering off soon!
    sleep 15
    poweroff
end
