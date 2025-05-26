#!/bin/bash

#############################################################################
# Enhanced LAMP Stack Setup Script
#
# Original Script: https://github.com/sohag-pro/SingleCommand
# Original Author: @sohag-pro
#
# This is an enhanced fork with additional features:
# - Supervisor integration for Laravel queues
# - Comprehensive permission management
# - Redis support
# - Laravel optimization
# - Production-ready configurations
#
# Fork Repository: https://github.com/theihasan/laravel-server-setup
#############################################################################

# Function to display error messages
error_exit() {
    echo "$1" >&2
    exit 1
}

# Function to prompt for user confirmation
confirm() {
    read -r -p "${1:-Are you sure?} [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            true
            ;;
        *)
            false
            ;;
    esac
}

# Function to select PHP version
select_php_version() {
    echo "Available PHP versions:"
    echo "1) PHP 7.4"
    echo "2) PHP 8.0"
    echo "3) PHP 8.1"
    echo "4) PHP 8.2"
    echo "5) PHP 8.3"
    echo "6) PHP 8.4"
    read -p "Select PHP version (1-6): " php_choice

    case $php_choice in
        1) PHP_VERSION="7.4" ;;
        2) PHP_VERSION="8.0" ;;
        3) PHP_VERSION="8.1" ;;
        4) PHP_VERSION="8.2" ;;
        5) PHP_VERSION="8.3" ;;
        6) PHP_VERSION="8.4" ;;
        *) error_exit "Invalid PHP version selected" ;;
    esac
    echo "Selected PHP version: $PHP_VERSION"
}

# Function to select database type
select_database() {
    echo "Available database systems:"
    echo "1) MySQL (default)"
    echo "2) PostgreSQL"
    read -p "Select database system (1-2, default: 1): " db_choice
    db_choice=${db_choice:-1}

    case $db_choice in
        1)
            DB_TYPE="mysql"
            echo "Selected database: MySQL"
            ;;
        2)
            DB_TYPE="postgresql"
            echo "Selected database: PostgreSQL"
            ;;
        *)
            error_exit "Invalid database selection"
            ;;
    esac
}

# Function to prompt for database credentials
get_database_credentials() {
    if [ "$DB_TYPE" = "mysql" ]; then
        read -p "Enter MySQL username (default: admin): " DB_USER
        DB_USER=${DB_USER:-admin}

        read -s -p "Enter MySQL password: " DB_PASS
        echo

        read -p "Enter database name (default: mydatabase): " DB_NAME
        DB_NAME=${DB_NAME:-mydatabase}
    else
        read -p "Enter PostgreSQL username (default: postgres): " DB_USER
        DB_USER=${DB_USER:-postgres}

        read -s -p "Enter PostgreSQL password: " DB_PASS
        echo

        read -p "Enter database name (default: mydatabase): " DB_NAME
        DB_NAME=${DB_NAME:-mydatabase}
    fi
}

# Function to set comprehensive permissions
set_project_permissions() {
    local project_path="/var/www/html/$REPO_NAME"

    echo "Setting comprehensive permissions for Laravel project..."

    # Set ownership to www-data
    sudo chown -R www-data:www-data "$project_path"

    # Set directory permissions
    sudo find "$project_path" -type d -exec chmod 755 {} \;

    # Set file permissions
    sudo find "$project_path" -type f -exec chmod 644 {} \;

    # Set executable permissions for artisan
    sudo chmod +x "$project_path/artisan"

    # Set special permissions for storage and bootstrap/cache
    sudo chmod -R 775 "$project_path/storage"
    sudo chmod -R 775 "$project_path/bootstrap/cache"

    # Ensure proper ownership for writable directories
    sudo chown -R www-data:www-data "$project_path/storage"
    sudo chown -R www-data:www-data "$project_path/bootstrap/cache"

    # Set permissions for log files
    if [ -d "$project_path/storage/logs" ]; then
        sudo chmod -R 775 "$project_path/storage/logs"
        sudo chown -R www-data:www-data "$project_path/storage/logs"
    fi

    # Create public uploads directory if it doesn't exist and set permissions
    if [ ! -d "$project_path/public/uploads" ]; then
        sudo mkdir -p "$project_path/public/uploads"
    fi
    sudo chmod -R 775 "$project_path/public/uploads"
    sudo chown -R www-data:www-data "$project_path/public/uploads"

    # Set ACL permissions for better compatibility
    if command -v setfacl &> /dev/null; then
        sudo setfacl -R -m u:www-data:rwx "$project_path/storage"
        sudo setfacl -R -m u:www-data:rwx "$project_path/bootstrap/cache"
        sudo setfacl -R -d -m u:www-data:rwx "$project_path/storage"
        sudo setfacl -R -d -m u:www-data:rwx "$project_path/bootstrap/cache"
    fi

    echo "Permissions set successfully!"
}

