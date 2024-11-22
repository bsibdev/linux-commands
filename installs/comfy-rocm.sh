#!/bin/bash

#Install and run ComfyUI with rocm6.2 for AMD GPU on Ubuntu 24.04
#Only tested for Ubuntu 24.04; other versions and distros might be missing dependencies

if [ "$EUID" -ne 0 ]; then
    user=$USER
else
    user=$SUDO_USER
fi

target_directory="/home/$user/Comfy_oldI"
comfyui_repo=https://github.com/comfyanonymous/ComfyUI.git

script_name="$(basename $0)"
log="/var/log/$script_name.log"
script_directory="$(dirname $(realpath "$0"))"
script_absolute_path="$(realpath "$0")"
standard_script_directory="/usr/local/bin"
script="$standard_script_directory/$script_name"


#save script outputs to log
exec > >(sudo tee -a "$log") 2>&1

#copy script to standard location
if [ "$script_directory" != "$standard_script_directory" ] ; then
    sudo cp -f "$script_absolute_path" "$standard_script_directory"
    echo "$script_name copied to $standard_script_directory"
fi

#launch script on boot
if ! crontab -l | grep $script > /dev/null 2>&1; then
    (crontab -l  ; echo "@reboot $script") | crontab -
    echo "$script_name added to crontab, and will now launch on boot"
    echo "use 'crontab -e' to edit crontab"
fi

check_pack_man() {
    if command -v apt >/dev/null 2>&1; then
        pack_manager=apt
        pack_install="$pack_manager install"
    elif command -v pacman >/dev/null 2>&1; then
        pack_manager=pacman 
        pack_install="$pack_manager -S"
    else
        echo "$script_name: Package manager not found"
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
            echo "$script_name: No package manager set"
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

install_dependencies() {
    dependencies=(
        synaptic
        python3
        python3-venv
        python3-pip
        git
    )
    
    dependencies_to_install=()

    for dependency in "${dependencies[@]}"; do
        if dpkg -l | grep -q "$dependency" > /dev/null 2>&1; then
            echo "$dependency is already installed."
        else
            echo "$dependency is not installed."
            dependencies_to_install+=("$dependency")
        fi
    done

    if [ ${#dependencies_to_install[@]} -gt 0 ]; then
        sudo $pack_install ${dependencies_to_install[@]} -y
    else
        echo "All dependencies are already installed"
    fi
}

install_dependencies


# Install ROCm & HIP libraries, rocminfo, and radeontop
install_rocm() {
    required_libraries=(
        libamd-comgr2
        libhsa-runtime64-1
        librccl1
        librocalution0
        librocblas0
        librocfft0
        librocm-smi64-1
        librocsolver0
        librocsparse0
        rocm-device-libs-17
        rocm-smi
        rocminfo
        hipcc
        libhiprand1
        libhiprtc-builtins5
        radeontop
    )

    libraries_to_install=()

    for required_library in "${required_libraries[@]}"; do
        if dpkg -l | grep -q "$required_library" > /dev/null 2>&1; then
            echo "$required_library is already installed."
        else
            echo "$required_library is not installed."
            libraries_to_install+=("$required_library")
        fi
    done

    if [ ${#libraries_to_install[@]} -gt 0 ]; then
        sudo $pack_install ${libraries_to_install[@]} -y
        sudo usermod -aG render,video $user

        echo "Installation complete. The system will reboot in 30 seconds."
        for i in {30..1}; do
            echo "Rebooting in $i seconds..."
            sleep 1
        done
        sudo reboot
    else
        echo "All necessary libraries are already installed"
    fi
    
}


install_comfyui() {
    if rocminfo | grep "GPU" > /dev/null 2>&1; then
        echo "Ready to rocm 'n roll"
    else
        echo "rocm error, no GPU found"
    fi

    #clone comfy repository
    if  ! -d "$target_directory/.git"; then
        git clone "$comfyui_repo" "$target_directory" 
        echo "Repository already cloned in $target_directory"
    else
        echo "Comfy repo has already been cloned"
    fi

    #install comfy-manager
    if ! -d "$target_directory/custom_nodes/ComfyUI-Manager" > /dev/null 2>&1; then
        mkdir "$target_directory/custom_nodes/ComfyUI-Manager"
        git clone "https://github.com/ltdrdata/ComfyUI-Manager.git" "$target_directory/custom_nodes/ComfyUI-Manager"
    fi


    #create subfolder in output
    if ! -d "$target_directory/raw" > /dev/null 2>&1; then
        echo "Creating $target_directory/raw"
        mkdir -p "$target_directory/raw"
    fi

    #create virtual environment
    if ! -d "$target_directory/venv" > /dev/null 2>&1; then
        echo "Creating virtual environment."
        python3 -m venv "$target_directory/venv"
    else
        echo "Virtual environment already exists."
    fi


    #activate virtual environment
    if [[ "$VIRTUAL_ENV" != "" ]]; then
        echo "Virtual environment is already active"
    else
        echo "Activating virtual environment"
        source "$target_directory/venv/bin/activate"
    fi

    if ! ls -R $target_directory/venv/lib/python3.12/site-packages | grep torch.py > /dev/null 2>&1 || ! ls -R $target_directory/venv/lib/python3.12/site-packages | grep rocm > /dev/null 2>&1; then
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2
    fi


    (pip install -r "$target_directory/requirements.txt")

}

launch_comfyui() {
    #activate virtual environment
    if [[ "$VIRTUAL_ENV" != "" ]]; then
        echo "Virtual environment is already active"
    else
        echo "Activating virtual environment"
        source "$target_directory/venv/bin/activate"
    fi

    if tailscale status | grep 100* > /dev/null 2>&1; then
        listen_ip=$(tailscale ip | grep 100)
    else
        listen_ip=$(hostname -I | awk '{print $1}')
    fi

    python "$target_directory/main.py" --listen "$listen_ip" --port 8188 --use-quad-cross-attention --output-directory "$target_directory/raw"
}

install_rocm

install_comfyui


#set owner to non-root user
if ls -lR $target_directory | grep root > /dev/null 2>&1; then
    sudo chown -R $user:$user "$target_directory"
    echo "Ownership changed to $user"
fi
#set permissions
if find "$target_directory" ! -perm 0777 | grep . > /dev/null 2>&1; then
sudo chmod -R 0777 "$target_directory"
echo "Full permissions granted for all items in $target_directory"
fi

launch_comfyui
