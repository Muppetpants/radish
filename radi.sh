#!/bin/bash
clear

asciiart=$(base64 -d <<< "X19fX19fICBfX18gX19fX19fIF8gICBfX19fXyBfICAgXyANCnwgX19fIFwvIF8gXHwgIF8gIChfKSAvICBfX198IHwgfCB8DQp8IHxfLyAvIC9fXCBcIHwgfCB8XyAgXCBgLS0ufCB8X3wgfA0KfCAgICAvfCAgXyAgfCB8IHwgfCB8ICBgLS0uIFwgIF8gIHwNCnwgfFwgXHwgfCB8IHwgfC8gL3wgfF8vXF9fLyAvIHwgfCB8DQpcX3wgXF9cX3wgfF8vX19fLyB8XyhfKV9fX18vXF98IHxfLw==") 
revision="1.0"
archtype=$(uname -m)
    if [ "$archtype" == "aarch64" ]; 
      then 
        arch="arm64"
    fi

    if [ "$archtype" == "x86_64" ]; 
      then
        arch="amd64"
    fi

function printMenu(){
    clear
    echo -e "$asciiart"
    echo "Your one-stop shop for rad RAD builds." 
    echo -e "\n    Select an option from menu:             Rev: $revision Arch: $arch"
#   echo -e "\n  Menu Options:"                                                                    # function call list
    echo -e "\n Key  Menu Option:             Description:"
    echo -e " ---  ------------             ------------"
    echo -e "  1 - Add MotionEye            (Install MotionEye, disable/stop motion)"               # installMotionEye
    echo -e "  2 - Add Wireguard            (Install and set-up wg with User's conf)"               # installWireguard
    echo -e "  3 - Add Kimset               (Install Kismet and creates override file)"             # installKismet
    echo -e "  4 - Add wpa_supp. script     (NOT READY! Create wpa_supplicant.conf builder)"                   # installWPASupplicant
    echo -e "  5 - Add Else                 (ABC)"     
    echo -e "  x - Exit radi.sh             (Scram!)"                                               # Exit
    echo -e "  ! - Add all the things       (MotionEye, Wireguard, Kismet, etc.)"                   # installEverything
 
 read -n1 -p "  Press key for menu item selection or press X to exit: " menuinput
case $menuinput in
        1) installMotionEye;;
        2) installWireguard;;
        3) installKismet;;
        4) installWPASupplicant;;
        5) TBD2;;
        x|X) echo -e "\n\n Exiting radi.sh - Happy Hunting! \n" ;;
        !) install_everything;;
    esac
    }
                                   



function checkRoot() {
	if [ "${EUID}" -ne 0 ]; then
		echo "You need to run this script as root"
		exit 1
	fi
}

function installMotionEye() {
    clear
    distro=$(cat /etc/os-release | egrep  "PRETTY_NAME" | egrep -c bullseye) # distro check
    if [ $distro -ne 1 ]
     then echo -e "\n  Bullseye Not Detected - Please flash bullseye and retry  \n"; exit
    fi

    apt update -y
    apt install python3-dev libcurl4-openssl-dev libssl-dev python3-pip
    pip3 install https://github.com/motioneye-project/motioneye/archive/dev.tar.gz
    motioneye_init
    systemctl disable motion.service
    systemctl stop motion.service
    echo ""
    echo "MotionEye is running at http://127.0.0.1:8765"
}

function installWireguard() {
    clear
    apt update -y
    apt install wireguard resolvconf
echo ""
echo "Wireguard client has been installed."

}

function installKismet(){
    # Asking user input for name, to declare variable
    clear
    user=$(logname)
    mkdir /home/$user/kismetFiles
    kismet_conf="/etc/kismet/kismet_site.conf"

wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key --quiet | gpg --dearmor | sudo tee /usr/share/keyrings/kismet-archive-keyring.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/bullseye bullseye main' | sudo tee /etc/apt/sources.list.d/kismet.list >/dev/null
apt update -y
apt install gpsd kismet -y
clear

# Create the following config file for kismet
cat <<EOF > "$kismet_conf"
#Overide File (kismet_site.conf)
#bluetooth
#source=hci0:type=linuxbluetooth
#wifi
#source=wlan0:default_ht20=true:channel_hoprate=5/sec,type=linuxwifi
source=wlan1:default_ht20=true:channel_hoprate=5/sec,type=linuxwifi
#gps
gps=gpsd:host=localhost,port=2947
#Update logging path
log_prefix=/home/$user/kismet
log_types=kismet,pcapng
EOF
echo ""
echo "Kismet is installed. Check/edit config at $kismet_conf. Run kismet with 'sudo kismet'. "
}

function installWPASupplicant(){
cat <<EOF > "fixMyWpaSupplicant.sh"

conf="wpa_supplicant.conf"

read -p "Network SSID: " ssid
read -p "Network passphrase: " passphrase

echo "Killing previous WPA_SUPPLICANT processes."
# Get the list of process IDs
pids=$(ps aux | grep wpa | grep -v grep | awk '{print $2}')
# Loop through the process IDs and kill them
for pid in $pids; do
    sudo kill -9 $pid
    echo "Killed process with ID: $pid"
done
clear

# Runs the wpa_passphrase command to build a conf file
echo "Building conf file"
echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev" > $conf
echo "update_config=1" >> $conf
echo "country=US" >> $conf
wpa_passphrase "$ssid" "$passphrase" >> $conf
clear

echo "Moving conf file"
sudo mv $conf /etc/wpa_supplicant/
EOF
}



function install_everything(){
    installMotionEye
    installWireguard
    installKismet
}

#Kickoff
checkRoot
printMenu

