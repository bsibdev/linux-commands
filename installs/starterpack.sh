#!/bin/bash

script_name="$(basename $0)"
log="/var/log/$script_name.log"
script_directory="$(dirname $(realpath "$0"))"
script_absolute_path="$(realpath "$0")"
standard_script_directory="/usr/local/bin"
script="$standard_script_directory/$script_name"


#save script outputs to log
$(exec > >(tee -a "$log") 2>&1)

#copy script to standard location
if [ "$script_directory" != "$standard_script_directory" ] ; then
    sudo cp -f "$script_absolute_path" "$standard_script_directory"
    echo "$script_name copied to $standard_script_directory"
fi

check_pack_man() {
    if command -v apt >/dev/null 2>&1; then
        pack_manager=apt
        pack_install="$pack_manager install"
    elif command -v pacman >/dev/null 2>&1; then
        pack_manager=pacman 
        pack_install="$pack_manager -S"
    fi
}

check_pack_man



update_packages() {
    local log_file
    local hours=12
    local time_limit=$(($hours * 60 * 60)) # hours in seconds
    local last_update
    local last_update_time
    local current_time=$(date +%s)

    pack_update() {
        case $pack_manager in
            apt)
                sudo apt update; sudo apt upgrade -y
                ;;
            pacman)
                sudo pacman -Syu
                ;;
            *)
                echo "No package manager set for $script_name"
                exit 1
        esac
    }

    case $pack_manager in
        apt)
            log_file="/var/log/apt/history.log"
            last_update=$(grep -E "Start-Date:*
             Commandline:*upgrade -y" "$log_file" | tail -1 | awk '{print $2, $3}')
            ;;
        pacman)
            log_file="/var/log/pacman.log"
            last_update=$(grep -E "\[ALPM\] upgraded" "$log_file" | tail -1 | awk '{print $1, $2}')
            ;;
        *)
            echo "No package manager set for $script_name"
            exit 1
    esac

    if [ ! -f "$log_file" ]; then
        echo "Package installer log file not found... updating now"
        pack_update
    elif [ -z "$last_update" ]; then
        echo "No last update found in log file... updating now"
        pack_update
    else
        last_update_time=$(date -d "$last_update" +%s)
        if [ $(($current_time - $last_update_time)) -ge $time_limit ]; then
            echo "Last packages upgrade is more than $hours hours old... running upgrade now"
            pack_update
        else
            echo "Packages already upgraded within the last $hours hours. Skipping"
        fi
    fi
}

update_packages


install_bitwarden() {
    program=bitwarden
    
    if ! snap info $program | grep "installed" 2>&1 >/dev/null
    then
        echo "Installing $program"
        sudo snap install $program && $program & >> $log
        echo "$program installed"
    else
        echo "$program is already installed"
    fi  
}

install_celluloid() {
    program=celluloid

    if ! command -v $program 2>&1 >/dev/null
    then
        echo "Installing $program"
        sudo $pack_manager install $program -y >> $log
        echo "$program installed"
    else
        echo "$program is already installed"
    fi
}

install_nala() {
    program=nala
    if ! command -v $program 2>&1 >/dev/null 
    then
        echo "Installing $program"

        sudo $pack_manager install $program -y >> $log
        echo "$program installed"
    else
        echo "$program is already installed"
    fi
}

install_nfs-server() {
    program=nfs-kernel-server

    if ! systemctl status nfs-server | grep "CPU" 2>&1 >/dev/null 
    then
        echo "Installing $program"
        sudo $pack_manager install $program -y >> $log
        sudo mkdir /nfs
        echo "$program installed"
    else
        echo "$program is already installed"
    fi
}

install_private-internet-access() {
    program=piavpn

    if ! sudo ls -R / | grep piavpn 2>&1 >/dev/null
    then
        echo "Installing $program"
        wget https://installers.privateinternetaccess.com/download/pia-linux-3.6.1-08339.run && chmod +x *pia-linux*.run && ./pia-linux*.run >> $log
        rm pia-linux*.run
    else
        echo "$program is already installed"
    fi
}

install_tailscale() {
    program=tailscale
    if ! command -v $program 2>&1 >/dev/null
    then
        echo "Installing $program"
        curl -fsSL https://tailscale.com/install.sh | sh >> $log
        tailscale status
    else
        echo "$program is already isntalled"
    fi
}

install_vivaldi() {
    program=vivaldi-stable


    if ! command -v $program 2>&1 >/dev/null 
    then
        echo "Installing $program"
        wget https://downloads.vivaldi.com/stable/vivaldi-stable_7.0.3495.15-1_amd64.deb && sudo dpkg -i ./*vivaldi-stable*.deb >> $log
        rm *vivaldi-stable*.deb
        echo "$program installed"
    else
        echo "$program is already installed"
    fi
}

install_everything() {
    echo "Installing all listed programs"
    install_bitwarden
    install_nala
    install_nfs-server
    install_private-internet-access
    install_tailscale
    install_vivaldi
}

change_wallpaper() {
    local wallpaper_path=./*.png

    # Check if the file exists
    if [[ -f "$wallpaper_path" ]]; then
        echo "Setting wallpaper to $wallpaper_path"
        
        # Use gsettings to change the wallpaper
        gsettings set org.gnome.desktop.background picture-uri "file://$wallpaper_path"
        gsettings set org.gnome.desktop.background picture-options "zoom"
        
        echo "Wallpaper updated successfully!"
    else
        echo "Error: File $wallpaper_path does not exist. Please provide a valid file path."
        return 1
    fi
}


check_pack-man
update_packages

echo ""

running=1

while [ $running -ne 0 ]
do   
    check_pack-man

    echo "What would you like to install?"
    echo "1 - All listed programs"
    echo "2 - Bitwarden"
    echo "3 - Nala"
    echo "4 - NFS Server"
    echo "5 - Private Internet Access"
    echo "6 - Tailscale"
    echo "7 - Vivaldi Web Browser"
    echo "8 - Rocm + ComfyUI"
    echo "9 - update"
    echo "10 - exit menu"

    read program;
    
    case $program in
        1)install_everything && running=0;;
        2)install_bitwarden;;
        3)install_nala;;
        4)install_nfs-server;;
        5)install_private-internet-access;;
        6)install_tailscale;;
        7)install_vivaldi;;
        8)./comfy-rocm.sh;;
        9)update_packages;;
        10)running=0;;
        *)echo "Invalid input"
    esac
done
echo "Script exited"