#!/bin/bash

clear
asciiart=$(base64 -d <<< "X19fX19fICBfX18gX19fX19fIF8gICBfX19fXyBfICAgXyANCnwgX19fIFwvIF8gXHwgIF8gIChfKSAvICBfX198IHwgfCB8DQp8IHxfLyAvIC9fXCBcIHwgfCB8XyAgXCBgLS0ufCB8X3wgfA0KfCAgICAvfCAgXyAgfCB8IHwgfCB8ICBgLS0uIFwgIF8gIHwNCnwgfFwgXHwgfCB8IHwgfC8gL3wgfF8vXF9fLyAvIHwgfCB8DQpcX3wgXF9cX3wgfF8vX19fLyB8XyhfKV9fX18vXF98IHxfLw==") 
revision="2.0"
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
    echo "Your one-stop shop for rad RADD builds." 
    echo -e "\n    Select an option from menu:             Rev: $revision Arch: $arch"
    echo -e "\n Key  Menu Option:             Description:"
    echo -e " ---  ------------             ------------"
    echo -e "  1 - Add MotionEye            (Install MotionEye, disable/stop motion)"               # installMotionEye
    echo -e "  2 - Add Wireguard            (Install Wireguard client *REQUIRES REBOOT*)"           # installWireguard
    echo -e "  3 - Add Kismet               (Install Kismet and creates override file)"             # installKismet
    echo -e "  4 - Add wpa_supp. script     (Install BwithE's wpa_supplicant.conf tool)"            # installWPASupplicant
    echo -e "  5 - Add DDDScapy             (Install probe stuffing python script)"                 # installDDD
    echo -e "  6 - Disable RPI BT radio     (CAUTION! Update /boot/config.txt (Breaks Kismet))"     # killBluetooth
    echo -e "  7 - Install useful tools     (net-tools, nmap, arp-scan, aircrack, tshark, etc.)"    # installUseful
    echo -e "  8 - Install hotspot cron     (Creates break-glass access to Pi via hotspot)"         # installHotspot
    echo -e "  a - Configure Wireguard      (Enable wg-quick with wg client .conf)"                 # configureWireguard
    echo -e "  h - Halp me!                 (Quick man page on what's what around here)"            # showDetails
    echo -e "  x - Exit radi.sh             (Beat it, nerd.)"                                       # Exit
    echo -e "  ! - Add all the things       (CAUTION! MotionEye, Wireguard, Kismet, etc...)"        # installEverything
    echo " "
 read -n1 -p "Press key for menu item selection or press X to exit: " menuinput
case $menuinput in
        1) installMotionEye;;
        2) installWireguard;;
        3) installKismet;;
        4) installWPASupplicant;;
        5) installDDD;;
        6) killBluetooth;;
        7) installUseful;;
        8) installHotspot;;
        a|A) configureWireguard;;
        h|H) showDetails;;
        x|X) echo -e "\n Exiting radi.sh - Happy Hunting! \n" ;;
        !) install_everything;;
    esac
    }
                        
function checkRoot() {
	if [ "${EUID}" -ne 0 ]; then
		echo -e "\n radi.sh requires root privileges (e.g. sudo bash radi.sh)"
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
    apt update -y
    apt install -y wireguard resolvconf
    echo "nameserver 8.8.8.8" >> /etc/resolvconf/resolv.conf.d/head
    echo "nameserver 8.4.4.8" >> /etc/resolvconf/resolv.conf.d/head
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
gps=gpsd:host=localhost,port=2947,reconnect=true
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
GPSD_OPTIONS="-n -b"
EOF


echo -e "\n Kismet is installed. Check/edit config at $kismet_conf. Run kismet with 'sudo kismet'."
}

function installWPASupplicant(){
    clear
    wget https://raw.githubusercontent.com/Muppetpants/wpa_supplicant/main/fixMyWpaSupplicant.sh
    echo -e "\n Run script as sudo (sudo bash fixMyWpaSupplicant.sh)."
}


function installDDD (){
    clear
    git clone https://github.com/Muppetpants/DDDScapy.git
    echo -e "\n cd into DDDScapy and read the README.md."
}


function killBluetooth(){
    clear
    echo "dtoverlay=disable-bt" >> /boot/config.txt
    echo -e "\n Bluetooth disabled on this Pi. To re-enable, remove/comment dtoverlay=disable-bt in /boot/config.txt." 
}

