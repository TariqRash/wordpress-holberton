#!/bin/bash
################################################################################
# WordPress One-Click Installer for Holberton Sandbox
# Includes: Nginx, PHP, MySQL, SSL Support, Arabic Terminal Output
# Author: Tarik & Shaden
################################################################################

set -e  # Exit on any error

# ============================================================================
# تثبيت fribidi لدعم العربي في Terminal
# ============================================================================
install_arabic_support() {
    if ! command -v fribidi &> /dev/null; then
        apt-get update -qq 2>/dev/null
        apt-get install -y fribidi toilet figlet > /dev/null 2>&1
    fi
}

# ============================================================================
# دالة الطباعة بالعربي
# ============================================================================
print_ar() {
    if command -v fribidi &> /dev/null; then
        echo "$1" | fribidi --nobreak --charset=UTF-8
    else
        echo "$1"
    fi
}

print_colored() {
    local color=$1
    local text=$2
    case $color in
        green)  echo -e "\033[0;32m${text}\033[0m" ;;
        blue)   echo -e "\033[0;34m${text}\033[0m" ;;
        yellow) echo -e "\033[1;33m${text}\033[0m" ;;
        red)    echo -e "\033[0;31m${text}\033[0m" ;;
        cyan)   echo -e "\033[0;36m${text}\033[0m" ;;
        *)      echo "${text}" ;;
    esac
}

# ============================================================================
# Banner
# ============================================================================
show_banner() {
    clear
    if command -v figlet &> /dev/null; then
        figlet -f standard "WordPress" | while read line; do print_colored cyan "$line"; done
    fi
    print_colored blue "╔════════════════════════════════════════════════════════╗"
    print_colored blue "║                                                        ║"
    print_ar "║          مثبت WordPress الشامل - نسخة Holberton          ║"
    print_colored blue "║                                                        ║"
    print_colored blue "╚════════════════════════════════════════════════════════╝"
    echo ""
}

# ============================================================================
# اكتشاف معلومات السيرفر
# ============================================================================
detect_server_info() {
    print_ar "🔍 جاري اكتشاف معلومات السيرفر..."
    
    HOSTNAME=$(hostname)
    
    # اكتشاف رقم Sandbox تلقائياً
    if [[ $HOSTNAME =~ ([0-9]+-[0-9]+) ]]; then
        SANDBOX_NUM="${BASH_REMATCH[1]}"
        DOMAIN="https://${SANDBOX_NUM}.cod-us-east-1.hbtn.io"
        print_colored green "✓ تم اكتشاف الدومين: ${DOMAIN}"
    else
        IP=$(hostname -I | awk '{print $1}')
        DOMAIN="http://${IP}"
        print_colored yellow "⚠ سيتم استخدام IP: ${DOMAIN}"
    fi
    
    # تحديد web root
    if [ -d "/usr/out/vs/workbench/contrib/webview/browser/pre" ]; then
        WEB_ROOT="/usr/out/vs/workbench/contrib/webview/browser/pre"
    elif [ -d "/var/www/html" ]; then
        WEB_ROOT="/var/www/html"
    elif [ -d "/usr/share/nginx/html" ]; then
        WEB_ROOT="/usr/share/nginx/html"
    else
        WEB_ROOT="/var/www/html"
        mkdir -p ${WEB_ROOT}
    fi
    
    print_colored green "✓ مجلد الويب: ${WEB_ROOT}"
    echo ""
}

# ============================================================================
# إعداد البيئة
# ============================================================================
prepare_environment() {
    print_ar "🔧 جاري إعداد البيئة..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    # إيقاف الخدمات المتعارضة على البورت 8080 (لعدم إيقاف Terminal)
    fuser -k 8080/tcp 2>/dev/null || true
    
    print_colored green "✓ تم إعداد البيئة"
    echo ""
}

# ============================================================================
# تثبيت الحزم المطلوبة
# ============================================================================
install_packages() {
    print_ar "📦 جاري تثبيت الحزم المطلوبة..."
    print_ar "   (قد يستغرق 2-3 دقائق)"
    echo ""
    
    # تحديث النظام
    print_ar "   → تحديث قوائم الحزم..."
    apt-get update -qq > /dev/null 2>&1
    print_colored green "   ✓ تم"
    
    # تثبيت Nginx
    print_ar "   → تثبيت Nginx..."
    apt-get install -y nginx -qq > /dev/null 2>&1
    print_colored green "   ✓ تم"
    
    # تثبيت PHP
    print_ar "   → تثبيت PHP وملحقاته..."
    apt-get install -y \
        php-fpm \
        php-mysql \
        php-curl \
        php-gd \
        php-mbstring \
        php-xml \
        php-xmlrpc \
        php-zip \
        php-intl \
        -qq > /dev/null 2>&1
    print_colored green "   ✓ تم"
    
    # تثبيت MySQL
    print_ar "   → تثبيت MySQL..."
    apt-get install -y mysql-server -qq > /dev/null 2>&1
    print_colored green "   ✓ تم"
    
    # تثبيت Git
    print_ar "   → تثبيت Git..."
    apt-get install -y git curl wget -qq > /dev/null 2>&1
    print_colored green "   ✓ تم"
    
    print_colored green "✓ تم تثبيت جميع الحزم بنجاح"
    echo ""
}

