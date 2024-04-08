check_distro() {
    distro=$(cat /etc/os-release | grep -i -c "PRETTY_NAME=bullseye") # distro check
    if [ $distro -ne 1 ]
     then echo -e "\n  Bullseye Not Detected - Please flash bullseye and retry  \n"; exit
    fi
}