# Function to install and configure Supervisor
install_supervisor() {
    echo "Installing Supervisor..."
    sudo apt install -y supervisor || error_exit "Failed to install Supervisor"

    # Enable and start supervisor
    sudo systemctl enable supervisor
    sudo systemctl start supervisor

    echo "Supervisor installed and started successfully!"
}

# Function to create Laravel queue configuration for Supervisor
create_queue_config() {
    local project_path="/var/www/html/$REPO_NAME"
    local queue_name="${REPO_NAME}_queue"
    local config_file="/etc/supervisor/conf.d/${queue_name}.conf"

    echo "Creating Laravel Queue configuration for Supervisor..."

    # Get queue configuration details
    read -p "Enter number of queue workers (default: 3): " num_workers
    num_workers=${num_workers:-3}

    read -p "Enter queue connection (default: database): " queue_connection
    queue_connection=${queue_connection:-database}

    read -p "Enter queue name (default: default): " queue_name_config
    queue_name_config=${queue_name_config:-default}

    # Create supervisor configuration file
    sudo tee "$config_file" << EOF
[program:${queue_name}]
process_name=%(program_name)s_%(process_num)02d
command=php ${project_path}/artisan queue:work ${queue_connection} --queue=${queue_name_config} --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
numprocs=${num_workers}
redirect_stderr=true
stdout_logfile=${project_path}/storage/logs/queue.log
stopwaitsecs=3600
user=www-data
EOF

    # Create log file if it doesn't exist
    sudo touch "${project_path}/storage/logs/queue.log"
    sudo chown www-data:www-data "${project_path}/storage/logs/queue.log"

    # Update supervisor configuration
    sudo supervisorctl reread
    sudo supervisorctl update
    sudo supervisorctl start "${queue_name}:*"

    echo "Laravel Queue configuration created successfully!"
    echo "Queue workers: $num_workers"
    echo "Queue connection: $queue_connection"
    echo "Queue name: $queue_name_config"
    echo "Log file: ${project_path}/storage/logs/queue.log"
    echo ""
    echo "Useful Supervisor commands:"
    echo "  sudo supervisorctl status ${queue_name}:*    # Check queue status"
    echo "  sudo supervisorctl restart ${queue_name}:*   # Restart queue workers"
    echo "  sudo supervisorctl stop ${queue_name}:*      # Stop queue workers"
    echo "  sudo supervisorctl start ${queue_name}:*     # Start queue workers"
}

# Update system
echo "Updating system packages..."
sudo apt update || error_exit "Failed to update system packages"

# Install ACL for better permission management
echo "Installing ACL for advanced permission management..."
sudo apt install -y acl || error_exit "Failed to install ACL"

# Select web server
echo "Available web servers:"
echo "1) Apache (default)"
echo "2) Nginx"
read -p "Select web server (1-2, default: 1): " web_server_choice
web_server_choice=${web_server_choice:-1}

case $web_server_choice in
    1)
        echo "Installing Apache2..."
        sudo apt install -y apache2 || error_exit "Failed to install Apache2"
        ;;
    2)
        echo "Installing Nginx..."
        sudo apt install -y nginx || error_exit "Failed to install Nginx"
        ;;
    *)
        error_exit "Invalid web server selected"
        ;;
esac

