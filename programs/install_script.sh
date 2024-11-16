#!/bin/bash

log=./install_script.log

check_pack-man() {
    if command -v nala 2>&1 >/dev/null
    then
        pack_manager=nala
        pack_update="sudo $pack_manager update && sudo $pack_manager upgrade -y >> $log"
        pack_install="$pack_manager install"
    elif command -v apt 2>&1 >/dev/null
    then
        pack_manager=apt
        pack_update="sudo $pack_manager update && sudo $pack_manager upgrade -y >> $log" 
        pack_install=$pack_manager install
    elif command -v pacman 2>&1 >/dev/null
    then
        pack_manager=pacman 
        pack_update="sudo $pack_manager -Syu >> $log"
        pack_install=$pack_manager -S
    fi
}



install_bitwarden() {
    program=bitwarden
    
    if ! snap info $program | grep "installed" 2>&1 >/dev/null
    then
        echo "Installing $program" && sleep 2
        sudo snap install $program && $program & >> $log
        echo "$program installed"
    else
        echo "$program is already installed"
    fi  
}

install_nala() {
    program=nala
    if ! command -v $program 2>&1 >/dev/null 
    then
        echo "Installing $program" && sleep 2

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
        echo "Installing $program" && sleep 2
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
        echo "Installing $program" && sleep 2
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
        echo "Installing $program" && sleep 2
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
        echo "Installing $program" && sleep 2
        wget https://downloads.vivaldi.com/stable/vivaldi-stable_7.0.3495.15-1_amd64.deb && sudo dpkg -i ./*vivaldi-stable*.deb >> $log
        rm *vivaldi-stable*.deb
        echo "$program installed"
    else
        echo "$program is already installed"
    fi
}

install_everything() {
    echo "Installing all listed programs" && sleep 2
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
eval $pack_update

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
    echo "8 - exit menu"
    echo "9 - update"

    read program;
    
    case $program in
        1)install_everything && running=0;;
        2)install_bitwarden;;
        3)install_nala;;
        4)install_nfs-server;;
        5)install_private-internet-access;;
        6)install_tailscale;;
        7)install_vivaldi;;
        8)running=0;;
        9)eval $pack_update;;
        *)echo "Invalid input"
    esac
done
echo "Script exited"