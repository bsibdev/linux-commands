sudo apt update
sudo apt upgrade
sudo apt install synaptic python3 python3-venv python3-pip git
#install rocm & HIP libraries,rocminfo,and radeontop
sudo apt install libamd-comgr2 libhsa-runtime64-1 librccl1 librocalution0 librocblas0 librocfft0 librocm-smi64-1 librocsolver0 librocsparse0 rocm-device-libs-17 rocm-smi rocminfo hipcc libhiprand1 libhiprtc-builtins5 radeontop
sudo usermod -aG render,video $USER
sudo reboot