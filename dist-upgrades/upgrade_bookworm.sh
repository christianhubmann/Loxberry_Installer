#!/bin/bash

########################################################################
# Adjust this to the latest release image

TARGET_VERSION_ID="12"
TARGET_PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
LBHOME="/opt/loxberry"
PHPVER_PROD=7.4
PHPVER_TEST=8.2

#
########################################################################

# Needed for some LoxBerry scripts
export LBHOMEDIR=$LBHOME
export PERL5LIB=$LBHOME/libs/perllib
export APT_LISTCHANGES_FRONTEND="none"
export DEBIAN_FRONTEND="noninteractive"

# Run as root
if (( $EUID != 0 )); then
    echo "This script has to be run as root."
    exit 1
fi

# install needed packages
apt-get -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages --allow-releaseinfo-change update

# Clear screen
tput clear

# Formating - to be used in echo's
BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`
BOLD=`tput bold`
ULINE=`tput smul`
RESET=`tput sgr0`

########################################################################
# Functions

# Horizontal Rule
HR () {
	echo -en "${!1}"
	printf '%.s─' $(seq 1 $(tput cols))
	echo -e "${RESET}"
}

# Section
TITLE () {
	echo -e ""
	HR "WHITE"
	echo -e "${BOLD}$1${RESET}"
	HR "WHITE"
	echo -e ""
}

# Messages
OK () {
	echo -e "\n${GREEN}[  OK   ]${RESET} .... $1"
}
FAIL () {
	echo -e "\n${RED}[FAILED ]${RESET} .... $1"
}
WARNING () {
	echo -e "\n${MAGENTA}[WARNING]${RESET} .... $1"
}
INFO () {
	echo -e "\n${YELLOW}[ INFO  ]${RESET} .... $1"
}

#
########################################################################


# Main Script
HR "GREEN"
echo -e "${BOLD}LoxBerry - BEYOND THE LIMITS${RESET}"
HR "GREEN"

# Read Distro infos
if [ -e /etc/os-release ]; then
	. /etc/os-release
	#PRETTY_NAME="Debian GNU/Linux 11 (bullseye)"
	#NAME="Debian GNU/Linux"
	#VERSION_ID="11"
	#VERSION="11 (bullseye)"
	#VERSION_CODENAME=bullseye
	#ID=debian
	#HOME_URL="https://www.debian.org/"
	#SUPPORT_URL="https://www.debian.org/support"
	#BUG_REPORT_URL="https://bugs.debian.org/"
fi
if [ -e /boot/dietpi/.hw_model ]; then
	. /boot/dietpi/.hw_model
	#G_HW_MODEL=20
	#G_HW_MODEL_NAME='Virtual Machine (x86_64)'
	#G_HW_ARCH=10
	#G_HW_ARCH_NAME='x86_64'
	#G_HW_CPUID=0
	#G_HW_CPU_CORES=2
	#G_DISTRO=6
	#G_DISTRO_NAME='bullseye'
	#G_ROOTFS_DEV='/dev/sda1'
	#G_HW_UUID='0f26dd2a-8ed6-40ee-86e9-c3b204dba1e0'
fi
if [ -e /boot/dietpi/.version ]; then
	. /boot/dietpi/.version
	#G_DIETPI_VERSION_CORE=8
	#G_DIETPI_VERSION_SUB=13
	#G_DIETPI_VERSION_RC=2
	#G_GITBRANCH='master'
	#G_GITOWNER='MichaIng'
	#G_LIVE_PATCH_STATUS[0]='applied'
	#G_LIVE_PATCH_STATUS[1]='not applicable'
fi

# Check correct distribution
if [ ! -e /boot/dietpi/.version ]; then
	echo -e "\n${RED}This seems not to be a DietPi Image. This script will run only on DietPi.\n"
	echo -e "We expect $TARGET_PRETTY_NAME as distribution.${RESET}\n"
	exit 1
fi

if [ $VERSION_ID -ne $TARGET_VERSION_ID ]; then
	echo -e "\n${RED}You are running $PRETTY_NAME. This distribution"
	echo -e "is not supported by this script.\n"
	echo -e "We expect $TARGET_PRETTY_NAME as distribution.${RESET}\n"
	exit 1
fi

if [ ! -e "$LBHOME/packages${TARGET_VERSION_ID}.txt" ]; then
	echo -e "\n${RED}We cannot find some files on your LoxBerry. Nake sure you run LoxBerry Update first!"
	echo -e "We need the latest version of LoxBerry!${RESET}\n"
	exit 1
fi

# Welcome screen with overview
echo -e "\nThis script will upgrade ${BOLD}${ULINE}LoxBerry${RESET} to run on ${BOLD}${ULINE}$TARGET_PRETTY_NAME${RESET}.\n"
echo -e "${RED}${BOLD}WARNING!${RESET}${RED} You cannot undo the upgrade! Make sure you have a BACKUP of oyur LoxBerry!"
echo -e "Nothing will be like it was before ;-) You have been warned...${RESET}"
echo -e "\n${ULINE}Your system seems to be:${RESET}\n"
echo -e "Distribution:       $PRETTY_NAME"
echo -e "DietPi Version:     $G_DIETPI_VERSION_CORE.$G_DIETPI_VERSION_SUB"
echo -e "Hardware Model:     $G_HW_MODEL_NAME"
echo -e "Architecture:       $G_HW_ARCH_NAME"
echo -e "\n\nHit ${BOLD}<CTRL>+C${RESET} now to stop, any other input will continue.\n"
read -n 1 -s -r -p "Press any key to continue"
tput clear

# Configuring hardware architecture
TITLE "Installing additional software packages from apt repository..."

/boot/dietpi/func/dietpi-set_software apt reset
/boot/dietpi/func/dietpi-set_software apt compress disable
/boot/dietpi/func/dietpi-set_software apt cache clean

# Configure PHP - we want PHP7.4 as default while Bookworm only has 8.2
curl -sL https://packages.sury.org/php/apt.gpg | gpg --dearmor | tee /usr/share/keyrings/deb.sury.org-php.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list

apt-get -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages --allow-releaseinfo-change update

if [ -e "$LBHOME/packages${TARGET_VERSION_ID}.txt" ]; then
        PACKAGES=""
        echo ""
        while read entry
        do
                if echo $entry | grep -Eq "^ii "; then
                        VAR=$(echo $entry | sed "s/  / /g" | cut -d " " -f 2 | sed "s/:.*\$//")
                        PINFO=$(apt-cache show $VAR 2>&1)
                        if echo $PINFO | grep -Eq "N: Unable to locate"; then
                        	WARNING "Unable to locate package $PACKAGE. Skipping..."
                                continue
                        fi
                        PACKAGE=$(echo $PINFO | grep "Package: " | cut -d " " -f 2)
			if [ -z $PACKAGE ] || [ $PACKAGE = "" ]; then
				continue
			fi
                        if dpkg -s $PACKAGE > /dev/null 2>&1; then
                        	INFO "$PACKAGE seems to be already installed. Skipping..."
                                continue
                        fi
                        OK "Add package $PACKAGE to the installation queue..."
                        PACKAGES+="$PACKAGE "
                fi
        done < "$LBHOME/packages${TARGET_VERSION_ID}.txt"
else
        FAIL "Could not find packages list: $LBHOME/packages$TARGET_VERSION_ID.txt.\n"
        exit 1
fi

echo ""
echo "These packages will be installed now:"
echo $PACKAGES
echo ""

apt-get --no-install-recommends -y --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages install $PACKAGES
if [ $? != 0 ]; then
        FAIL "Could not install (at least some) queued packages.\n"
	exit 1
else
        OK "Successfully installed all queued packages.\n"
fi

/boot/dietpi/func/dietpi-set_software apt compress enable
/boot/dietpi/func/dietpi-set_software apt cache clean
apt-get -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages --allow-releaseinfo-change update

# Remove dhcpd - See issue 135
TITLE "Removing dhcpcd5..."

apt-get --no-install-recommends -y --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages purge dhcpcd5

# Remove appamor
TITLE "Removing AppArmor..."

apt-get --no-install-recommends -y --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages purge apparmor

apt-get -y --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages --purge autoremove

# Environment Variablen laden
source /etc/environment

# PHP - we install PHP8.2 for testing and 7.4 for production
#apt-get --no-install-recommends -y --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages install php${PHPVER_TEST} php${PHPVER_PROD}

TITLE "Configuring PHP ${PHPVER_PROD}..."

if [ ! -e /etc/php/${PHPVER_PROD} ]; then
	FAIL "Could not set up PHP - target folder /etc/php/${PHPVER_PROD} does not exist.\n"
	exit 1
fi

mkdir -p /etc/php/${PHPVER_PROD}/apache2/conf.d
mkdir -p /etc/php/${PHPVER_PROD}/cgi/conf.d
mkdir -p /etc/php/${PHPVER_PROD}/cli/conf.d
rm /etc/php/${PHPVER_PROD}/apache2/conf.d/20-loxberry.ini
rm /etc/php/${PHPVER_PROD}/cgi/conf.d/20-loxberry.ini
rm /etc/php/${PHPVER_PROD}/cli/conf.d/20-loxberry.ini
ln -s $LBHOME/system/php/loxberry-apache.ini /etc/php/${PHPVER_PROD}/apache2/conf.d/20-loxberry-apache.ini
ln -s $LBHOME/system/php/loxberry-apache.ini /etc/php/${PHPVER_PROD}/cgi/conf.d/20-loxberry-apache.ini
ln -s $LBHOME/system/php/loxberry-cli.ini /etc/php/${PHPVER_PROD}/cli/conf.d/20-loxberry-cli.ini

if [ ! -L  /etc/php/${PHPVER_PROD}/apache2/conf.d/20-loxberry-apache.ini ]; then
	FAIL "Could not set up PHP ${PHPVER_PROD}.\n"
	exit 1
else
	OK "Successfully set up PHP ${PHPVER_PROD}."
fi

TITLE "Configuring PHP ${PHPVER_TEST}..."

if [ ! -e /etc/php/${PHPVER_TEST} ]; then
	FAIL "Could not set up PHP - target folder /etc/php/${PHPVER_TEST} does not exist.\n"
	exit 1
fi

mkdir -p /etc/php/${PHPVER_TEST}/apache2/conf.d
mkdir -p /etc/php/${PHPVER_TEST}/cgi/conf.d
mkdir -p /etc/php/${PHPVER_TEST}/cli/conf.d
rm /etc/php/${PHPVER_TEST}/apache2/conf.d/20-loxberry.ini
rm /etc/php/${PHPVER_TEST}/cgi/conf.d/20-loxberry.ini
rm /etc/php/${PHPVER_TEST}/cli/conf.d/20-loxberry.ini
ln -s $LBHOME/system/php/loxberry-apache.ini /etc/php/${PHPVER_TEST}/apache2/conf.d/20-loxberry-apache.ini
ln -s $LBHOME/system/php/loxberry-apache.ini /etc/php/${PHPVER_TEST}/cgi/conf.d/20-loxberry-apache.ini
ln -s $LBHOME/system/php/loxberry-cli.ini /etc/php/${PHPVER_TEST}/cli/conf.d/20-loxberry-cli.ini

if [ ! -L  /etc/php/${PHPVER_TEST}/apache2/conf.d/20-loxberry-apache.ini ]; then
	FAIL "Could not set up PHP ${PHPVER_TEST}.\n"
	exit 1
else
	OK "Successfully set up PHP ${PHPVER_TEST}."
fi


TITLE "Enabling PHP ${PHPVER_PROD}..."
update-alternatives --set php /usr/bin/php${PHPVER_PROD}


# Configuring Apache2
TITLE "Configuring Apache2..."

# Apache Config
a2dismod php*
a2dissite 001-default-ssl
a2enmod php${PHPVER_PROD}

# Configuring Python 3 - reenable pip installations
TITLE "Configuring Python3..."

echo -e '[global]\nbreak-system-packages=true' > /etc/pip.conf
if [ -e /etc/pip.conf ]; then
	OK "Python3 configured successfully.\n"
else
	FAIL "Could not set up Python 3.\n"
	exit 1
fi

# Configure listchanges to have no output - for apt beeing non-interactive
TITLE "Configuring listchanges to be quit..."

if [ -e /etc/apt/listchanges.conf ]; then
	sed -i 's/frontend=pager/frontend=none/' /etc/apt/listchanges.conf
fi

OK "Successfully configured listchanges."

# Installing NodeJS
TITLE "Installing NodeJS"
/boot/dietpi/dietpi-software install 9

# Installing YARN
TITLE "Installing Yarn"
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarnkey.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | tee /etc/apt/sources.list.d/yarn.list

apt-get -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages --allow-releaseinfo-change update
apt-get --no-install-recommends -y --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages install yarn

# Set correct File Permissions
TITLE "Setting File Permissions..."

$LBHOME/sbin/resetpermissions.sh

if [ $? != 0 ]; then
	FAIL "Could not set File Permissions for LoxBerry.\n"
	exit 1
else
	OK "Successfully set File Permissions for LoxBerry."
fi

# Start Apache
TITLE "Start Apache2 Webserver..."

/bin/systemctl restart apache2

if ! /bin/systemctl --no-pager status apache2; then
       FAIL "Could not reconfigure Apache2.\n"
       exit 1
else
       OK "Successfully reconfigured Apache2."
fi

# Set correct File Permissions - again
TITLE "Setting File Permissions (again)..."

$LBHOME/sbin/resetpermissions.sh

if [ $? != 0 ]; then
	FAIL "Could not set File Permissions for LoxBerry.\n"
	exit 1
else
	OK "Successfully set File Permissions for LoxBerry."
fi

# The end
export PERL5LIB=$LBHOME/libs/perllib
IP=$(perl -e 'use LoxBerry::System; $ip = LoxBerry::System::get_localip(); print $ip; exit;')
echo -e "\n\n\n${GREEN}WE ARE DONE! :-)${RESET}"
echo -e "\n\n${RED}You have to reboot your LoxBerry now!${RESET}"
echo -e "\n${GREEN}Then point your browser to http://$IP or http://loxberry"
echo -e "\nGood Bye.\n\n${RESET}"

exit 0
