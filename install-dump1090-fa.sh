#!/bin/bash
set -e

BUILD_FOLDER=/usr/share/dump1090-builder

if [[ -d ${BUILD_FOLDER} ]]; then
  echo -e "\e[01;95mRemoving Old Build Folder ${BUILD_FOLDER} \e[0;39m"
  rm -rf ${BUILD_FOLDER};
fi
echo " "
echo -e "\e[01;95mCreating New Build Folder\e[0;32m" ${BUILD_FOLDER} "\e[01;95mto hold source codes \e[0;39m"
mkdir -p ${BUILD_FOLDER}
sleep 3  
if [[ `cat /etc/os-release | grep CentOS` ]] || [[ `cat /etc/os-release | grep AlmaLinux` ]] || [[ `cat /etc/os-release | grep Rocky` ]]; then
  echo -e "\e[01;32mAdding EPEL repository by installing epel-release package \e[0;39m"
  sleep 3
  dnf install epel-release -y
  echo -e "\e[01;32mInstalling package lsb_release to identify the OS \e[0;39m"
  sleep 3
  dnf install lsb-release -y
else
  dnf install lsb-release -y
fi
echo " "
OS_ID=`lsb_release -si`
OS_REL=`lsb_release -sr`
echo -e "\e[01;32mDetected OS \e[1;95m" ${OS_ID} ${OS_REL} " \e[0;39m"
echo " "
sleep 5

echo -e "\e[01;32mUpdating repository... \e[0;39m"
sleep 3
dnf makecache

echo -e "\e[01;32mInstalling Tools & Dependencies, if not yet installed.... \e[0;39m"
echo -e "\e[01;32mgit, wget, make, gcc, usbutils, libusbx, libusbx-devel, ncurses-devel, rtl-sdr, rtl-sdr-devel, lighttpd \e[0;39m"
sleep 3
dnf install -y git
dnf install -y wget
dnf install -y make
dnf install -y gcc
dnf install -y usbutils
dnf install -y libusbx
dnf install -y libusbx-devel
dnf install -y ncurses-devel
dnf install -y rtl-sdr
dnf install -y rtl-sdr-devel
dnf install -y lighttpd

echo -e "\e[01;32mDownloading dump1090-fa Source Code from Github \e[0;39m"
cd ${BUILD_FOLDER}
git clone --depth 1 https://github.com/abcd567a/dump1090.git dump1090-fa
cd ${BUILD_FOLDER}/dump1090-fa
make RTLSDR=yes DUMP1090_VERSION=$(git describe --tags | sed 's/-.*//')
##make RTLSDR=yes DUMP1090_VERSION=$(head -1 debian/changelog | sed 's/.*(\([^)]*\).*/\1/')
echo -e "\e[01;32mCopying Executeable Binary to folder /usr/bin/ \e[0;39m"
if [[ `pgrep dump1090-fa` ]]; then
systemctl stop dump1090-fa
fi

if [[ `pgrep view1090` ]]; then
killall view1090;
fi

echo -e "\e[01;32mCopying necessary files from cloned source code to the computer...\e[0;39m"
mkdir -p /etc/default
cp ${BUILD_FOLDER}/dump1090-fa/debian/dump1090-fa.default /etc/default/dump1090-fa

mkdir -p /usr/share/dump1090-fa/
cp ${BUILD_FOLDER}/dump1090-fa/debian/start-dump1090-fa /usr/share/dump1090-fa/start-dump1090-fa
cp ${BUILD_FOLDER}/dump1090-fa/debian/generate-wisdom /usr/share/dump1090-fa/
cp ${BUILD_FOLDER}/dump1090-fa/debian/upgrade-config /usr/share/dump1090-fa/
mkdir -p /usr/lib/dump1090-fa
cp ${BUILD_FOLDER}/dump1090-fa/starch-benchmark  /usr/lib/dump1090-fa/

mkdir -p /usr/share/skyaware/
cp -r ${BUILD_FOLDER}/dump1090-fa/public_html /usr/share/skyaware/html

cp ${BUILD_FOLDER}/dump1090-fa/debian/dump1090-fa.service /usr/lib/systemd/system/dump1090-fa.service

