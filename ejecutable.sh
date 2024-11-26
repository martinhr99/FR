#!/bin/bash

# Variables generales
DOMAIN1="midominio1.com"
DOMAIN2="midominio2.com"
SECURE_DOMAIN="frpracticahttps.com"

echo "== Instalando Apache2 =="
sudo apt update
sudo apt install -y apache2 openssl

echo "== Habilitando y verificando servicio Apache2 =="
sudo systemctl enable apache2
sudo systemctl start apache2
sudo systemctl status apache2

echo "== Configurando página inicial de Apache2 =="
echo "<h1>Página inicial del servidor</h1>" | sudo tee /var/www/html/index.html

echo "== Configurando Hosts Virtuales =="
# Crear directorios raíz para cada host virtual
sudo mkdir -p /var/www/$DOMAIN1 /var/www/$DOMAIN2
echo "<h1>Bienvenido a $DOMAIN1</h1>" | sudo tee /var/www/$DOMAIN1/index.html
echo "<h1>Bienvenido a $DOMAIN2</h1>" | sudo tee /var/www/$DOMAIN2/index.html

# Cambiar propietario
sudo chown -R www-data:www-data /var/www/$DOMAIN1 /var/www/$DOMAIN2

# Configurar archivos para hosts virtuales
sudo tee /etc/apache2/sites-available/$DOMAIN1.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN1
    DocumentRoot /var/www/$DOMAIN1
</VirtualHost>
EOF

sudo tee /etc/apache2/sites-available/$DOMAIN2.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN2
    DocumentRoot /var/www/$DOMAIN2
</VirtualHost>
EOF

# Activar hosts virtuales
sudo a2ensite $DOMAIN1.conf
sudo a2ensite $DOMAIN2.conf

# Reiniciar Apache2
sudo systemctl reload apache2

echo "== Configurando acceso restringido =="
# Crear directorio protegido
sudo mkdir -p /var/www/$DOMAIN1/restringida
echo "<h1>Zona restringida</h1>" | sudo tee /var/www/$DOMAIN1/restringida/index.html

# Crear archivo de contraseñas
sudo htpasswd -c /usr/local/passwords admin <<EOF
1234
EOF

# Configurar acceso restringido con .htaccess
sudo tee /var/www/$DOMAIN1/restringida/.htaccess <<EOF
AuthType Basic
AuthName "Zona restringida"
AuthUserFile /usr/local/passwords
Require valid-user
EOF

# Permitir uso de .htaccess
sudo sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

# Reiniciar Apache2
sudo systemctl reload apache2

echo "== Configurando HTTPS con un certificado autofirmado =="
# Crear directorio para host seguro
sudo mkdir -p /var/www/$SECURE_DOMAIN
echo "<h1>FR HTTPS</h1>" | sudo tee /var/www/$SECURE_DOMAIN/index.html

# Generar certificado SSL autofirmado
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/$SECURE_DOMAIN.key \
  -out /etc/ssl/certs/$SECURE_DOMAIN.crt \
  -subj "/C=ES/ST=Granada/L=Granada/O=UGR/OU=DTSTC/CN=$SECURE_DOMAIN"

# Configurar host virtual para HTTPS
sudo tee /etc/apache2/sites-available/$SECURE_DOMAIN.conf <<EOF
<VirtualHost *:443>
    ServerName $SECURE_DOMAIN
    DocumentRoot /var/www/$SECURE_DOMAIN

    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/$SECURE_DOMAIN.crt
    SSLCertificateKeyFile /etc/ssl/private/$SECURE_DOMAIN.key
</VirtualHost>
EOF

# Activar módulo SSL y host virtual
sudo a2enmod ssl
sudo a2ensite $SECURE_DOMAIN.conf

# Reiniciar Apache2
sudo systemctl reload apache2

echo "== Agregando dominios a /etc/hosts para pruebas locales =="
sudo tee -a /etc/hosts <<EOF
127.0.0.1 $DOMAIN1
127.0.0.1 $DOMAIN2
127.0.0.1 $SECURE_DOMAIN
EOF

echo "== Configuración completa. Pruebe accediendo a: =="
echo "  http://$DOMAIN1"
echo "  http://$DOMAIN2"
echo "  https://$SECURE_DOMAIN (acepte el certificado no confiable)"
