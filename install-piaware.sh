#!/bin/bash
set -e

BUILD_FOLDER=/usr/share/piaware-builder
if [[ -d ${BUILD_FOLDER} ]]; then
  echo -e "\e[01;95mRemoving Old Build Folder ${BUILD_FOLDER} \e[0;39m"
  rm -rf ${BUILD_FOLDER};
fi
echo " "
echo -e "\e[01;95mCreating New Build Folder\e[0;32m" ${BUILD_FOLDER} "\e[01;95mto hold source codes \e[0;39m"
sleep 3
mkdir -p ${BUILD_FOLDER}

if [[ `cat /etc/os-release | grep CentOS` || `cat /etc/os-release | grep AlmaLinux` || `cat /etc/os-release | grep Rocky` ]] ; then
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
sleep 10

echo -e "\e[01;32mUpdating repository... \e[0;39m"
sleep 3
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
dnf install tk -y
dnf install python3-setuptools -y
dnf install python3-devel -y

if [[ `lsb_release -si` == "Fedora" ]]; then
  dnf install tcllib -y
  dnf install tcltls -y
  dnf install itcl -y
  dnf install tclx -y
  dnf install python3-pyasyncore -y
else
  echo -e "\e[01;32mDownloading & Installing .rpm packages \e[0;39m"
  echo -e "\e[01;32mtcllib, tcltls, python3-pyasyncore\e[0;39m"
  cd ${BUILD_FOLDER}
  wget https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/Packages/t/tcllib-1.21-1.el9.noarch.rpm
  dnf install tcllib-1.21-1.el9.noarch.rpm -y
  wget https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/Packages/t/tcltls-1.7.22-7.el9.x86_64.rpm
  dnf install tcltls-1.7.22-7.el9.x86_64.rpm -y
  wget https://dl.fedoraproject.org/pub/epel/10/Everything/x86_64/Packages/p/python3-pyasyncore-1.0.4-1.el10_1.noarch.rpm
  sudo dnf install python3-pyasyncore-1.0.4-1.el10_1.noarch.rpm -y

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
  ln -sf /usr/lib/itcl* /usr/share/tcl8.6
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
git clone --depth 1 https://github.com/mutability/mlat-client.git
cd mlat-client
./setup.py build
./setup.py install

echo -e "\e[01;95mBuilding & Installing faup1090 using Source Code from Github \e[0;39m"
sleep 3
cd ${BUILD_FOLDER}
git clone --depth 1 https://github.com/flightaware/dump1090 faup1090
cd faup1090
make faup1090

echo -e "\e[01;95mBuilding & Installing PIAWARE using Source Code from Github \e[0;39m"
sleep 3
cd ${BUILD_FOLDER}
git clone --depth 1 https://github.com/flightaware/piaware.git
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
