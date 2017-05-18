#!/bin/bash
clear
cd /tmp
echo " __  __           _            _                   _"
echo "|  \/  | __ _ ___| |_ ___   __| | ___  _ __    ___| |___"
echo "| |\/| |/ _  / __| __/ _ \ / _  |/ _ \|  _ \  / __|  _  |"
echo "| |  | | (_| \__ \ || (_) | (_| | (_) | | | |_\__ \ | | |"
echo "|_|  |_|\____|___/\__\___/ \____|\___/|_| |_(_)___/_| |_|"
echo ""
echo "Welcome to Mastodon.sh !"
echo "> This script permits to install your own Mastodon's instance without doing anything !"
echo "> This script has been created by PastaGringo with the indirect help of Angristan"
echo
echo "This script works on Debian 8 (Jessie) and is still in development"
echo "!!! You need to start this script on a new fresh VPS, to avoid any issue on your production environment !!!"
echo
echo "There are few things that you need to know before continuing if you want your own fonctionnal Mastodon instance :"
echo "1) You need to have a valid domain name with an A DNS record with the local server IP address"
echo "2) You need to have an account with a SMTP tiers like Mailgun/SparkPost or you own SMTP relay"
echo "3) Few dozen of minutes regarding of your server performances"
echo
echo "> If all above things are in your possession, we can continue and install your first Mastodon instance !"
echo "PS : if not, when the script will finish, you will need to modify few files by your own."
echo
read -p ">>> I understood everything... please continue ! <<<"
echo
echo "> For installing Mastodon with this script, you absolutely need to have the same IP for the A DNS record from your domain and this server."
echo "Could please give me your domain name? ONLY in this format >> domain.tld <<"
read domainwithtld
domain=$(echo $domainwithtld | cut -d'.' -f 1) 
echo
echo "> This script allow to configure a Mailgun account, in order to send mail activation for new Mastodon's users."
echo "If you don't use Mailgun (or other services), you will need to modify the SMTP settings in the file "/home/mastodon/live/.env.production""
echo "> this part is not fully implemented yet <"
read -r -p "Do you want to configure your Mailgun account ? [y/n]" response
case "$response" in
        [y])
                mailgunsetup="yes"
                echo
                echo "All right!"
                read -r -p "Please give me your Mailgun SMTP login : " mailgunlogin
                read -r -p "Please give me your Mailgun SMTP password : " mailgunpwd
                read -r -p "Please give me your Mailgun SMTP mail sender (something@domain.tld) : " mailgunsender
                echo "It's done !"
                ;;
        *)
                echo "No problem!"
                ;;
esac                                                         
echo
echo "To finish, could you give your email accout ? (for letsencrypt certificate) : "
read email
echo
echo "I got everything I need !"
echo "I will verify one last thing before begin the install..."
echo
echo "Updating repos..."
apt-get -qq clean
apt-get -qq update 
echo "Installing dnsutils..."
apt-get -qq install dnsutils -y > /dev/null
echo
echo "Looking for the DNS A record on $domainwithtld..."
Target_domain_DNS_record_A=$(dig $domainwithtld +short)
echo $Target_domain_DNS_record_A
echo "Looking for the server's external IP address..."
external_ip=$(dig +short myip.opendns.com @resolver1.opendns.com)
echo $external_ip
echo
if [ "$Target_domain_DNS_record_A" == "$external_ip" ]; then
        echo "It's all good ! IP address are the same, script will work without issue."
else
        echo "! WARNING ! Your A DNS record for $domainwithtld is different than the local external address IP. The script will not work at the end ! (LetsEncrypt certificate)"
fi
echo
read -r -p "Are you sure to install Mastodon's instance? [y/n] " response
case "$response" in
        [y])
                echo
                echo GO
                echo
                ;;
        *)
                echo Wrong answser, exiting....
                echo
                exit
                ;;