# ============================================================================
# إعداد قاعدة البيانات
# ============================================================================
setup_database() {
    print_ar "🗄️ جاري إعداد قاعدة البيانات..."
    
    DB_NAME="wordpress"
    DB_USER="wpuser"
    DB_PASS="wppassword"
    
    # إنشاء قاعدة البيانات
    mysql -e "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null || true
    mysql -e "CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    
    # إنشاء المستخدم
    mysql -e "DROP USER IF EXISTS '${DB_USER}'@'localhost';" 2>/dev/null || true
    mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
    
    # منح الصلاحيات
    mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
    
    print_colored green "✓ تم إعداد قاعدة البيانات"
    echo ""
}

# ============================================================================
# تنزيل WordPress
# ============================================================================
download_wordpress() {
    print_ar "⬇️ جاري تنزيل WordPress من GitHub..."
    
    cd /tmp
    rm -rf WordPress 2>/dev/null || true
    
    git clone --depth 1 --quiet https://github.com/WordPress/WordPress.git 2>/dev/null
    
    print_colored green "✓ تم تنزيل WordPress"
    echo ""
}

# ============================================================================
# تثبيت WordPress
# ============================================================================
install_wordpress() {
    print_ar "📋 جاري تثبيت WordPress..."
    
    # تنظيف المجلد
    rm -rf ${WEB_ROOT}/* 2>/dev/null || true
    
    # نسخ الملفات
    cp -r /tmp/WordPress/* ${WEB_ROOT}/
    
    # إعداد wp-config.php
    cp ${WEB_ROOT}/wp-config-sample.php ${WEB_ROOT}/wp-config.php
    
    sed -i "s/database_name_here/${DB_NAME}/" ${WEB_ROOT}/wp-config.php
    sed -i "s/username_here/${DB_USER}/" ${WEB_ROOT}/wp-config.php
    sed -i "s/password_here/${DB_PASS}/" ${WEB_ROOT}/wp-config.php
    
    # إضافة Security Keys
    SALT=$(curl -sL https://api.wordpress.org/secret-key/1.1/salt/)
    cat > /tmp/salt.txt << EOF
$SALT
EOF
    
    sed -i "/put your unique phrase here/r /tmp/salt.txt" ${WEB_ROOT}/wp-config.php
    sed -i "/put your unique phrase here/d" ${WEB_ROOT}/wp-config.php
    
    # ضبط الصلاحيات
    chown -R www-data:www-data ${WEB_ROOT}
    chmod -R 755 ${WEB_ROOT}
    
    # تنظيف
    rm -rf /tmp/WordPress /tmp/salt.txt
    
    print_colored green "✓ تم تثبيت WordPress"
    echo ""
}

# ============================================================================
# إعداد Nginx
# ============================================================================
setup_nginx() {
    print_ar "🌐 جاري إعداد Nginx..."
    
    # اكتشاف PHP socket
    PHP_SOCKET=$(ls /run/php/php*-fpm.sock 2>/dev/null | head -1)
    
    if [ -z "$PHP_SOCKET" ]; then
        PHP_SOCKET="/run/php/php-fpm.sock"
    fi
    
    # إنشاء إعدادات Nginx
    cat > /etc/nginx/sites-available/wordpress << 'NGINX_EOF'
server {
    listen 8080 default_server;
    listen [::]:8080 default_server;
    
    root WEB_ROOT_PLACEHOLDER;
    index index.php index.html index.htm;
    
    server_name _;
    
    # WordPress Permalinks
    location / {
        try_files $uri $uri/ /index.php?$args;
    }
    
    # PHP Processing
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:PHP_SOCKET_PLACEHOLDER;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    # Deny access to .htaccess files
    location ~ /\.ht {
        deny all;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
NGINX_EOF
    
    # استبدال المتغيرات
    sed -i "s|WEB_ROOT_PLACEHOLDER|${WEB_ROOT}|g" /etc/nginx/sites-available/wordpress
    sed -i "s|PHP_SOCKET_PLACEHOLDER|${PHP_SOCKET}|g" /etc/nginx/sites-available/wordpress
    
    # تفعيل الموقع
    ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
    
    # اختبار الإعدادات
    nginx -t > /dev/null 2>&1
    
    print_colored green "✓ تم إعداد Nginx"
    echo ""
}

# ============================================================================
# تشغيل الخدمات
# ============================================================================
start_services() {
    print_ar "🚀 جاري تشغيل الخدمات..."
    
    # تشغيل PHP-FPM
    systemctl start php*-fpm > /dev/null 2>&1
    systemctl enable php*-fpm > /dev/null 2>&1
    
    # تشغيل Nginx
    systemctl restart nginx
    systemctl enable nginx > /dev/null 2>&1
    
    # تشغيل MySQL
    systemctl start mysql > /dev/null 2>&1
    systemctl enable mysql > /dev/null 2>&1
    
    print_colored green "✓ تم تشغيل جميع الخدمات"
    echo ""
}

# ============================================================================
# عرض النتائج
# ============================================================================
show_results() {
    clear
    
    # Banner نهائي
    if command -v toilet &> /dev/null; then
        toilet -f standard "SUCCESS!" --gay
    else
        print_colored green "╔════════════════════════════════════════════════════════╗"
        print_colored green "║                                                        ║"
        print_colored green "║                ✅  نجح التثبيت!  ✅                     ║"
        print_colored green "║                                                        ║"
        print_colored green "╔════════════════════════════════════════════════════════╗"
    fi
    
    echo ""
    print_colored blue "╔════════════════════════════════════════════════════════╗"
    print_colored blue "║                                                        ║"
    print_ar "║              تم تثبيت WordPress بنجاح! 🎉               ║"
    print_colored blue "║                                                        ║"
    print_colored blue "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    print_ar "🌐 رابط الموقع:"
    print_colored cyan "   ${DOMAIN}:8080"
    echo ""
    
    print_ar "📁 مجلد التثبيت:"
    print_colored cyan "   ${WEB_ROOT}"
    echo ""
    
    print_ar "📊 معلومات قاعدة البيانات:"
    echo "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_colored yellow "   اسم القاعدة:       ${DB_NAME}"
    print_colored yellow "   اسم المستخدم:      ${DB_USER}"
    print_colored yellow "   كلمة المرور:       ${DB_PASS}"
    print_colored yellow "   المضيف:            localhost"
    print_colored yellow "   بادئة الجداول:     wp_"
    echo ""
    
    print_ar "🎯 الخطوات التالية:"
    echo "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_ar "   1. افتح الرابط أعلاه في المتصفح"
    print_ar "   2. اختر اللغة العربية"
    print_ar "   3. املأ معلومات الموقع (العنوان، اسم المستخدم، كلمة المرور)"
    print_ar "   4. بعد التثبيت، اذهب إلى الإضافات (Plugins)"
    print_ar "   5. ثبّت Elementor Page Builder"
    print_ar "   6. ابدأ بتصميم موقعك!"
    echo ""
    
    print_ar "🔒 معلومات الأمان:"
    echo "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ $DOMAIN == https://* ]]; then
        print_colored green "   ✓ HTTPS مفعّل تلقائياً (من Holberton)"
    else
        print_colored yellow "   ⚠ HTTPS غير متوفر (استخدام IP مباشر)"
    fi
    echo ""
    
    print_ar "💡 نصائح إضافية:"
    echo "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_ar "   • احفظ معلومات قاعدة البيانات في مكان آمن"
    print_ar "   • غيّر كلمة مرور المشرف بعد التثبيت"
    print_ar "   • ثبّت إضافات الأمان (مثل Wordfence)"
    print_ar "   • عمل نسخة احتياطية دورية"
    echo ""
    
    print_colored red "⏰ تذكير هام:"
    print_ar "   Sandbox ينتهي بعد ساعتين - لا تنسَ التمديد!"
    echo ""
    
    print_colored blue "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    # حفظ المعلومات في ملف
    cat > ~/wordpress-info.txt << INFO_EOF
╔════════════════════════════════════════════════════════╗
║           معلومات تثبيت WordPress                      ║
╚════════════════════════════════════════════════════════╝

🌐 رابط الموقع:
   ${DOMAIN}:8080

📊 قاعدة البيانات:
   الاسم:         ${DB_NAME}
   المستخدم:      ${DB_USER}
   كلمة المرور:   ${DB_PASS}
   المضيف:        localhost

📁 المسار:
   ${WEB_ROOT}

⏰ تاريخ التثبيت:
   $(date '+%Y-%m-%d %H:%M:%S')

════════════════════════════════════════════════════════
INFO_EOF
    
    print_colored green "💾 تم حفظ المعلومات في: ~/wordpress-info.txt"
    echo ""
}

# ============================================================================
# Main Function
# ============================================================================
main() {
    # التحقق من صلاحيات root
    if [ "$EUID" -ne 0 ]; then 
        echo "الرجاء تشغيل السكريبت بصلاحيات root:"
        echo "sudo bash $0"
        exit 1
    fi
    
    # تثبيت دعم العربي
    install_arabic_support
    
    # عرض البانر
    show_banner
    
    # تنفيذ الخطوات
    detect_server_info
    prepare_environment
    install_packages
    setup_database
    download_wordpress
    install_wordpress
    setup_nginx
    start_services
    show_results
}

# تشغيل السكريبت
main "$@"