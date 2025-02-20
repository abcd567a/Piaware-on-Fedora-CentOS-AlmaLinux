#!/bin/bash
set -e

BUILD_FOLDER=/usr/share/piaware-builder
echo -e "\e[01;95mCreating Build Folder\e[0;32m" ${BUILD_FOLDER} "\e[01;95mto hold source codes \e[0;39m"
sleep 3
mkdir -p ${BUILD_FOLDER}

echo -e "\e[01;32mUpdating repository... \e[0;39m"
sleep 3
if [[ `cat /etc/os-release | grep CentOS` ]] || [[ `cat /etc/os-release | grep AlmaLinux` ]] ; then 
  echo -e "\e[01;32mAdding EPEL repository by installing epel-release package \e[0;39m"
  sleep 3
  dnf install epel-release -y
  echo -e "\e[01;32mInstalling package lsb_release to identify the OS \e[0;39m"
  sleep 3
  dnf install lsb-release -y
else
  dnf install lsb-release -y
fi

OS_ID=`lsb_release -si`

dnf makecache

echo -e "\e[01;32mInstalling Tools & Dependencies.... \e[0;39m"
sleep 3
dnf install git -y
dnf install gcc -y
dnf install autoconf -y
dnf install ncurses-devel -y
dnf install net-tools -y
dnf install openssl-devel -y
dnf install openssl-perl -y
dnf install tcl -y
dnf install tcl-devel -y
dnf install tcllib -y
dnf install tcltls -y
dnf install tk -y
dnf install python3-setuptools -y
dnf install python3-devel -y

if [[ `lsb_release -si` == "Fedora" ]]; then
  dnf install python3-pyasyncore -y
  dnf install itcl -y
  dnf install tclx -y
else
  echo -e "\e[01;32mBuilding & Installing tclx using Source Code from Github \e[0;39m"
  sleep 3
  cd ${BUILD_FOLDER}
  git clone https://github.com/flightaware/tclx.git
  cd tclx
  ./configure
  make
  make install
  ln -sf /usr/lib/tclx8.6 /usr/share/tcl8.6

  echo -e "\e[01;95mBuilding & Installing itcl using Source Code from Github \e[0;39m"
  sleep 3
  cd ${BUILD_FOLDER}
  git clone https://github.com/tcltk/itcl.git
  cd itcl
  ./configure
  make all
  make test
  ln -sf itclWidget/tclconfig tclconfig
  make install
  ln -sf /usr/lib/itcl4.3.2 /usr/share/tcl8.6
fi

echo -e "\e[01;32mBuilding & Installing tcllauncher using Source Code from Github \e[0;39m"
sleep 3
cd ${BUILD_FOLDER}
git clone https://github.com/flightaware/tcllauncher.git
cd tcllauncher
autoconf
./configure --prefix=/usr/share/piaware-builder --with-tcl=/usr/lib64/tclConfig.sh
make
make install
ln -sf /usr/lib/Tcllauncher1.10 /usr/share/tcl8.6

echo -e "\e[01;95mBuilding & Installing mlat-client & fa-mlat-client using Source Code from Github \e[0;39m"
sleep 3
cd ${BUILD_FOLDER}
git clone https://github.com/mutability/mlat-client.git
cd mlat-client
./setup.py build
./setup.py install

##dnf install python3-wheel -y
##dnf install python3-devel -y
##dnf install python3-pyasyncore -y
##python3 -m build --wheel --no-isolation

echo -e "\e[01;95mBuilding & Installing faup1090 using Source Code from Github \e[0;39m"
sleep 3
cd ${BUILD_FOLDER}
git clone -b dev --depth 1 https://github.com/flightaware/dump1090 faup1090
cd faup1090
make faup1090

echo -e "\e[01;95mBuilding & Installing PIAWARE using Source Code from Github \e[0;39m"
sleep 3
cd ${BUILD_FOLDER}
git clone https://github.com/flightaware/piaware.git
cd piaware
make install

adduser --system piaware

ln -sf /usr/lib/piaware_packages /usr/share/tcl8.6
ln -sf /usr/lib/fa_adept_codec /usr/share/tcl8.6
cp ${BUILD_FOLDER}/faup1090/faup1090 /usr/lib/piaware/helpers/
cp /usr/local/bin/fa-mlat-client /usr/lib/piaware/helpers/
install -Dm440 ${BUILD_FOLDER}/piaware/etc/piaware.sudoers /etc/sudoers.d/piaware
touch /etc/piaware.conf
chown piaware:piaware /etc/piaware.conf
sudo install -d -o piaware -g piaware /var/cache/piaware

systemctl enable generate-pirehose-cert.service
systemctl start generate-pirehose-cert.service
systemctl enable piaware.service
systemctl start piaware.service

echo ""
echo -e "\e[32mPIAWARE INSTALLATION COMPLETED \e[39m"
echo ""
echo -e "\e[39mIf you already have  feeder-id, please configure piaware with it \e[39m"
echo -e "\e[39mFeeder Id is available on this address while loggedin: \e[39m"
echo -e "\e[94m    https://flightaware.com/adsb/stats/user/ \e[39m"
echo ""
echo -e "\e[39m    sudo piaware-config feeder-id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \e[39m"
echo -e "\e[39m    sudo piaware-config allow-manual-updates yes \e[39m"
echo -e "\e[39m    sudo piaware-config allow-auto-updates yes \e[39m"

if [[ `ps --no-headers -o comm 1` == "systemd" ]]; then
   echo -e "\e[39m    sudo systemctl restart piaware \e[39m"
else
   echo -e "\e[39m    sudo service piaware restart \e[39m"
fi

echo ""
echo -e "\e[39mIf you dont already have a feeder-id, please go to Flightaware Claim page while loggedin \e[39m"
echo -e "\e[94m    https://flightaware.com/adsb/piaware/claim \e[39m"
echo ""