esac
rubyversion=$(curl -s https://raw.githubusercontent.com/tootsuite/mastodon/master/.ruby-version)    
echo "Mastodon Ruby version is : " $rubyversion
echo
echo "deb http://httpredir.debian.org/debian jessie-backports main" >> /etc/apt/sources.list
apt update && apt full-upgrade -y
apt-get install imagemagick ffmpeg libpq-dev libxml2-dev pkg-config libxslt1-dev file curl git g++ libprotobuf-dev protobuf-compiler -y
echo
echo NODEJS 
echo
curl -sL https://deb.nodesource.com/setup_4.x | bash -
apt install nodejs -y
npm install -g yarn 
apt install redis-server redis-tools -y
echo
echo POSTGRES  
echo
apt-get install postgresql postgresql-contrib -y
su - postgres -c "psql -c 'CREATE USER mastodon CREATEDB;'"  
adduser --disabled-password --disabled-login --gecos "" mastodon
echo "mastodon ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
apt install autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm3 libgdbm-dev -y
su - mastodon << EOF
git clone https://github.com/rbenv/rbenv.git /home/mastodon/.rbenv
cd /home/mastodon/.rbenv && src/configure && make -C src
echo 'export PATH="/home/mastodon/.rbenv/bin:$PATH"' >> /home/mastodon/.bash_profile
EOF
echo 'eval "$(rbenv init -)"' >> /home/mastodon/.bash_profile
su - mastodon << EOF
git clone https://github.com/rbenv/ruby-build.git /home/mastodon/.rbenv/plugins/ruby-build
rbenv install --verbose $rubyversion
rbenv global $rubyversion
gem install bundler
cd /home/mastodon
git clone https://github.com/tootsuite/mastodon.git live
cd live
bundle install --deployment --without development test
yarn install
cp .env.production.sample .env.production
EOF
cd /home/mastodon/live
secret1=$(/home/mastodon/.rbenv/shims/bundle exec rake secret)
secret2=$(/home/mastodon/.rbenv/shims/bundle exec rake secret)
secret3=$(/home/mastodon/.rbenv/shims/bundle exec rake secret)
export secret1 secret2 secret3 domainwithtld
su - mastodon << EOF
cd /home/mastodon/live
if test -f .env.production; then rm .env.production && cp .env.production.sample .env.production; else cp .env.production.sample .env.production; fi
sed -i '/REDIS_HOST=/c\REDIS_HOST=localhost' .env.production                                                                                                                                                      
sed -i '/DB_HOST=/c\DB_HOST=/var/run/postgresql' .env.production
sed -i '/DB_USER=/c\DB_USER=mastodon' .env.production
sed -i '/DB_NAME=/c\DB_NAME=mastodon_production' .env.production
sed -i '/LOCAL_DOMAIN=/c\LOCAL_DOMAIN=${domainwithtld}' .env.production
sed -i '/PAPERCLIP_SECRET=/c\PAPERCLIP_SECRET=${secret1}' .env.production
sed -i '/SECRET_KEY_BASE=/c\SECRET_KEY_BASE=${secret2}' .env.production
sed -i '/OTP_SECRET=/c\OTP_SECRET=${secret3}' .env.production            
echo
echo Mise en place de la base de données  
echo
RAILS_ENV=production bundle exec rails db:setup
echo
echo Pré-compilation des fichiers CSS et JS
echo
RAILS_ENV=production bundle exec rails assets:precompile
EOF

cat >> /etc/systemd/system/mastodon-web.service <<EOF
[Unit]
 Description=mastodon-web
 After=network.target

[Service]
 Type=simple
 User=mastodon
 WorkingDirectory=/home/mastodon/live
 Environment="RAILS_ENV=production"
 Environment="PORT=3000"
 ExecStart=/home/mastodon/.rbenv/shims/bundle exec puma -C config/puma.rb
 TimeoutSec=15
 Restart=always

[Install]
 WantedBy=multi-user.target
EOF

cat >> /etc/systemd/system/mastodon-sidekiq.service <<EOF
[Unit]
 Description=mastodon-sidekiq
 After=network.target

[Service]
 Type=simple
 User=mastodon
 WorkingDirectory=/home/mastodon/live
 Environment="RAILS_ENV=production"
 Environment="DB_POOL=5"
 ExecStart=/home/mastodon/.rbenv/shims/bundle exec sidekiq -c 5 -q default -q mailers -q pull -q push
 TimeoutSec=15
 Restart=always

[Install]
 WantedBy=multi-user.target
EOF

cat >> /etc/systemd/system/mastodon-streaming.service <<EOF
[Unit]
 Description=mastodon-streaming
 After=network.target

[Service]
 Type=simple
 User=mastodon
 WorkingDirectory=/home/mastodon/live
 Environment="NODE_ENV=production"
 Environment="PORT=4000"
 ExecStart=/usr/bin/npm run start
 TimeoutSec=15
 Restart=always

[Install]
 WantedBy=multi-user.target
EOF

systemctl enable /etc/systemd/system/mastodon-*.service

systemctl start mastodon-web.service mastodon-sidekiq.service mastodon-streaming.service
systemctl restart mastodon-web.service mastodon-sidekiq.service mastodon-streaming.service
systemctl status mastodon-web.service mastodon-sidekiq.service mastodon-streaming.service

echo
echo Installation du reverse proxy Nginx
echo
wget -O - https://nginx.org/keys/nginx_signing.key | apt-key add -
echo "deb http://nginx.org/packages/debian/ $(lsb_release -sc) nginx" > /etc/apt/sources.list.d/nginx.list
apt update
apt install nginx -y

cat >> /etc/nginx/conf.d/mastodon.conf << 'EOT' #TO CHANGE
map $http_upgrade $connection_upgrade {
 default upgrade;
 '' close;
}
server {
 listen 80;
 listen [::]:80;
 server_name www.mstdn.io mstdn.io;
 return 301 https://mstdn.io$request_uri;

 access_log /dev/null;
 error_log /dev/null;
}

server {
 listen 443 ssl http2;
 listen [::]:443 ssl http2;
 server_name www.mstdn.io mstdn.io;

 if ($host = www.mstdn.io) {
  return 301 https://mstdn.io$request_uri;
 }

 access_log /var/log/nginx/mstdn-access.log;
 error_log /var/log/nginx/mstdn-error.log;

 ssl_certificate /etc/letsencrypt/live/www.mstdn.io/fullchain.pem;
 ssl_certificate_key /etc/letsencrypt/live/www.mstdn.io/privkey.pem;
 ssl_protocols TLSv1.2;
 ssl_ciphers EECDH+AESGCM:EECDH+CHACHA20:EECDH+AES;
 ssl_prefer_server_ciphers on;
 add_header Strict-Transport-Security "max-age=15552000; preload";

 keepalive_timeout 70;
 sendfile on;
 client_max_body_size 0;
 gzip off;

 root /home/mastodon/live/public;

 location / {
  try_files $uri @proxy;
 }

 location @proxy {
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto https;
  proxy_pass_header Server;
  proxy_pass http://127.0.0.1:3000;
  proxy_buffering off;
  proxy_redirect off;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection $connection_upgrade;
  tcp_nodelay on;
 }

 location /api/v1/streaming {
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto https;
  proxy_pass http://127.0.0.1:4000;
  proxy_buffering off;
  proxy_redirect off;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection $connection_upgrade;
  tcp_nodelay on;
 }

 error_page 500 501 502 503 504 /500.html;
}
EOT
sed -i "s/mstdn.io/${domainwithtld}/g" /etc/nginx/conf.d/mastodon.conf
sed -i "s/mstdn-access/${domainwithtld}-access/g" /etc/nginx/conf.d/mastodon.conf
sed -i "s/mstdn-error/${domainwithtld}-error/g" /etc/nginx/conf.d/mastodon.conf

apt install -t jessie-backports letsencrypt --allow-unauthenticated -y
service nginx stop
letsencrypt certonly -d www.$domainwithtld -d $domainwithtld --agree-tos -m $email --rsa-key-size 4096 --standalone
service nginx start
echo
echo INSTALLATION FINISHED
echo YOU NEED TO BROWSE YOUR SERVER TO ADD YOUR ACCOUNT
echo After, we will activate your account as administator.
echo $mailgunlogin $mailgun $mailgunpwd $mailgunsender $mailgunsetup
echo "Need to add : "
echo "> cron"
echo "> admin part"
echo "> ..."
