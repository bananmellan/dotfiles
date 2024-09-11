function lock
    if [ -f /tmp/.git-sync.lock ]
        set_color green; echo Unlocking...; set_color normal
        rm /tmp/.git-sync.lock
    else
        set_color red; echo Locking...; set_color normal
        touch /tmp/.git-sync.lock
    end
end
