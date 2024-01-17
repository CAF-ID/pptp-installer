#!/bin/bash



#CONFiG
nama_paket="pptpd"
max_attempts=5
log_file="install_log.txt"
this_file=$(realpath "$0")
destination_path="/etc/run.sh"
STORE_IP=""

ENV_FILE="/etc/.env"

create_env_file() {
    echo 'STORE_IP=""' > "$ENV_FILE"
}
read_env_file() {
    source "$ENV_FILE"
}
if [ ! -f "$ENV_FILE" ]; then
    echo "File $ENV_FILE tidak ditemukan. Membuat file baru..."
    create_env_file
else
    echo "Membaca konfigurasi dari file $ENV_FILE..."
    read_env_file
fi

# ANSI escape codes for colors
ORANGE='\033[38;2;252;61;3m'
CYAN='\033[0;36m'
GREENISH='\033[38;2;3;252;148m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color


clear

while true; do
    echo -e "${RED}[CAF PPTPD]${NC}"
    echo -e "Pilih opsi action:"
    echo -e "${GREEN}1.${NC} ${BLUE}Setup PPTPD${NC}"
    echo -e "${GREEN}2.${NC} ${BLUE}Run PPTPD${NC}"
    echo -e "${GREEN}3.${NC} ${BLUE}iptables Settings${NC}"
    echo -e "${GREEN}4.${NC} ${BLUE}Create Account${NC}"
	echo -e "${GREEN}0.${NC} ${BLUE}Exit${NC}"
    read -p "Masukkan pilihan (0-4): " pilihan
    case $pilihan in
	  0)
	  exit 0
	  break
	  ;;
      1)
        echo "Setting Up PPTPD"
        # Cek repo dulu rek
        if grep -Fxq "deb http://kartolo.sby.datautama.net.id/debian/ buster main contrib non-free" /etc/apt/sources.list; then
			echo -e "Repository (${GREEN}1${NC}) sudah ada, tidak perlu ditambahkan."
        else
		  	echo -e "Menambahkan Repository (${GREEN}1${NC})"
          	echo "deb http://kartolo.sby.datautama.net.id/debian/ buster main contrib non-free" >> /etc/apt/sources.list
        fi

        if grep -Fxq "deb http://kartolo.sby.datautama.net.id/debian/ buster-updates main contrib non-free" /etc/apt/sources.list; then
			echo -e "Repository (${GREEN}2${NC}) sudah ada, tidak perlu ditambahkan."
        else
			echo -e "Menambahkan Repository (${GREEN}2${NC})"
          	echo "deb http://kartolo.sby.datautama.net.id/debian/ buster-updates main contrib non-free" >> /etc/apt/sources.list
        fi

        if grep -Fxq "deb http://kartolo.sby.datautama.net.id/debian-security/ buster/updates main contrib non-free" /etc/apt/sources.list; then
			echo -e "Repository (${GREEN}3${NC}) sudah ada, tidak perlu ditambahkan."
        else
          	echo -e "Menambahkan Repository (${GREEN}3${NC})"
          	echo "deb http://kartolo.sby.datautama.net.id/debian-security/ buster/updates main contrib non-free" >> /etc/apt/sources.list
        fi
        sleep 2
        echo -e "${RED}[- DONE -]${NC}"
        sleep 2
		echo -e "${GREEN}Updating Repository...${NC}"
		apt update >/dev/null 2>&1
		echo -e "${RED}[- DONE -]${NC}"
        sleep 2
		for attempt in $(seq $max_attempts); do
            echo -e "${GREEN}Installing PPTPD package...($attempt)${NC}"
            apt-get install -y $nama_paket neofetch > $log_file 2>&1
            # Cek dah keinstall apa blom
            if [ $? -eq 0 ]; then
				echo -e "${RED}[- DONE INSTALL $nama_paket -]${NC}"
            break
            else
                echo "Gagal menginstal paket $nama_paket pada percobaan ke-$attempt."
                if [ $attempt -eq $max_attempts ]; then
                    echo "Instalasi tidak berhasil setelah $max_attempts percobaan. Lakukan instalasi manual menggunakan 'apt-get install pptpd -y' "
                fi
    		fi
    	sleep 2
		done
		sleep 2
		IP_VPN=""
		RANGE_IP_VPN=""
		echo -e "[ ${GREENISH}CONFIGURE PPTPD${NC} ]"
		echo -n -e "${BLUE}Berikan sebuah IP VPN yang akan digunakan${NC} ${RED}(Tidak Boleh Sama dengan IP Server)${NC}: "
		read IP_VPN
		echo -n -e "${BLUE}Berikan Total Range IP VPN yang akan digunakan${NC}: "
		read RANGE_IP_VPN
		echo -e "[ ${GREENISH}Setting Up PPTPD (${CYAN}/etc/pptpd.conf${NC})${NC} ]"
		last_part=$(echo "$IP_VPN" | awk -F'.' '{print $NF}')
		range_end=$((last_part + RANGE_IP_VPN))
		new_ip="${IP_VPN%.*}.$((last_part + 1))-$range_end"
		sed -i "s/^#localip 192.168.0.1/localip ${IP_VPN}/" /etc/pptpd.conf
		echo -e "${ORANGE}localip ${IP_VPN} >> /etc/pptpd.conf"
		sed -i "s/^#remoteip 192.168.0.234-238,192.168.0.245/remoteip ${new_ip}/" /etc/pptpd.conf
		echo -e "${ORANGE}remoteip ${new_ip} >> /etc/pptpd.conf${NC}"
		echo -e "[ ${GREENISH}Removing Useless Protocols (${CYAN}/etc/ppp/pptpd-options${NC})${NC} ]"
		sed -i '/refuse-pap/s/^/# /; /refuse-chap/s/^/# /; /refuse-mschap/s/^/# /' /etc/ppp/pptpd-options
		echo -e "- ${ORANGE}refuse-pap${NC}"
		echo -e "- ${ORANGE}refuse-chap${NC}"
		echo -e "- ${ORANGE}refuse-mschap${NC}"
		echo -e "[ ${GREENISH}Setting Up DNS (${CYAN}/etc/ppp/pptpd-options${NC})${NC} ]"
		sed -i 's/^#ms-dns 10.0.0.1/ms-dns 8.8.8.8/; s/^#ms-dns 10.0.0.2/ms-dns 8.8.4.4/' /etc/ppp/pptpd-options
		echo -e "${ORANGE}ms-dns 8.8.8.8${NC}"
		echo -e "${ORANGE}ms-dns 8.8.4.4${NC}"
		echo -e "[ ${GREENISH}Adding DNS Resolver(${CYAN}/etc/resolv.conf${NC})${NC} ]"
		echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" | tee /etc/resolv.conf >/dev/null
		echo -e "${ORANGE}nameserver 8.8.8.8${NC}"
		echo -e "${ORANGE}nameserver 8.8.4.4${NC}"
		echo -e "${GREEN}[ ${RED}Complete Configure PPTPD Server${NC} ${GREEN}]${NC}"
		echo -e "clear\nalias cafvpn=\"/etc/run.sh\"\nneofetch" | tee ~/.bashrc >/dev/null 
		echo -e "[ ${GREENISH}Berhasil Menambahkan Command 'cafvpn' untuk Control PPTP ${NC} ]"
		cp "$this_file" "$destination_path" >/dev/null
		chmod +x "$destination_path"
		echo "${IP_VPN}" | tee /etc/ipvpn >/dev/null
		chmod +x /etc/ipvpn
		remaining_time=15
		show_remaining_time() {
    		printf "\rWaktu tersisa: %d detik" $1
		}
		for ((i = $remaining_time; i > 0; i--)); do
    		show_remaining_time $i
		    sleep 1
		done
		source ~/.bashrc
        break
        ;;
      2)
		/etc/init.d/networking restart
        /etc/init.d/pptpd restart
		echo -e "${GREEN}[ ${RED}Berhasil Menjalankan PPTPD${NC} ${GREEN}]${NC}"
        break
        ;;
      3)
	  	file_contents=$(cat /etc/ipvpn)
        iptables -I INPUT -p tcp --dport 1723 -m state --state NEW -j ACCEPT && iptables-save
		iptables -I INPUT -p gre -j ACCEPT
		iptables -t nat -I POSTROUTING -o enp0s3 -j MASQUERADE
		iptables -I FORWARD -p tcp --tcp-flags SYN,RST SYN -s "${file_contents}"/24 -j TCPMSS --clamp-mss-to-pmtu
		echo -e "${GREEN}[ ${RED}Berhasil Mengaktifkan Forwarding IPv4${NC} ${GREEN}]${NC}"
        break
        ;;
      4)
       	echo -e "[ ${GREENISH}CONFIGURE PPTPD${NC} ]"
		echo -n -e "${BLUE}Berikan sebuah user VPN yang akan digunakan ${NC}: "
		read USER_VPN
		echo -n -e "${BLUE}Berikan sebuah password VPN yang akan digunakan ${NC}: "
		read PASS_VPN
		echo "${USER_VPN} pptpd ${PASS_VPN} *" | tee -a /etc/ppp/chap-secrets
        break
        ;;
      *)
	  	clear
        echo -e "${RED}Pilihan tidak valid.${NC} Harap masukkan angka 0-4."
        ;;
    esac
done
