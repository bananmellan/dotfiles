function _box
    if not podman container exists $argv[1]
        distrobox assemble create --file $HEM/.config/distroboxes/$argv[1].ini
    end

    if [ "$(podman inspect box | jq .[0].State.Status)" != '"running"' ]
        podman start $argv[1] > /dev/null
    end

    if [ $argv[2] ]
        distrobox enter $argv[1] -- $argv[2..]
    else
        distrobox enter $argv[1] -- fish
    end
end
