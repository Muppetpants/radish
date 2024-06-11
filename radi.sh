#!/bin/bash


clear

asciiart=$(base64 -d <<< "X19fX19fICBfX18gX19fX19fIF8gICBfX19fXyBfICAgXyANCnwgX19fIFwvIF8gXHwgIF8gIChfKSAvICBfX198IHwgfCB8DQp8IHxfLyAvIC9fXCBcIHwgfCB8XyAgXCBgLS0ufCB8X3wgfA0KfCAgICAvfCAgXyAgfCB8IHwgfCB8ICBgLS0uIFwgIF8gIHwNCnwgfFwgXHwgfCB8IHwgfC8gL3wgfF8vXF9fLyAvIHwgfCB8DQpcX3wgXF9cX3wgfF8vX19fLyB8XyhfKV9fX18vXF98IHxfLw==") 
revision="1.1"
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
    echo -e "\n Key  Menu Option:             Description:"
    echo -e " ---  ------------             ------------"
    echo -e "  1 - Add MotionEye            (Install MotionEye, disable/stop motion)"               # installMotionEye
    echo -e "  2 - Add Wireguard            (Install Wireguard client *REQUIRES REBOOT*)"           # installWireguard
    echo -e "  3 - Add Kimset               (Install Kismet and creates override file)"             # installKismet
    echo -e "  4 - Add wpa_supp. script     (Install BwithE's wpa_supplicant.conf tool)"            # installWPASupplicant
    echo -e "  5 - Add RPI AP script        (Install BwithE's Hostapd script)"                      # installRpiAp
    echo -e "  6 - Disable RPI BT radio     (Update /boot/config.txt (Breaks Kismet hci0))"         # killBluetooth
    echo -e "  7 - Install useful tools     (net-tools, nmap, arp-scan, aircrack, tshark, etc.)"    # installUseful
    echo -e "  a - Configure Wireguard      (Enable wg-quick with wg client .conf)"                 # configureWireguard
    echo -e "  h - Halp me!                 (Quick man page on what's what around here)"            # showHelp
    echo -e "  x - Exit radi.sh             (Beat it, nerd.)"                                       # Exit
    echo -e "  ! - Add all the things       (MotionEye, Wireguard, Kismet, useful tools,etc.)"      # installEverything
    echo " "
 read -n1 -p "Press key for menu item selection or press X to exit: " menuinput
case $menuinput in
        1) installMotionEye;;
        2) installWireguard;;
        3) installKismet;;
        4) installWPASupplicant;;
        5) installRpiAp;;
        6) killBluetooth;;
        7) installUseful;;
        a|A) configureWireguard;;
        h|H) showHelp;;
        x|X) echo -e "\n Exiting radi.sh - Happy Hunting! \n" ;;
        !) install_everything;;
    esac
    }
                        
function checkRoot() {
	if [ "${EUID}" -ne 0 ]; then
		echo -e "\n Radi.sh requires root privileges (e.g. sudo bash radi.sh)"
		exit 1
	fi
}

function installMotionEye() {
    clear
    distro=$(cat /etc/os-release | egrep  "PRETTY_NAME" | egrep -c bullseye) # distro check
    if [ $distro -ne 1 ]
     then echo -e "\n  Bullseye Not Detected - Please flash bullseye and retry  \n"; exit
    fi
    raspi-config nonint do_legacy 0
    apt update -y
    apt --no-install-recommends install -y ca-certificates curl python3 python3-dev libcurl4-openssl-dev gcc libssl-dev
    python3 -m pip install --pre motioneye
    motioneye_init
    sleep 3
    systemctl disable motion.service
    systemctl stop motion.service
    echo -e "\n MotionEye is running at http://127.0.0.1:8765"
}

function installWireguard() {
    clear
    # echo "nameserver 8.8.8.8" >> /etc/resolv.conf
    # echo "nameserver 8.4.4.8" >> /etc/resolv.conf
    apt update -y
    apt install -y wireguard resolvconf
    echo "nameserver 8.8.8.8" >> /etc/resolvconf/resolv.conf.d/head
    echo "nameserver 8.4.4.8" >> /etc/resolvconf/resolv.conf.d/head
    #bash /etc/resolvconf/update.d/libc
    echo -e "\n Wireguard client has been installed."
    sleep 1
    echo -e "\n Radi.sh requires a reboot becuase resolvconf is an asshole"
    read -n 1 -r -s -p $'Press any key to reboot...\n'
    reboot
}