# Add PHP repository and install PHP
echo "Setting up PHP repository..."
sudo apt install -y ca-certificates apt-transport-https software-properties-common
sudo add-apt-repository -y ppa:ondrej/php
sudo apt update

# Select PHP version
select_php_version

# Install PHP and extensions
echo "Installing PHP ${PHP_VERSION} and extensions..."
if [ "$DB_TYPE" = "mysql" ]; then
    DB_EXTENSION="php${PHP_VERSION}-mysql"
else
    DB_EXTENSION="php${PHP_VERSION}-pgsql"
fi

sudo apt install -y php${PHP_VERSION} \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-opcache \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-curl \
    $DB_EXTENSION \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-soap \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-imagick \
    php${PHP_VERSION}-ldap \
    php${PHP_VERSION}-redis || error_exit "Failed to install PHP"

# Select database type
select_database

# Install database
if [ "$DB_TYPE" = "mysql" ]; then
    echo "Installing MySQL server..."
    sudo apt install -y mysql-server || error_exit "Failed to install MySQL"
else
    echo "Installing PostgreSQL server..."
    sudo apt install -y postgresql postgresql-contrib || error_exit "Failed to install PostgreSQL"
fi

# Get database credentials
get_database_credentials

# Configure database
if [ "$DB_TYPE" = "mysql" ]; then
    echo "Configuring MySQL..."
    sudo mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'localhost' WITH GRANT OPTION;"
    sudo mysql -e "FLUSH PRIVILEGES;"
    sudo mysql -e "CREATE DATABASE ${DB_NAME};"
else
    echo "Configuring PostgreSQL..."
    # Set password for postgres user
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD '${DB_PASS}';"

    # Create user if not postgres
    if [ "$DB_USER" != "postgres" ]; then
        sudo -u postgres createuser --createdb --login --pwprompt "$DB_USER" || echo "User might already exist"
        sudo -u postgres psql -c "ALTER USER ${DB_USER} PASSWORD '${DB_PASS}';"
    fi

    # Create database
    sudo -u postgres createdb -O "$DB_USER" "$DB_NAME" || echo "Database might already exist"

    # Configure PostgreSQL to allow password authentication
    PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oP '\d+\.\d+' | head -1)
    PG_CONFIG_PATH="/etc/postgresql/${PG_VERSION}/main"

    if [ -f "${PG_CONFIG_PATH}/pg_hba.conf" ]; then
        sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" "${PG_CONFIG_PATH}/postgresql.conf"
        sudo sed -i "s/local   all             all                                     peer/local   all             all                                     md5/" "${PG_CONFIG_PATH}/pg_hba.conf"
        sudo systemctl restart postgresql
    fi
fi

# Install Git
echo "Installing Git..."
sudo apt install -y git || error_exit "Failed to install Git"

# Install Composer
echo "Installing Composer..."
cd ~
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
HASH=$(curl -sS https://composer.github.io/installer.sig)
php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

# Function to select Node.js version
select_node_version() {
    echo "Available Node.js versions:"
    echo "1) Node.js 16.x (LTS)"
    echo "2) Node.js 18.x (LTS)"
    echo "3) Node.js 20.x (Current)"
    read -p "Select Node.js version (1-3): " node_choice

    case $node_choice in
        1) NODE_VERSION="16" ;;
        2) NODE_VERSION="18" ;;
        3) NODE_VERSION="20" ;;
        *) error_exit "Invalid Node.js version selected" ;;
    esac
    echo "Selected Node.js version: $NODE_VERSION"
}

# Install Node.js (optional)
if confirm "Do you want to install Node.js?"; then
    echo "Installing Node.js..."
    select_node_version
    cd ~
    curl -sL https://deb.nodesource.com/setup_${NODE_VERSION}.x -o nodesource_setup.sh
    sudo bash nodesource_setup.sh
    sudo apt install -y nodejs
fi

# Install Yarn and PM2 (optional, only if Node.js is installed)
if [ -x "$(command -v node)" ]; then
    if confirm "Do you want to install Yarn?"; then
        echo "Installing Yarn..."
        sudo npm install --global yarn
    fi

    if confirm "Do you want to install PM2?"; then
        echo "Installing PM2..."
        sudo npm install --global pm2
    fi
