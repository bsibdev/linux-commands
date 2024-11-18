#!/bin/bash

script_name="$(basename $0)"
log="/var/log/$script_name.log"
script_dir="$(dirname $(realpath "$0"))"
path_to_script="$(realpath "$0")"
script_storage="/usr/local/bin"
script="$script_storage/$script_name"


#save script outputs to log
$(exec > >(tee -a "$log") 2>&1)

#copy script to standard location
if [ "$script_dir" != "$script_storage" ] ; then
    sudo cp -f "$script_dir" "$script_storage"
    echo "$script_name copied to $script_storage"
fi

#launch script on boot
if ! crontab -l | grep $script > /dev/null 2>&1; then
    (crontab -l  ; echo "@reboot $script") | crontab -
fi

check_pack_man() {
    if command -v nala >/dev/null 2>&1; then
        pack_manager=nala
        pack_update=$("sudo "$pack_manager" update"; "sudo "$pack_manager" upgrade -y")
        pack_install="$pack_manager install"
    elif command -v apt >/dev/null 2>&1; then
        pack_manager=apt
        pack_update=$("sudo "$pack_manager" update"; "sudo "$pack_manager" upgrade -y")
        pack_install="$pack_manager install"
    elif command -v pacman >/dev/null 2>&1; then
        pack_manager=pacman 
        pack_update=$(sudo "$pack_manager" -Syu)
        pack_install="$pack_manager -S"
    fi
}

check_pack_man

$pack_update

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
        sudo "$pack_install" "${dependencies_to_install[@]}" -y
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
        sudo "$pack_install" "${libraries_to_install[@]}" -y
        sudo usermod -aG render,video $SUDO_USER

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
    echo "rocm install Error, no GPU found"
    fi
    
    target_dir="/home/$SUDO_USER/Comfy11I"
    comfy_repo=https://github.com/comfyanonymous/ComfyUI.git

    #clone comfy repository
    if  ! -d "$target_dir/.git"; then
        git clone "$comfy_repo" "$target_dir" 
        echo "Repository already cloned in $target_dir"
    else
        echo "Comfy repo has already been cloned"
    fi


    #create subfolder in output
    if ! -d "$target_dir/raw" > /dev/null 2>&1; then
        echo "Creating $target_dir/raw"
        mkdir -p "$target_dir/raw"
    fi

    #create virtual environment
    if ! -d "$target_dir/venv" > /dev/null 2>&1; then
        echo "Creating virtual environment."
        python3 -m venv "$target_dir/venv"
    else
        echo "Virtual environment already exists."
    fi


    #activate virtual environment
    if [[ "$VIRTUAL_ENV" != "" ]]; then
        echo "Virtual environment is active"
    else
        echo "Activating virtual environment"
        source "$target_dir/venv/bin/activate"
    fi

    if ! ls -R $target_dir/venv/lib/python3.12/site-packages | grep torch.py > /dev/null 2>&1 || ! ls -R $target_dir/venv/lib/python3.12/site-packages | grep rocm > /dev/null 2>&1; then
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2
    fi


    (pip install -r "$target_dir/requirements.txt")

}

launch_comfyui() {
    #activate virtual environment
    if [[ "$VIRTUAL_ENV" != "" ]]; then
        echo "Virtual environment is active"
    else
        echo "Activating virtual environment"
        source "$target_dir/venv/bin/activate"
    fi

    if tailscale ip | grep 100 > /dev/null 2>&1; then
        listen_ip=$(tailscale ip | grep 100)
    else
        listen_ip=$(hostname -I | awk '{print $1}')
    fi

    python "$target_dir/main.py" --listen "$listen_ip" --port 8188 --use-quad-cross-attention --output-directory "$target_dir/raw"
}
install_rocm
install_comfyui
# Change ownership of the target directory to non-root user
sudo chown -R $SUDO_USER:$SUDO_USER "$target_dir"
echo "Ownership changed to $SUDO_USER"

launch_comfyui
