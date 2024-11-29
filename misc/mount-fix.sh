#!/bin/bash

check_mount() {
    local drive="/dev/sdd2"
    local mount_point="/media/comfy/Ether"
    
    local running=1
    
    while [ $running -eq 1 ]; do
        if cd $mount_point | grep "Transport endpoint is not connected" > /dev/null 2>&1
        then
            echo "Transport endpoint is not connected"
            sudo umount -lf $mount_point
            sudo mount $drive $mount_point
        fi    
        sleep 30
    done
}

check_mount
                                                                                                                                                                                                                  