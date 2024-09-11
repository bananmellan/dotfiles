if [ -z $CONTAINER_ID ]
    alias debian="_box debian"
    alias sid="_box sid"
    alias tumbleweed="_box tumbleweed"
    alias tumble=tumbleweed
    alias arch="_box arch"
    alias archlinux="arch"
    alias fedora="_box fedora"
    alias ubuntu="_box ubuntu"
    alias box="_box box"
    alias libvirt="_box libvirt"
else
    if exists __distrobox_init_$CONTAINER_ID
        if not [ -f /.INIT ]
            __distrobox_init_$CONTAINER_ID
            sudo touch /.INIT
        end
    end
end