fi

# Install Supervisor
install_supervisor

# Get project details
read -p "Enter GitHub repository URL: " REPO_URL

# Navigate to web root
cd /var/www/html

# Clone the repository
echo "Cloning repository..."
sudo git clone "$REPO_URL" || error_exit "Failed to clone repository"

# Get the repository name from URL and cd into it
REPO_NAME=$(basename "$REPO_URL" .git)
cd "$REPO_NAME"

# Set comprehensive permissions
set_project_permissions

# Install dependencies with Composer
echo "Installing Composer dependencies..."
sudo -u www-data composer install || error_exit "Failed to install Composer dependencies"

# Setup environment file
echo "Setting up environment file..."
if [ -f ".env.example" ]; then
    sudo cp .env.example .env || error_exit "Failed to create .env file"
elif [ ! -f ".env" ]; then
    echo "Warning: No .env.example found. Creating basic .env file..."
    if [ "$DB_TYPE" = "mysql" ]; then
        DB_CONNECTION="mysql"
        DB_PORT="3306"
    else
        DB_CONNECTION="pgsql"
        DB_PORT="5432"
    fi

    sudo tee .env << EOF
APP_NAME=Laravel
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://localhost

LOG_CHANNEL=stack
LOG_LEVEL=debug

DB_CONNECTION=${DB_CONNECTION}
DB_HOST=127.0.0.1
DB_PORT=${DB_PORT}
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASS}

BROADCAST_DRIVER=log
CACHE_DRIVER=file
FILESYSTEM_DISK=local
QUEUE_CONNECTION=database
SESSION_DRIVER=file
SESSION_LIFETIME=120
EOF
fi

# Set proper ownership for .env file
sudo chown www-data:www-data .env
sudo chmod 644 .env

# Generate application key
echo "Generating application key..."
sudo -u www-data php artisan key:generate || error_exit "Failed to generate application key"

# Update database credentials in .env
if [ "$DB_TYPE" = "mysql" ]; then
    sudo sed -i "s/DB_CONNECTION=.*/DB_CONNECTION=mysql/" .env
    sudo sed -i "s/DB_PORT=.*/DB_PORT=3306/" .env
else
    sudo sed -i "s/DB_CONNECTION=.*/DB_CONNECTION=pgsql/" .env
    sudo sed -i "s/DB_PORT=.*/DB_PORT=5432/" .env
fi

sudo sed -i "s/DB_DATABASE=.*/DB_DATABASE=${DB_NAME}/" .env
sudo sed -i "s/DB_USERNAME=.*/DB_USERNAME=${DB_USER}/" .env
sudo sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASS}/" .env

# Run database migrations
if confirm "Do you want to run database migrations?"; then
    echo "Running database migrations..."
    sudo -u www-data php artisan migrate --force || echo "Warning: Migration failed. Please check your database configuration."
fi

# Clear and cache configuration
echo "Clearing and caching Laravel configuration..."
sudo -u www-data php artisan config:clear
sudo -u www-data php artisan cache:clear
sudo -u www-data php artisan view:clear
sudo -u www-data php artisan route:clear

# Cache configuration for production
sudo -u www-data php artisan config:cache
sudo -u www-data php artisan route:cache
sudo -u www-data php artisan view:cache

# Create storage link
echo "Creating storage symbolic link..."
sudo -u www-data php artisan storage:link || echo "Storage link already exists or failed to create"

# Get domain name
read -p "Enter your domain name (e.g., example.com): " DOMAIN_NAME

# Create web server configuration
if [ "$web_server_choice" = "1" ]; then
    # Apache configuration
    echo "Creating Apache configuration..."
    sudo tee /etc/apache2/sites-available/${DOMAIN_NAME}.conf << EOF
<VirtualHost *:80>
    ServerAdmin admin@${DOMAIN_NAME}
    ServerName ${DOMAIN_NAME}
    DocumentRoot /var/www/html/${REPO_NAME}/public

    <Directory /var/www/html/${REPO_NAME}/public>
        Options Indexes MultiViews FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

    # Enable Apache rewrite module
    sudo a2enmod rewrite

    # Enable the new site
    sudo a2ensite ${DOMAIN_NAME}.conf

    # Disable default site
    sudo a2dissite 000-default.conf

    # Restart Apache
    sudo systemctl restart apache2
