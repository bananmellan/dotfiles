function vm
    quickemu --vm $argv[1] $argv[2..]
end

complete -f -c vm -a "(/usr/bin/ls ~/.VMs/*.conf)"
