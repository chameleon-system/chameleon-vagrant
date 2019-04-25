#!/usr/bin/env bash

# exit if any errors are encountered
set -e

INSTLOG=/var/log/chameleon-install.log

# open fd=3 redirecting to 1 (stdout)
exec 3>&1

# function echo to show echo output on terminal
echo() {
   # call actual echo command and redirect output to fd=3 and log file
   command echo "$@"
   command echo "$@" >&3
}

# redirect stdout to a log file
exec >>${INSTLOG}
exec 2>&1

echo "Starting vagrant bootstrap.sh script. Detailed log info can be found within the vagrant guest in ${INSTLOG}"
echo ""

echo "Step [1/6] - Installing docker..."
apt-get update
apt-get install -yqq apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -yqq  docker-ce=18.06.1~ce~3-0~ubuntu

echo "Step [2/6] - Installing docker-compose..."
curl -Ls https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose 

echo "Step [3/6] - Installing chameleon sources..."
mkdir -p /home/wwwusers/chameleon
cd /home/wwwusers/chameleon
git clone https://github.com/chameleon-system/chameleon-system.git customer
git clone https://github.com/chameleon-system/chameleon-resources.git resources
# TODO parameters.yml creation
chown -R www-data:www-data /home/wwwusers/chameleon

echo "Step [4/6] - Launching docker-compose application stack..."
cd ~vagrant
docker-compose up -d

echo "Step [5/6] - Installing composer packages..."
# TODO this bootstrapping part should be performed by a separate docker - k8s Init Container style
chmod 755 /home/vagrant/installcomposer.sh
chown www-data:www-data /home/vagrant/installcomposer.sh
docker exec -i $(docker ps | grep 'php' | awk '{print $1}') chown www-data:www-data /var/www
docker exec -u www-data -i $(docker ps | grep 'php' | awk '{print $1}') /usr/local/bin/installcomposer.sh

echo "Step [6/6] - Importing database..."
# TODO import database
MYSQLDOCKER=$(docker ps | grep 'mariadb' | awk '{print $1}')
docker exec -ti ${MYSQLDOCKER} bash -c 'cat /initial-database/*.sql | mysql -uchameleon -pchameleon chameleon'

echo "Ready! You should now be able to access chameleon at the given hostname. Remember restrictions for privileged ports!"
# close fd=3
exec 3>&-
