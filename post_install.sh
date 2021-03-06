# Create user and set up the folders
pw useradd -n sickrage -c "bookstack" -s /sbin/nologin -w no
git clone https://github.com/BookStackApp/BookStack.git --branch release --single-branch /usr/local/bookstack

# Install dependencies
# pkg install -y git nginx openssl mariadb102-server php71 php71-tidy php71-tokenizer php71-openssl php71-pdo php71-mysqli php71-simplexml php71-mbstring

# Enable autostart for php, nginx and mysql
sysrc -f /etc/rc.conf nginx_enable="YES"
sysrc -f /etc/rc.conf mysql_enable="YES"
sysrc -f /etc/rc.conf php_fpm_enable="YES"

# Setup php-fpm
cp /usr/local/etc/php.ini-production /usr/local/etc/php.ini
sed -i '' -e 's?listen = 127.0.0.1:9000?listen = /var/run/php-fpm.sock?g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/;listen.owner = www/listen.owner = www/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/;listen.group = www/listen.group = www/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's/;listen.mode = 0660/listen.mode = 0600/g' /usr/local/etc/php-fpm.d/www.conf
sed -i '' -e 's?;cgi.fix_pathinfo=1?cgi.fix_pathinfo=0?g' /usr/local/etc/php.ini

# Start the service
service nginx start 2>/dev/null
service php-fpm start 2>/dev/null
service mysql-server start 2>/dev/null

# Configure mysql
mysql -u root <<-EOF
UPDATE mysql.user SET Password=PASSWORD('password') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
CREATE USER 'bookstack'@'localhost' IDENTIFIED BY 'password';
CREATE DATABASE bookstack character set UTF8mb4 collate utf8mb4_bin;
GRANT ALL PRIVILEGES ON *.* TO 'bookstack'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON bookstack.* TO 'bookstack'@'localhost';
FLUSH PRIVILEGES;
EOF

# Install composer
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'e0012edf3e80b6978849f5eff0d4b4e4c79ff1609dd1e613307e16318854d24ae64f26d17af3ef0bf7cfb710ca74755a') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
php -r "unlink('composer-setup.php');"

# Install bookstack
cd /usr/local/bookstack || exit
composer install
chown -R www:www /usr/local/bookstack
cp .env.example .env

# Update env
sed -i '' -e 's?DB_DATABASE=database_database?DB_DATABASE=bookstack?g' /usr/local/bookstack/.env
sed -i '' -e 's?DB_USERNAME=database_username?DB_USERNAME=bookstack?g' /usr/local/bookstack/.env
sed -i '' -e 's?DB_PASSWORD=database_user_password?DB_PASSWORD=password?g' /usr/local/bookstack/.env

# Regenerate key and intall tables
php artisan key:generate --force
php artisan migrate --force
