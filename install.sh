#!/bin/bash
set -e

clear
echo "╔════════════════════════════════════════╗"
echo "║   WordPress Installer - Holberton      ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Detect info
echo "→ Detecting server info..."
HOSTNAME=$(hostname)
if [[ $HOSTNAME =~ ([0-9]+-[0-9]+) ]]; then
    DOMAIN="https://${BASH_REMATCH[1]}.cod-us-east-1.hbtn.io"
else
    DOMAIN="http://$(hostname -I | awk '{print $1}')"
fi
echo "✓ Domain: ${DOMAIN}"

WEB_ROOT="/var/www/html"
mkdir -p $WEB_ROOT
echo "✓ Web root: ${WEB_ROOT}"
echo ""

# Install packages (already done based on your output)
echo "→ Checking packages..."
if ! command -v nginx &> /dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y nginx php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip mysql-server git -qq
fi
echo "✓ Packages ready"
echo ""

# Start MySQL manually
echo "→ Starting MySQL..."
if ! pgrep -x mysqld > /dev/null; then
    mkdir -p /run/mysqld
    chown mysql:mysql /run/mysqld
    /usr/sbin/mysqld --daemonize --pid-file=/run/mysqld/mysqld.pid --user=mysql 2>/dev/null || true
    sleep 3
fi
echo "✓ MySQL running"
echo ""

# Database setup
echo "→ Setting up database..."
DB_NAME="wordpress"
DB_USER="wpuser"
DB_PASS="wppassword"

mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" 2>/dev/null
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';" 2>/dev/null
mysql -e "FLUSH PRIVILEGES;" 2>/dev/null
echo "✓ Database ready"
echo ""

# Download WordPress
echo "→ Downloading WordPress..."
if [ ! -d "/tmp/WordPress" ]; then
    cd /tmp && rm -rf WordPress
    git clone --depth 1 -q https://github.com/WordPress/WordPress.git
fi
echo "✓ Downloaded"
echo ""

# Install WordPress
echo "→ Installing WordPress..."
rm -rf ${WEB_ROOT}/*
cp -r /tmp/WordPress/* ${WEB_ROOT}/
cp ${WEB_ROOT}/wp-config-sample.php ${WEB_ROOT}/wp-config.php
sed -i "s/database_name_here/${DB_NAME}/; s/username_here/${DB_USER}/; s/password_here/${DB_PASS}/" ${WEB_ROOT}/wp-config.php

# Security keys
SALT=$(curl -sL https://api.wordpress.org/secret-key/1.1/salt/)
echo "$SALT" > /tmp/salt.txt
sed -i "/put your unique phrase here/r /tmp/salt.txt" ${WEB_ROOT}/wp-config.php
sed -i "/put your unique phrase here/d" ${WEB_ROOT}/wp-config.php

chown -R www-data:www-data ${WEB_ROOT}
chmod -R 755 ${WEB_ROOT}
rm -rf /tmp/WordPress /tmp/salt.txt
echo "✓ WordPress installed"
echo ""

# Start PHP-FPM
echo "→ Starting PHP-FPM..."
if ! pgrep -x php-fpm > /dev/null; then
    /usr/sbin/php-fpm8.1 --daemonize 2>/dev/null || /usr/sbin/php-fpm --daemonize 2>/dev/null || true
    sleep 2
fi
echo "✓ PHP-FPM running"
echo ""

# Configure Nginx
echo "→ Configuring Nginx..."
PHP_SOCKET=$(ls /run/php/php*-fpm.sock 2>/dev/null | head -1)

cat > /etc/nginx/sites-available/default << NGINX_CONF
server {
    listen 8080 default_server;
    listen [::]:8080 default_server;
    
    root ${WEB_ROOT};
    index index.php index.html index.htm;
    
    server_name _;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_SOCKET};
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
NGINX_CONF

nginx -t > /dev/null 2>&1
echo "✓ Nginx configured"
echo ""

# Start Nginx
echo "→ Starting Nginx..."
if pgrep -x nginx > /dev/null; then
    nginx -s reload 2>/dev/null || true
else
    nginx 2>/dev/null || true
fi
sleep 1
echo "✓ Nginx running"
echo ""

# Verify services
echo "→ Verifying services..."
SERVICES_OK=true

if ! pgrep -x mysqld > /dev/null; then
    echo "  ⚠ MySQL not running"
    SERVICES_OK=false
else
    echo "  ✓ MySQL: OK"
fi

if ! pgrep -x php-fpm > /dev/null; then
    echo "  ⚠ PHP-FPM not running"
    SERVICES_OK=false
else
    echo "  ✓ PHP-FPM: OK"
fi

if ! pgrep -x nginx > /dev/null; then
    echo "  ⚠ Nginx not running"
    SERVICES_OK=false
else
    echo "  ✓ Nginx: OK"
fi

echo ""

# Results
clear
echo "╔════════════════════════════════════════╗"
echo "║         ✅  INSTALLATION COMPLETE!    ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "🌐 WordPress URL:"
echo "   ${DOMAIN}:8080"
echo ""
echo "📊 Database Credentials:"
echo "   Database: ${DB_NAME}"
echo "   Username: ${DB_USER}"
echo "   Password: ${DB_PASS}"
echo "   Host:     localhost"
echo ""
echo "🎯 Next Steps:"
echo "   1. Open ${DOMAIN}:8080 in your browser"
echo "   2. Select language (Arabic)"
echo "   3. Complete WordPress installation"
echo "   4. Install Elementor from Plugins"
echo ""

if [ "$SERVICES_OK" = false ]; then
    echo "⚠️  Some services need manual start:"
    echo ""
    echo "If MySQL not running:"
    echo "  sudo /usr/sbin/mysqld --daemonize --pid-file=/run/mysqld/mysqld.pid"
    echo ""
    echo "If PHP-FPM not running:"
    echo "  sudo /usr/sbin/php-fpm8.1 --daemonize"
    echo ""
    echo "If Nginx not running:"
    echo "  sudo nginx"
    echo ""
fi

# Save info
cat > ~/wordpress-info.txt << INFO
WordPress Installation Info
============================
URL: ${DOMAIN}:8080
Database: ${DB_NAME}
Username: ${DB_USER}
Password: ${DB_PASS}
Host: localhost
Web Root: ${WEB_ROOT}
Installation Date: $(date)

Manual Service Start Commands:
-------------------------------
MySQL:   sudo /usr/sbin/mysqld --daemonize --pid-file=/run/mysqld/mysqld.pid
PHP-FPM: sudo /usr/sbin/php-fpm8.1 --daemonize
Nginx:   sudo nginx

Check Services:
---------------
ps aux | grep -E 'mysql|php-fpm|nginx' | grep -v grep
INFO

echo "💾 Installation info saved to: ~/wordpress-info.txt"
echo ""
echo "Run this to check services:"
echo "  ps aux | grep -E 'mysql|php-fpm|nginx' | grep -v grep"
echo ""