function configureWireguard() {
    read -p "SETUP: Enter absolute path to client wg.conf: " wgConf
    thirdLine=$(sed -n '3p' "$wgConf")
    certIpAddress=$(echo "$thirdLine" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    firstThree=$(echo "$certIpAddress" | cut -d. -f1-3)
    sudo cp $wgConf /etc/wireguard/PiUser.conf

    # Enable Service
    sudo systemctl enable wg-quick@PiUser
    sudo systemctl start wg-quick@PiUser

    # Confirm connectivity
    echo -e "\n Pinging WG-Server to test connectivity"
    sleep 2
    ping -c4 $firstThree.1

}

function installKismet(){
    clear
    user=$(logname)
    mkdir /home/$user/kismetFiles 2>/dev/null
    kismet_conf="/etc/kismet/kismet_site.conf"
    gpsd_conf="/etc/default/gpsd"
    read -n1 -p "Press key to specify GPS device in use (USB0 = 1, ACM0 = 2): " gpsDev
	case $gpsDev in
        1) gpsPort=USB0;;
        2) gpsPort=ACM0;;
	esac

wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key --quiet | gpg --dearmor | sudo tee /usr/share/keyrings/kismet-archive-keyring.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/bullseye bullseye main' | sudo tee /etc/apt/sources.list.d/kismet.list >/dev/null
apt update -y
apt install -y gpsd kismet
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
log_prefix=/home/$user/kismetFiles
log_types=kismet,pcapng
EOF

cat <<EOF > "$gpsd_conf"
# Start the gpsd daemon automatically at boot time
START_DAEMON="true"
# Use USB hotplugging to add new USB devices automatically to the daemon
USBAUTO="true"
# Devices gpsd should collect to at boot time.
# They need to be read/writeable, either by user gpsd or the group dialout.
DEVICES="/dev/tty$gpsPort"
# Other options you want to pass to gpsd
GPSD_OPTIONS=""
EOF


echo -e "\n Kismet is installed. Check/edit config at $kismet_conf. Run kismet with 'sudo kismet'."
}

function installWPASupplicant(){
    clear
    wget https://raw.githubusercontent.com/Muppetpants/wpa_supplicant/main/fixMyWpaSupplicant.sh
    echo -e "\n Run script as sudo (sudo bash fixMyWpaSupplicant.sh)."
}


function installRpiAp (){
    clear
    wget https://raw.githubusercontent.com/Muppetpants/rpi-ap/main/rpi-ap.sh
    echo -e "\n Run script as sudo (sudo bash rpi-ap.sh)."
}


function killBluetooth(){
    clear
    echo "dtoverlay=disable-bt" >> /boot/config.txt
    echo -e "\n Bluetooth disabled on this Pi. To re-enable, remove/comment dtoverlay=disable-bt in /boot/config.txt." 
}

function installUseful(){
    apt install -y terminator net-tools nmap arp-scan ettercap-text-only aircrack-ng tshark steghide ftp
    echo -e "\n Installed some useful tools... "
}


function install_everything(){
    installMotionEye
    installKismet
    installWPASupplicant
    installRpiAp
    killBluetooth
    installUseful
    installWireguard
}

function showHelp(){
    clear
    echo "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
    echo "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
    echo "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
    echo "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
    read -n 1 -r -s -p $'Press any key to return to main menu.\n'
    printMenu

}

optionsHelp()
{
   # Display Help
   echo "\n\n Syntax: sudo bash radi.sh [-a|b|d|h|k|m|u|w]"
   echo "options:"
   echo "-a     Install all tools"
   echo "-b     Kill Bluetooth."
   echo "-d     Print details about tools and set-up"
   echo "-h     Print help"
   echo "-k     Install kismet"
   echo "-m     Install motioneye"
   echo "-u     Install useful tools"
   echo "-w     Install wireguard (client)"

   echo
}



# Get arguments/options
while getopts ":abdhkmuw" option; do
   case $option in
      a|A) #all the things
         install_everything
         exit;;
      b|B) # kill bt
         killBluetooth
         exit;;
      d) # blah
        showHelp
        exit;;
      h) # blah
        optionsHelp
        exit;;
      k|K) # install kismet
         installKismet
         exit;;
      m|M) # install motioneye
         installMotionEye
         exit;;
      u|U) # install useful tools
         installUseful
         exit;;
      w|W) # install wireguard
         installWireguard
         exit;;
     \?) # incorrect option
         echo "Error: Invalid option"
         optionsHelp
         exit;;
   esac
done

#Kickoff
checkRoot
printMenu

