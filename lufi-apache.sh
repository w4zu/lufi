#!/bin/bash
# lufi-install : installation de LUFI en moteur SQLite
# License : Creative Commons http://creativecommons.org/licenses/by-nd/4.0/deed.fr
# Website : http://blogmotion.fr 
#
# LUFI : https://git.framasoft.org/fiat-tux/hat-softwares/lufi 
#        https://framapiaf.org/@framasky
#		 https://fiat-tux.fr/2018/10/30/lufi-0-03-est-sorti/
# Modifier par @w4zu pour apache 2.4   
#set -xe
VERSION="lufi-apache-v1.0"

# VARIABLES A MODIFIER
domaine="lufi.yourdomain.net"
WWW="/home/lufi"
# VARIABLES
blanc="\033[1;37m"
gris="\033[0;37m"
magenta="\033[0;35m"
rouge="\033[1;31m"
vert="\033[1;32m"
jaune="\033[1;33m"
bleu="\033[1;34m"
rescolor="\033[0m"
cronlufi="/etc/cron.d/lufi"
# DEBUT DU SCRIPT
echo -e "$vert"
echo -e "#########################################################"
echo -e "#                                                       #"
echo -e "#          Script d'installation de LUFI 1.0            #"
echo -e "#                avec le moteur SQLite                  #"
echo -e "#                                                       #"
echo -e "#              Testé sur Debian 9.8 x64                 #"
echo -e "#                      by @xhark                        #"
echo -e "#           Modifier par @w4zu Pour apache 2.4          #"
echo -e "#                                                       #"
echo -e "#########################################################"
echo -e "                     $VERSION"
echo -e "$rescolor\n\n"
sleep 3

if [ "$UID" -ne "0" ]
then
	echo -e "\n${jaune}\tRun this script as root.$rescolor \n\n"
	exit 1
fi

echo -e "\n${jaune}Installation des dependances...${rescolor}"
apt-get install -y build-essential git libssl-dev cpanminus
mkdir -p $WWW
cd $WWW

echo -e "\n${jaune}Git clone...${rescolor}" && sleep 1
git clone https://framagit.org/fiat-tux/hat-softwares/lufi.git

echo -e "\n${jaune}cpan Carton...${rescolor}" && sleep 1
cpanm Carton
cd lufi 

echo -e "\n${jaune}Carton install...${rescolor}" && sleep 1
carton install --deployment --without=test --without=postgresql --without=mysql --without=ldap --without=htpasswd
cp lufi.conf.template lufi.conf

echo -e "\n${jaune}Configuration lufi.conf...${rescolor}" && sleep 1
sed -i 's|#proxy|proxy|' "$WWW/lufi/lufi.conf"
sed -i 's|#contact|contact|' "$WWW/lufi/lufi.conf"
sed -i 's|#report|report|' "$WWW/lufi/lufi.conf"
sed -i 's|#max_file_size|max_file_size|' "$WWW/lufi/lufi.conf"

echo -e "${jaune}Configuration du vhost Apache...${rescolor}" && sleep 1
cat << EOF > /etc/apache2/sites-available/$domaine.conf
<VirtualHost $domaine:443>
    ServerAdmin postmaster@$domaine
    ServerName $domaine 

    CustomLog  /var/log/apache2/lufi.access.log combined
    ErrorLog /var/log/apache2/lufi.error.log
    LogLevel warn

    # HTTPS only header, improves security
    Header always set Strict-Transport-Security "max-age=63072000; preload"

    # Lufi
    ProxyPreserveHost On
    ProxyRequests off
    RewriteEngine On
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    
    # Adapt this to your configuration
    RewriteRule ^/(.*) ws://127.0.0.1:8081/$1 [P,L]
    # HTTPS only, use instead of the above line (note the "wss" instead of "ws")
    #RewriteRule ^/lufi/(.*) wss://127.0.0.1:8081/$1 [P,L]

    RequestHeader unset X-Forwarded-Proto
    RequestHeader add X-Remote-Port %{R_P}e
    # HTTPS only, but won't be used if you use HTTP. You can leave it.
    RequestHeader set X-Forwarded-Proto https env=HTTPS

    <Location />
        # Adapt this to your configuration
        ProxyPass http://127.0.0.1:8081/
        ProxyPassReverse /
        LimitRequestBody 104857600
    </Location>

#SSLCertificateFile /etc/letsencrypt/live/ourcertif/fullchain.pem
#SSLCertificateKeyFile /etc/letsencrypt/live/ourcertif/privkey.pem

</VirtualHost>

EOF

a2ensite $domaine.conf

echo -e "\n${jaune}Permissions www-data...${rescolor}" && sleep 1
chown -R www-data:www-data $WWW/lufi

echo -e "\n${jaune}Config et restart des services...${rescolor}" && sleep 1
cp utilities/lufi.service /etc/systemd/system
sed -i "s|/var/www/lufi|${WWW}/lufi|" /etc/systemd/system/lufi.service
systemctl daemon-reload 
systemctl enable lufi.service
systemctl start lufi.service
/etc/init.d/apache2 restart
# ADD crontab
if [ -f "$cronlufi" ]
then 
    echo "crontab OK"
else
    echo "0 1 * * * cd $WWW/lufi && carton exec script/lufi cron cleanfiles --mode production" >> /etc/cron.d/lufi
fi
echo -e "\n\n${magenta} --- FIN DU SCRIPT (v${VERSION})---\n${rescolor}"
echo -e "Merci de modifier les variables  par défaut 'contact', 'report' et 'secrets' dans \n $WWW/lufi/lufi.conf"
echo -e "Merci d'ajouter un certificat dans votre vhost ou d'en générer un via let's encrypt"
exit 0
