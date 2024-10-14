# Manual RAD README

## Install MotionEye (BULLSEYE)
```    
	# enable legacy cameras
    raspi-config nonint do_legacy 0
	
	# update apt packages
    apt update -y
	
	# install dependencies
    apt --no-install-recommends install -y ca-certificates curl python3 python3-dev libcurl4-openssl-dev gcc libssl-dev
    
	# install motioneye via pip
	python3 -m pip install --pre motioneye
	
	# Start Motioneye
    motioneye_init
    
	# Disable motion service, which may interefere with motioneye
    systemctl disable motion.service
	
	# Stop motion service, which may interefere with motioneye
    systemctl stop motion.service
	
	# Login and create Camera at http://127.0.0.1:8765"
	
```	
## Install Wireguard
```

    # update apt packages
    apt update -y
	
	# install wireguard and resolvconf
    apt install -y wireguard resolvconf
```


## Install Kismet
```
    # Install gpg key
	wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key --quiet | gpg --dearmor | sudo tee /usr/share/keyrings/kismet-archive-keyring.gpg >/dev/null
	echo 'deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/bullseye bullseye main' | sudo tee /etc/apt/sources.list.d/kismet.list >/dev/null
	
    # update apt packages
	apt update -y
	
	# install packages
	apt install -y gpsd kismet

# Edit and name the following /etc/kismet/kismet_site.conf:

#Overide File (kismet_site.conf)
#bluetooth
source=hci0:type=linuxbluetooth
#wifi
#source=wlan0:default_ht20=true:channel_hoprate=5/sec,type=linuxwifi
source=wlan1:default_ht20=true:channel_hoprate=5/sec,type=linuxwifi
#gps
gps=gpsd:host=localhost,port=2947,reconnect=true
#Update logging path
log_prefix=<absolute path to output directory>
#e.g. log_prefix=/home/pi/Documents/
log_types=kismet



# Edit the following: /etc/default/gpsd


# Start the gpsd daemon automatically at boot time
START_DAEMON="true"
# Use USB hotplugging to add new USB devices automatically to the daemon
USBAUTO="true"
# Devices gpsd should collect to at boot time.
# They need to be read/writeable, either by user gpsd or the group dialout.
DEVICES="/dev/tty<USB0>" 
# e.g DEVICES="/dev/ttyUSB0" 
# Other options you want to pass to gpsd
GPSD_OPTIONS=" "

# Run with the following:
sudo systemctl start kismet

```
## Install DDDScapy 
```
 #install scapy
    sudo pip install scapy
	
	#Pull DDDScapy repo
    git clone https://github.com/Muppetpants/DDDScapy.git
```
## Disable Bluetooth on Pi
```
# Disables bt in Pi's /boot/config.txt
	echo "dtoverlay=disable-bt" >> /boot/config.txt
```	
	
## Add Kali Repo 
```
#Install GPG key
    wget http://archive.kali.org/archive-key.asc -O /etc/apt/trusted.gpg.d/kali-archive-key.asc
    echo "deb http://http.kali.org/kali kali-last-snapshot main contrib non-free non-free-firmware" >> /etc/apt/sources.list
     
	# update apt packages
	sudo apt update
 ```