if [[ ! `getent passwd dump1090` ]]; then
echo -e "\e[01;32mAdding system user dump1090 and adding it to group rtlsdr... \e[0;39m"
echo -e "\e[01;32mThe user dump1090 will run the dump1090-fa service \e[0;39m"
useradd --system dump1090
fi

echo -e "\e[01;32mGroup rtlsdr was created when installing rtl-sdr, now adding the\e[0;39m"
echo -e "\e[01;32muser dump1090 to group rtlsdr to enable it to use rtlsdr Dongle ... \e[0;39m"
usermod -a -G rtlsdr dump1090
systemctl enable dump1090-fa

echo -e "\e[01;32mPerforming Lighttpd integration to display Skyaware Map ... \e[0;39m"
cp ${BUILD_FOLDER}/dump1090-fa/debian/lighttpd/89-skyaware.conf /etc/lighttpd/conf.d/89-skyaware.conf
cp ${BUILD_FOLDER}/dump1090-fa/debian/lighttpd/88-dump1090-fa-statcache.conf /etc/lighttpd/conf.d/88-dump1090-fa-statcache.conf
chmod 666 /etc/lighttpd/lighttpd.conf
if [[ ! `grep "^server.modules += ( \"mod_alias\" )" /etc/lighttpd/lighttpd.conf` ]]; then
  echo "server.modules += ( \"mod_alias\" )" >> /etc/lighttpd/lighttpd.conf
fi
if [[ ! `grep "89-skyaware.conf" /etc/lighttpd/lighttpd.conf` ]]; then
  echo "include conf_dir + \"/conf.d/89-skyaware.conf\"" >> /etc/lighttpd/lighttpd.conf
fi
sed -i 's/server.use-ipv6 = "enable"/server.use-ipv6 = "disable"/' /etc/lighttpd/lighttpd.conf
chmod 644 /etc/lighttpd/lighttpd.conf
systemctl enable lighttpd
systemctl start lighttpd

#Integration if user replaces Lighttpd by Apache
mkdir -p /etc/httpd/conf.d
wget -O /etc/httpd/conf.d/apache.skyaware.conf https://github.com/abcd567a/Piaware-on-Fedora-CentOS-AlmaLinux/raw/master/apache.skyaware.conf

if [[ ${OS_ID} == "Fedora" ]]; then
echo -e "\e[01;32mConfiguring SELinux to run permissive for httpd \e[0;39m"
echo -e "\e[01;32mThis will enable lighttpd to pull aircraft data \e[0;39m"
echo -e "\e[01;32mfrom folder /var/run/dump1090-fa/ \e[0;39m"
echo -e "\e[39m   sudo semanage permissive -a httpd_t \e[39m"
semanage permissive -a httpd_t;
fi

echo " "
echo -e "\e[01;32mConfiguring Firewall to permit display of SkyView from LAN/internet \e[0;39m"
echo -e "\e[39m   sudo firewall-cmd --add-service=http \e[39m"
firewall-cmd --add-service=http

echo -e "\e[39m   sudo firewall-cmd --add-port=8080/tcp \e[39m"
firewall-cmd --add-port=8080/tcp

echo -e "\e[39m   sudo firewall-cmd --runtime-to-permanent \e[39m"
firewall-cmd --runtime-to-permanent

echo -e "\e[39m   sudo firewall-cmd --reload \e[39m"
firewall-cmd --reload

systemctl enable dump1090-fa.service
systemctl start dump1090-fa.service

echo ""
echo -e "\e[32mDUMP1090=FA INSTALLATION COMPLETED \e[39m"
echo ""
echo -e "\e[01;32mSee the Web Interface (Map etc) at\e[0;39m"
echo -e "\e[39m     $(ip route | grep -m1 -o -P 'src \K[0-9,.]*')/skyaware/ \e[39m" "\e[35m(IP-of-Computer/skyaware/) \e[39m"
echo -e "\e[01;32m   OR \e[0;39m"
echo -e "\e[39m     $(ip route | grep -m1 -o -P 'src \K[0-9,.]*'):8080 \e[39m" "\e[35m(IP-of-Computer:8080) \e[39m"
echo " "
echo -e "\e[01;31mREBOOT Computer ... REBOOT Computer ... REBOOT Computer \e[0;39m"
echo " "
