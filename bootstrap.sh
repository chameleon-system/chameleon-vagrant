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

curl -Ls https://github.com/chameleon-system/chameleon-system/archive/7.0.0.tar.gz -o chameleon.tar.gz
tar xfz chameleon.tar.gz
mv chameleon-system-7.0.0 customer

curl -Ls https://github.com/chameleon-system/chameleon-resources/archive/7.0.0.tar.gz -o chameleon-resources.tar.gz
tar xfz chameleon-resources.tar.gz
mv chameleon-resources-7.0.0 resources

# add custom config
# this should be set via env as soon as possible via composer or alike

cat << EOF > /home/wwwusers/chameleon/customer/app/config/parameters.yml
parameters:
    secret: ChangeMe
    chameleon_system_core.debug.show_view_source_html_hints: true
    chameleon_system_core.development_email: 'email@example-com'
    database_host: mysql
    database_port: 3306
    database_name: chameleon
    database_user: chameleon
    database_password: chameleon
    chameleon_system_core.cache.memcache_server1: memcached
    chameleon_system_core.cache.memcache_port1: '11211'
    chameleon_system_core.cache.memcache_sessions_server1: memcached-session
    chameleon_system_core.cache.memcache_sessions_port1: '11211'
    chameleon_system_core.mail_target_transformation_service.enabled: false
    chameleon_system_core.mail_target_transformation_service.subject_prefix: '[TEST] '
    chameleon_system_core.mail_target_transformation_service.target_mail: mail@example.com
    chameleon_system_core.mail_target_transformation_service.white_list: '@@PORTAL-DOMAINS'
    mailer_host: 127.0.0.1
    mailer_user: null
    mailer_password: null
EOF

chown -R www-data:www-data /home/wwwusers/chameleon

echo "Step [4/6] - Launching docker-compose application stack..."
cd ~vagrant
docker-compose up -d

echo "Step [5/6] - Installing composer packages..."
# TODO this bootstrapping part should be performed by a separate docker - k8s Init Container style
chmod 755 /home/vagrant/installcomposer.sh
chown www-data:www-data /home/vagrant/installcomposer.sh
PHPDOCKER=$(docker ps | grep 'php' | awk '{print $1}')
docker exec -i ${PHPDOCKER} chown www-data:www-data /var/www
docker exec -u www-data -i ${PHPDOCKER} /usr/local/bin/installcomposer.sh

echo "Step [6/6] - Importing database and mediapool..."
# importing DB
MYSQLDOCKER=$(docker ps | grep 'mariadb' | awk '{print $1}')
docker exec -i ${MYSQLDOCKER} bash -c 'cat /initial-database/*.sql | mysql -uchameleon -pchameleon chameleon'

# setting primary domain
docker exec -i ${MYSQLDOCKER} /bin/bash -c "echo \"INSERT INTO cms_portal_domains SET id='1', name='localhost', cms_portal_id='1', is_master_domain='1';\" | mysql -u chameleon -pchameleon chameleon"

# importing mediapool
rsync -a /home/wwwusers/chameleon/resources/mediapool/ /home/wwwusers/chameleon/customer/web/chameleon/mediapool/

# creating initial user
docker exec -u www-data -e APP_INITIAL_BACKEND_USER_NAME=admin -e APP_INITIAL_BACKEND_USER_PASSWORD=adminadminadmin -i ${PHPDOCKER} app/console chameleon_system:bootstrap:create_initial_backend_user -n

echo "Ready! You should now be able to access chameleon at the given hostname. Remember restrictions for privileged ports!"
# close fd=3
exec 3>&-