else
    # Nginx configuration
    echo "Creating Nginx configuration..."
    sudo tee /etc/nginx/sites-available/${DOMAIN_NAME} << EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN_NAME};
    root /var/www/html/${REPO_NAME}/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF

    # Create symbolic link
    sudo ln -s /etc/nginx/sites-available/${DOMAIN_NAME} /etc/nginx/sites-enabled/

    # Remove default nginx site
    sudo rm -f /etc/nginx/sites-enabled/default

    # Test nginx configuration
    sudo nginx -t

    # Restart Nginx
    sudo systemctl restart nginx
fi

# Configure Laravel Queue with Supervisor (optional)
if confirm "Do you want to configure Laravel Queue with Supervisor?"; then
    create_queue_config
fi

# Install Redis (optional, recommended for queues and caching)
if confirm "Do you want to install Redis for caching and queues?"; then
    echo "Installing Redis..."
    sudo apt install -y redis-server || error_exit "Failed to install Redis"
    sudo systemctl enable redis-server
    sudo systemctl start redis-server

    # Update .env to use Redis for cache and sessions
    sudo sed -i "s/CACHE_DRIVER=.*/CACHE_DRIVER=redis/" .env
    sudo sed -i "s/SESSION_DRIVER=.*/SESSION_DRIVER=redis/" .env

    echo "Redis installed and configured!"
fi

# Final permission fix
echo "Applying final permission fixes..."
set_project_permissions

# SSL Installation (optional)
if confirm "Do you want to install SSL certificate?"; then
    echo "WARNING: Before proceeding, ensure your domain's DNS A record points to this server's IP address."
    if confirm "Have you configured the DNS settings?"; then
        echo "Installing Certbot..."
        if [ "$web_server_choice" = "1" ]; then
            sudo apt install -y certbot python3-certbot-apache
            echo "Generating SSL certificate..."
            sudo certbot --apache
        else
            sudo apt install -y certbot python3-certbot-nginx
            echo "Generating SSL certificate..."
            sudo certbot --nginx
        fi
    else
        echo "Please configure DNS settings first and run SSL installation later."
    fi
fi

echo "============================================"
echo "         Installation Complete!"
echo "============================================"
echo "PHP Version: ${PHP_VERSION}"
echo "Database: ${DB_TYPE^^}"
echo "Database User: ${DB_USER}"
echo "Database Name: ${DB_NAME}"
echo "Node.js Version: ${NODE_VERSION:-Not installed}"
echo "Domain: ${DOMAIN_NAME}"
echo "Project Path: /var/www/html/${REPO_NAME}"
echo ""
echo "Services Status:"
echo "- Web Server: Running"
if [ "$DB_TYPE" = "mysql" ]; then
    echo "- MySQL: Running"
else
    echo "- PostgreSQL: Running"
fi
echo "- Supervisor: Running"
if [ -x "$(command -v redis-server)" ]; then
    echo "- Redis: Running"
fi

echo ""
echo "Next Steps:"
echo "1. Configure your domain's DNS to point to this server"
echo "2. Test your application at http://${DOMAIN_NAME}"
echo "3. Monitor queue workers: sudo supervisorctl status"
echo "4. Check application logs: tail -f /var/www/html/${REPO_NAME}/storage/logs/laravel.log"
echo ""
echo "Important Files:"
echo "- Environment: /var/www/html/${REPO_NAME}/.env"
echo "- Queue Config: /etc/supervisor/conf.d/${REPO_NAME}_queue.conf"
if [ "$web_server_choice" = "1" ]; then
    echo "- Apache Config: /etc/apache2/sites-available/${DOMAIN_NAME}.conf"
else
    echo "- Nginx Config: /etc/nginx/sites-available/${DOMAIN_NAME}"
fi

echo ""
echo "🎉 Your Laravel application is ready to use!"