function installUseful(){
    apt install -y terminator net-tools nmap arp-scan ettercap-text-only aircrack-ng tshark steghide ftp wireshark-common
    sudo chmod a+x /usr/bin/dumpcap
    echo -e "\n Installed some useful tools... "
}

function installHotspot(){
    clear
    echo "This script will check for network connectivity to a previously trusted WLAN two minutes after reboot. If the RADD has not established a connection with a previously trusted network, the RADD will start a WLAN hotspot to allow direct access at 10.42.0.1."
    echo " " 
    read -p "Hotspot SSID: " ssid
    while true; do
        read -s -p "Passphrase (8+): " passphrase
        echo
        read -s -p "Passphrase (8+) (again): " passphrase2
        echo
        [ "$passphrase" = "$passphrase2" ] && break
        echo "Please try again"
    done

    #Create script to run at reboot
    echo "#!/bin/bash" > hotspotJob.sh
    echo "/usr/bin/systemctl start NetworkManager" >> hotspotJob.sh
    echo "sleep 5" >> hotspotJob.sh
    echo "/usr/bin/nmcli d show wlan0 | grep disconnected" >> hotspotJob.sh
    echo "if [ \$? -eq 0 ]; then" >> hotspotJob.sh
    echo -e " \t /usr/bin/nmcli d wifi hotspot ifname wlan0 ssid $ssid password $passphrase" >> hotspotJob.sh
    echo "fi" >> hotspotJob.sh
    chmod 0600 hotspotJob.sh

    #Create cron entry
    rm /etc/cron.d/hotspot 2>/dev/null
    filePath=$(pwd)
    echo "@reboot root sleep 120; bash $filePath/hotspotJob.sh" > /etc/cron.d/hotspot
    chmod 0644 /etc/cron.d/hotspot
    
}


function install_everything(){
    installMotionEye
    installKismet
    installWPASupplicant
    installRpiAp
    killBluetooth
    installUseful
    installHotspot
    installWireguard
}

function showDetails(){
    clear
    echo -e "\n 1 - Add MotionEye: This option checks for bullseye before running and then installs and enables Motioneye as as a service which can be reached at port 8765. Standard camera set-up is still required (add camera, update conf, etc.) This options also disables motion.service which interferes with the motioneye service."
    echo -e "\n 2 - Add Wireguard: This options installs the wireguard client and resolvconf. This option does nothing to configure individual wireguard certificates."
    echo -e "\n 3 - Add Kimset: This option installs and configures GPSD, installs kismet, and creates an intial kismet override file (/etc/kismet_site.conf). The override file specifies an output directory in the user's home, and enables WLAN on wlan1. Default outputs include .kismet and .pcapng. BT can be enabled by uncommenting the "source=hci0" line within the override file."
    echo -e "\n 4"
    echo -e "\n 5 - This tool facilitates digital dead drops by stuffing the contents of file.txt into crafted probe request packets. By default, sends 10x packets for each line of text in file.txt"
    echo -e "\n 6 - Disable RPI BT radio: This option disables the BT radio. Can be useful for leave-behind devices but will break hci0 collection in kismet (disabled by default). To re-enable this, open /boot/config.txt and remove or comment the line "dtoverlay=disable-bt"."
    echo -e "\n 7 - Install useful tools: This option installs terminator, net-tools, nmap, arp-scan, ettercap-text-only, aircrack-ng, tshark, steghide, and ftp client."
    echo -e "\n 8 - Install hotspot cron: This option is intended to create a method to access the RADD when it does not establish other WLAN connectivity. This option asks for user input for SSID and passphrase (special characters should be avoided). and then builds a script in the working directory and a cron job called /etc/cron.d/hotspot This can be useful for set-up and testing, but should be disabled (move or remove the cron file or script) prior to sending a RADD into the wild."
    echo -e "\n a - Configure Wireguard: This option requires a valid wireguard client conf file. It renames and moves the conf to /etc/wireguard/PiUser and then starts and enables the wireguard service for PiUser. "
    echo -e "\n ! - Install everything. CAUTION!"

    read -n 1 -r -s -p $'Press any key to return to main menu.\n'
    printMenu

}

optionsHelp()
{
   # Display help in CLI
   echo -e "\n Syntax: sudo bash radi.sh [-a|b|d|h|k|m|u|w]"
   echo "options:"
   echo "-a     Install all tools"
   echo "-b     Kill Bluetooth"
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
        showDetails
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

