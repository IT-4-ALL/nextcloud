#!/bin/bash

# Simple ASCII art pattern for a cloud
echo "#############################################################"
echo "############### Nextcloud Installation #####################"
echo "#############################################################"
echo ""

# Function to prompt for the master password and confirm it
function prompt_password {
    echo "Press Ctrl + C to exit."
    echo "Please enter the master password (minimum 8 characters):"
    read -s MASTER_PASSWORD

    # Check if the password is at least 8 characters long
    if [ ${#MASTER_PASSWORD} -lt 8 ]; then
        echo "Password must be at least 8 characters long. Please try again."
        return 1
    fi

    echo "Please confirm the master password:"
    read -s MASTER_PASSWORD_CONFIRM

    if [ "$MASTER_PASSWORD" != "$MASTER_PASSWORD_CONFIRM" ]; then
        echo "Passwords do not match. Please try again."
        return 1
    fi

    echo "The master password has been successfully recorded."
    return 0
}

# Loop until the passwords match and meet the length requirement
while ! prompt_password; do
    # Passwords do not match or are too short; prompt again
    echo "Please re-enter your password."
done

# Continue with the installation process
echo "Proceeding with Nextcloud installation..."

# Update the package list
echo "Updating package list..."
sudo apt update

# Install necessary packages
echo "Installing necessary packages..."
sudo apt install -y unzip wget apache2 php libapache2-mod-php php-mysql php-xml php-curl php-mbstring php-zip php-gd php-intl php-imagick php-bcmath php-json mariadb-server expect

# Secure MariaDB installation
echo "Securing MariaDB installation..."
sudo tee /tmp/mariadb_secure.sh > /dev/null <<EOL
#!/usr/bin/expect -f

set timeout 10
spawn sudo mysql_secure_installation

# Handle the prompts
expect "Enter current password for root (enter for none):"
send "\r"  # Assuming no password is set initially

expect "Switch to unix_socket authentication [Y/n]"
send "n\r"

expect "Change the root password? [Y/n]"
send "N\r"

expect "New password:"
send "$env(MASTER_PASSWORD)\r"

expect "Re-enter new password:"
send "$env(MASTER_PASSWORD)\r"

expect "Remove anonymous users? [Y/n]"
send "Y\r"

expect "Disallow root login remotely? [Y/n]"
send "Y\r"

expect "Remove test database and access to it? [Y/n]"
send "Y\r"

expect "Reload privilege tables now? [Y/n]"
send "Y\r"

interact
EOL

# Make the Expect script executable and run it
sudo chmod +x /tmp/mariadb_secure.sh
sudo /tmp/mariadb_secure.sh

# Remove the Expect script
rm /tmp/mariadb_secure.sh

# Setup Nextcloud database
echo "Setting up Nextcloud database..."
echo "Setting up Nextcloud database..."
sudo mysql -u root -p"$MASTER_PASSWORD" -e "FLUSH PRIVILEGES;"
sudo mysql -u root -p"$MASTER_PASSWORD" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MASTER_PASSWORD';"
sudo mysql -u root -p"$MASTER_PASSWORD" -e "CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
sudo mysql -u root -p"$MASTER_PASSWORD" -e "FLUSH PRIVILEGES;"

echo "Nextcloud DATABASE installation setup is complete."

cd
cd /var/www
sudo wget https://download.nextcloud.com/server/releases/latest.zip
sudo unzip latest.zip
rm latest.zip
cd
sudo chown -R www-data:www-data /var/www/nextcloud
sudo chmod -R 755 /var/www/nextcloud


echo "Write apache config"

sudo tee /etc/apache2/sites-available/nextcloud.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerAdmin admin@example.com
    DocumentRoot /var/www/nextcloud
    ServerName example.com
    
    <Directory /var/www/nextcloud/>
        Options +FollowSymlinks
        AllowOverride All
        <IfModule mod_dav.c>
            Dav off
        </IfModule>
        SetEnv HOME /var/www/nextcloud
        SetEnv HTTP_HOME /var/www/nextcloud
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF


sudo a2ensite nextcloud.conf
sudo a2dissite 000-default.conf
sudo a2enmod rewrite headers env dir mime
echo "Apache2 reboot"
sudo systemctl restart apache2
echo "Success"
echo "##################################################################"
echo "Database User: root"
echo "Database Password: $MASTER_PASSWORD" 
echo "Database Name: nextcloud"
echo "Database Location: localhost"
echo "##################################################################"
