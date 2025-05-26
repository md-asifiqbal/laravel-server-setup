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


if [ ! -t 0 ]; then
    if [ -t 1 ]; then
        exec < /dev/tty
    else
        echo "=========================================="
        echo "⚠️  INTERACTIVE INPUT REQUIRED"
        echo "=========================================="
        echo "This script requires interactive input but is being run in a non-interactive way."
        echo ""
        echo "Please use one of these methods instead:"
        echo ""
        echo "Method 1 (Recommended):"
        echo "  curl -fsSL https://raw.githubusercontent.com/theihasan/laravel-server-setup/main/setup.sh -o setup.sh"
        echo "  chmod +x setup.sh"
        echo "  ./setup.sh"
        echo ""
        echo "Method 2:"
        echo "  bash <(curl -fsSL https://raw.githubusercontent.com/theihasan/laravel-server-setup/main/setup.sh)"
        echo ""
        exit 1
    fi
fi


safe_read() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local response

    if [ ! -t 0 ]; then
        echo "Error: Cannot read input in non-interactive mode"
        exit 1
    fi

    if [ -n "$default" ]; then
        read -r -p "$prompt (default: $default): " response
        response=${response:-$default}
    else
        read -r -p "$prompt: " response
    fi

    if [ -n "$var_name" ]; then
        eval "$var_name='$response'"
    else
        echo "$response"
    fi
}

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
    safe_read "Select PHP version (1-6)" "" php_choice

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
    safe_read "Select database system (1-2)" "1" db_choice

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

# Function to get server specifications for process recommendations
get_server_specs() {
    echo "Analyzing server specifications..."

    # Get CPU cores
    CPU_CORES=$(nproc)

    # Get RAM in GB
    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')

    # Get available RAM in GB
    AVAILABLE_RAM_GB=$(free -g | awk '/^Mem:/{print $7}')

    echo "Server Specifications:"
    echo "- CPU Cores: $CPU_CORES"
    echo "- Total RAM: ${RAM_GB}GB"
    echo "- Available RAM: ${AVAILABLE_RAM_GB}GB"

    # Calculate recommended processes
    if [ "$RAM_GB" -ge 8 ] && [ "$CPU_CORES" -ge 4 ]; then
        RECOMMENDED_PROCESSES=$((CPU_CORES * 2))
        SERVER_TYPE="High-performance"
    elif [ "$RAM_GB" -ge 4 ] && [ "$CPU_CORES" -ge 2 ]; then
        RECOMMENDED_PROCESSES=$CPU_CORES
        SERVER_TYPE="Medium-performance"
    else
        RECOMMENDED_PROCESSES=2
        SERVER_TYPE="Basic"
    fi

    echo "- Server Type: $SERVER_TYPE"
    echo "- Recommended Queue Processes: $RECOMMENDED_PROCESSES"
    echo ""
}

# Function to configure queue driver selection
configure_queue_driver() {
    echo "Queue Driver Configuration:"
    echo "1) Database (default) - Simple, no additional setup"
    echo "2) Redis - Fast, recommended for production"
    echo "3) Both - Database as fallback, Redis as primary"

    read -p "Select queue driver (1-3, default: 1): " queue_driver_choice
    queue_driver_choice=${queue_driver_choice:-1}

    case $queue_driver_choice in
        1)
            QUEUE_DRIVER="database"
            echo "Selected: Database queue driver"
            ;;
        2)
            QUEUE_DRIVER="redis"
            INSTALL_REDIS_FOR_QUEUE=true
            echo "Selected: Redis queue driver"
            ;;
        3)
            QUEUE_DRIVER="redis"
            QUEUE_FALLBACK="database"
            INSTALL_REDIS_FOR_QUEUE=true
            echo "Selected: Redis with database fallback"
            ;;
        *)
            error_exit "Invalid queue driver selection"
            ;;
    esac
}

# Function to configure session and cache drivers
configure_cache_session_drivers() {
    echo ""
    echo "Cache & Session Driver Configuration:"
    echo "Current selection: Queue = $QUEUE_DRIVER"

    # Cache driver selection
    echo ""
    echo "Cache Driver Options:"
    echo "1) File (default) - Simple file-based caching"
    echo "2) Redis - Fast in-memory caching (recommended)"
    echo "3) Database - Store cache in database"

    read -p "Select cache driver (1-3, default: 1): " cache_driver_choice
    cache_driver_choice=${cache_driver_choice:-1}

    case $cache_driver_choice in
        1) CACHE_DRIVER="file" ;;
        2)
            CACHE_DRIVER="redis"
            INSTALL_REDIS_FOR_CACHE=true
            ;;
        3) CACHE_DRIVER="database" ;;
        *) CACHE_DRIVER="file" ;;
    esac

    # Session driver selection
    echo ""
    echo "Session Driver Options:"
    echo "1) File (default) - Store sessions in files"
    echo "2) Redis - Fast session storage (recommended for multiple servers)"
    echo "3) Database - Store sessions in database"

    read -p "Select session driver (1-3, default: 1): " session_driver_choice
    session_driver_choice=${session_driver_choice:-1}

    case $session_driver_choice in
        1) SESSION_DRIVER="file" ;;
        2)
            SESSION_DRIVER="redis"
            INSTALL_REDIS_FOR_SESSION=true
            ;;
        3) SESSION_DRIVER="database" ;;
        *) SESSION_DRIVER="file" ;;
    esac

    # Determine if Redis is needed
    if [ "$INSTALL_REDIS_FOR_QUEUE" = true ] || [ "$INSTALL_REDIS_FOR_CACHE" = true ] || [ "$INSTALL_REDIS_FOR_SESSION" = true ]; then
        INSTALL_REDIS=true
    fi

    echo ""
    echo "Selected Configuration:"
    echo "- Queue Driver: $QUEUE_DRIVER"
    echo "- Cache Driver: $CACHE_DRIVER"
    echo "- Session Driver: $SESSION_DRIVER"
    if [ "$INSTALL_REDIS" = true ]; then
        echo "- Redis: Will be installed"
    fi
}

# Function to create multiple queue configurations for Supervisor
create_advanced_queue_config() {
    local project_path="/var/www/html/$REPO_NAME"

    echo ""
    echo "=== Advanced Queue Configuration ==="

    # Get server specs and recommendations
    get_server_specs

    # Configure drivers
    configure_queue_driver
    configure_cache_session_drivers

    echo ""
    echo "=== Queue Workers Setup ==="

    # Ask for number of different queues
    read -p "How many different queue types do you want to configure? (default: 1): " num_queue_types
    num_queue_types=${num_queue_types:-1}

    # Array to store queue configurations
    declare -a QUEUE_CONFIGS

    for ((i=1; i<=num_queue_types; i++)); do
        echo ""
        echo "--- Queue Type $i Configuration ---"

        if [ $i -eq 1 ]; then
            default_queue_name="default"
            default_processes=$RECOMMENDED_PROCESSES
        else
            default_queue_name="queue$i"
            default_processes=2
        fi

        read -p "Queue name (default: $default_queue_name): " queue_name
        queue_name=${queue_name:-$default_queue_name}

        echo ""
        echo "Process Recommendations for '$queue_name' queue:"
        echo "- Light workload (emails, notifications): 1-2 processes"
        echo "- Medium workload (file processing, API calls): 3-5 processes"
        echo "- Heavy workload (image processing, reports): 5+ processes"
        echo "- Your server can handle up to $RECOMMENDED_PROCESSES processes efficiently"

        read -p "Number of processes for '$queue_name' (recommended: $default_processes): " processes
        processes=${processes:-$default_processes}

        # Validate process count
        if [ "$processes" -gt $((RECOMMENDED_PROCESSES * 2)) ]; then
            echo "Warning: $processes processes might overload your server!"
            if ! confirm "Continue with $processes processes?"; then
                processes=$RECOMMENDED_PROCESSES
                echo "Reset to recommended: $processes processes"
            fi
        fi

        read -p "Priority for '$queue_name' (1=highest, 5=lowest, default: 3): " priority
        priority=${priority:-3}

        read -p "Max execution time in seconds (default: 3600): " max_time
        max_time=${max_time:-3600}

        # Store configuration
        QUEUE_CONFIGS+=("$queue_name:$processes:$priority:$max_time")

        echo "✓ Queue '$queue_name': $processes processes, priority $priority, max time ${max_time}s"
    done

    echo ""
    echo "Creating Supervisor configurations..."

    # Create supervisor config for each queue
    for config in "${QUEUE_CONFIGS[@]}"; do
        IFS=':' read -r queue_name processes priority max_time <<< "$config"

        config_file="/etc/supervisor/conf.d/${REPO_NAME}_${queue_name}.conf"

        # Set priority (lower number = higher priority)
        supervisor_priority=$((990 + priority * 10))

        sudo tee "$config_file" << EOF
[program:${REPO_NAME}_${queue_name}]
process_name=%(program_name)s_%(process_num)02d
command=php ${project_path}/artisan queue:work ${QUEUE_DRIVER} --queue=${queue_name} --sleep=3 --tries=3 --max-time=${max_time} --timeout=$((max_time + 60))
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
numprocs=${processes}
redirect_stderr=true
stdout_logfile=${project_path}/storage/logs/queue_${queue_name}.log
stopwaitsecs=$((max_time + 120))
user=www-data
priority=${supervisor_priority}
EOF

        # Create log file
        sudo touch "${project_path}/storage/logs/queue_${queue_name}.log"
        sudo chown www-data:www-data "${project_path}/storage/logs/queue_${queue_name}.log"

        echo "✓ Created config for '$queue_name' queue"
    done

    # Create a master queue monitor script
    sudo tee "/usr/local/bin/queue-monitor" << 'EOF'
#!/bin/bash
echo "=== Laravel Queue Status ==="
echo "Date: $(date)"
echo ""

echo "Supervisor Status:"
sudo supervisorctl status | grep queue

echo ""
echo "Queue Statistics:"
if command -v redis-cli &> /dev/null; then
    echo "Redis Queue Length: $(redis-cli llen queues:default)"
fi

echo ""
echo "Recent Queue Logs:"
find /var/www/html/*/storage/logs -name "queue_*.log" -exec tail -5 {} \; 2>/dev/null
EOF

    sudo chmod +x /usr/local/bin/queue-monitor

    # Update supervisor
    sudo supervisorctl reread
    sudo supervisorctl update

    # Start all queue workers
    for config in "${QUEUE_CONFIGS[@]}"; do
        IFS=':' read -r queue_name processes priority max_time <<< "$config"
        sudo supervisorctl start "${REPO_NAME}_${queue_name}:*"
    done

    echo ""
    echo "🎉 Queue configuration completed successfully!"
    echo ""
    echo "Queue Summary:"
    for config in "${QUEUE_CONFIGS[@]}"; do
        IFS=':' read -r queue_name processes priority max_time <<< "$config"
        echo "  ✓ $queue_name: $processes workers (priority: $priority, timeout: ${max_time}s)"
    done

    echo ""
    echo "Useful Commands:"
    echo "  queue-monitor                              # Check queue status"
    echo "  sudo supervisorctl status                  # All supervisor processes"
    echo "  sudo supervisorctl restart ${REPO_NAME}_*  # Restart all queues"
    echo "  sudo supervisorctl stop ${REPO_NAME}_*     # Stop all queues"
    echo "  sudo supervisorctl start ${REPO_NAME}_*    # Start all queues"
    echo ""
    echo "Queue Logs:"
    for config in "${QUEUE_CONFIGS[@]}"; do
        IFS=':' read -r queue_name processes priority max_time <<< "$config"
        echo "  tail -f ${project_path}/storage/logs/queue_${queue_name}.log"
    done
}

# Update system
echo "=========================================="
echo "🚀 Laravel Server Setup Script"
echo "=========================================="
echo "Enhanced LAMP/LEMP stack with Laravel optimization"
echo "Original: github.com/sohag-pro/SingleCommand"
echo "Enhanced: github.com/theihasan/server-setup"
echo ""
echo "Starting system update..."
sudo apt update || error_exit "Failed to update system packages"

# Install ACL for better permission management
echo "Installing ACL for advanced permission management..."
sudo apt install -y acl || error_exit "Failed to install ACL"

# Select web server
echo "Available web servers:"
echo "1) Apache (default)"
echo "2) Nginx"
safe_read "Select web server (1-2)" "1" web_server_choice

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
sudo apt install -y git unzip || error_exit "Failed to install Git and unzip"

# Install Composer
echo "Installing Composer..."
cd ~
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
HASH=$(curl -sS https://composer.github.io/installer.sig)
php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

# Function to safely set composer config
safe_composer_config() {
    local key="$1"
    local value="$2"
    local scope="${3:---global}"

    # Try to set the config and capture any errors
    if sudo -u www-data composer config $scope "$key" "$value" 2>/dev/null; then
        echo "✓ Set $key = $value"
    else
        echo "⚠ Skipping unsupported config: $key (not available in this Composer version)"
    fi
}

# Configure composer globally for better performance
echo "Configuring Composer for optimal performance..."
sudo mkdir -p /var/www/.composer
sudo chown -R www-data:www-data /var/www/.composer

# Get composer version for compatibility checks
COMPOSER_VERSION=$(sudo -u www-data composer --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
echo "Detected Composer version: $COMPOSER_VERSION"

# Set basic configurations that work across versions
safe_composer_config "process-timeout" "2000"

# Try to set cache configurations (may not work on all versions)
safe_composer_config "cache-files-maxsize" "1GB"

# Set other useful configurations
safe_composer_config "sort-packages" "true"
safe_composer_config "optimize-autoloader" "true"

# Setup GitHub token for better API limits
setup_github_token

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

# Check for existing installations
check_existing_installation

# Get project details
safe_read "Enter GitHub repository URL" "" REPO_URL

# Navigate to web root
cd /var/www/html

# Get the repository name from URL
REPO_NAME=$(basename "$REPO_URL" .git)

# Check if directory already exists
if [ -d "$REPO_NAME" ]; then
    echo ""
    echo "⚠️  Directory '$REPO_NAME' already exists!"
    echo "This might be from a previous installation attempt."
    echo ""
    echo "Options:"
    echo "1) Remove existing directory and clone fresh (recommended)"
    echo "2) Keep existing directory and update it"
    echo "3) Use a different directory name"
    echo "4) Exit and handle manually"

    safe_read "Select option (1-4)" "1" clone_option

    case $clone_option in
        1)
            echo "Removing existing directory and cloning fresh..."
            if confirm "Are you sure you want to delete /var/www/html/$REPO_NAME? This cannot be undone!"; then
                sudo rm -rf "$REPO_NAME"
                sudo git clone "$REPO_URL" || error_exit "Failed to clone repository"
                echo "✓ Fresh repository cloned successfully"
            else
                echo "Cancelled. Exiting to avoid data loss."
                exit 0
            fi
            ;;
        2)
            echo "Keeping existing directory and updating..."
            cd "$REPO_NAME"
            if [ -d ".git" ]; then
                echo "Pulling latest changes..."
                sudo git stash push -m "Auto-stash before script update $(date)" || true
                sudo git pull origin main || sudo git pull origin master || {
                    echo "Git pull failed. Continuing with existing code..."
                    echo "You may need to resolve conflicts manually later."
                }
                echo "✓ Repository updated (existing files preserved)"
            else
                echo "Not a git repository, continuing with existing files..."
                echo "✓ Using existing files"
            fi
            ;;
        3)
            safe_read "Enter new directory name" "${REPO_NAME}_new" NEW_REPO_NAME
            if [ -d "$NEW_REPO_NAME" ]; then
                error_exit "Directory '$NEW_REPO_NAME' also exists. Please choose a different name or clean up manually."
            fi
            REPO_NAME="$NEW_REPO_NAME"
            sudo git clone "$REPO_URL" "$REPO_NAME" || error_exit "Failed to clone repository"
            cd "$REPO_NAME"
            echo "✓ Repository cloned to new directory: $REPO_NAME"
            ;;
        4)
            echo "Exiting. To clean up manually, run:"
            echo "  sudo rm -rf /var/www/html/$REPO_NAME"
            echo "Then run this script again."
            exit 0
            ;;
        *)
            error_exit "Invalid option selected"
            ;;
    esac
else
    # Clone the repository normally
    echo "Cloning repository..."
    if sudo git clone "$REPO_URL"; then
        cd "$REPO_NAME"
        echo "✓ Repository cloned successfully"
    else
        echo ""
        echo "Failed to clone repository. This could be due to:"
        echo "1. Invalid repository URL"
        echo "2. Repository is private (requires authentication)"
        echo "3. Network connectivity issues"
        echo "4. Repository doesn't exist"
        echo ""
        if confirm "Do you want to continue with manual repository setup?"; then
            safe_read "Enter the directory name for your project" "myproject" REPO_NAME
            sudo mkdir -p "$REPO_NAME"
            cd "$REPO_NAME"
            echo "✓ Empty project directory created. You'll need to add your code manually."
        else
            error_exit "Repository clone failed and manual setup declined"
        fi
    fi
fi

echo "✓ Repository ready at: /var/www/html/$REPO_NAME"

# Set comprehensive permissions
set_project_permissions

# Create composer cache directories with proper permissions
sudo mkdir -p /var/www/.cache/composer/files
sudo mkdir -p /var/www/.cache/composer/repo
sudo mkdir -p /var/www/.config/composer
sudo chown -R www-data:www-data /var/www/.cache
sudo chown -R www-data:www-data /var/www/.config
sudo chmod -R 755 /var/www/.cache
sudo chmod -R 755 /var/www/.config

# Install dependencies with Composer
echo "Installing Composer dependencies..."

# Fix composer cache permissions first
sudo mkdir -p /var/www/.cache/composer
sudo mkdir -p /var/www/.config/composer
sudo chown -R www-data:www-data /var/www/.cache
sudo chown -R www-data:www-data /var/www/.config

# Set composer configuration to avoid GitHub API rate limits and improve performance
echo "Setting up Composer package repository and cache..."

# Essential configurations that should work on most Composer versions
echo "Setting essential Composer configurations..."
sudo -u www-data composer config --global process-timeout 2000 || echo "⚠ Could not set process timeout"

# Try optional configurations
echo "Setting optional Composer optimizations..."
safe_composer_config "repos.packagist" "composer https://packagist.org"
safe_composer_config "cache-files-maxsize" "1GB"
safe_composer_config "cache-repo-dir" "/var/www/.cache/composer/repo"
safe_composer_config "cache-files-dir" "/var/www/.cache/composer/files"
safe_composer_config "sort-packages" "true"
safe_composer_config "optimize-autoloader" "true"

echo "Composer configuration completed."

# Check if composer.lock exists to determine installation method
if [ -f "composer.lock" ]; then
    echo "Found composer.lock - installing exact versions..."
    INSTALL_CMD="install"
else
    echo "No composer.lock found - updating to latest versions..."
    INSTALL_CMD="update"
fi

# Install with optimized settings and better error handling
echo "Installing dependencies (this may take a few minutes)..."
echo "Note: Installation may pause for large packages - this is normal."

# Try different installation strategies
if sudo -u www-data composer $INSTALL_CMD --optimize-autoloader --no-dev --prefer-dist --no-interaction; then
    echo "✓ Composer dependencies installed successfully!"
elif sudo -u www-data composer $INSTALL_CMD --prefer-dist --no-interaction; then
    echo "✓ Composer dependencies installed (with dev packages)!"
elif sudo -u www-data composer $INSTALL_CMD --prefer-source --no-interaction; then
    echo "✓ Composer dependencies installed from source!"
else
    echo "⚠️ Standard composer install failed, trying manual approach..."
    # Last resort: try with timeout and verbose output
    sudo -u www-data composer $INSTALL_CMD --prefer-dist --no-interaction -vvv --timeout=0 || {
        echo "❌ Composer installation failed completely."
        echo "This might be due to:"
        echo "1. Network connectivity issues"
        echo "2. GitHub rate limiting (consider adding a GitHub token)"
        echo "3. Server resource constraints"
        echo ""
        if confirm "Do you want to continue without composer dependencies? (Not recommended)"; then
            echo "Continuing without dependencies - you'll need to run 'composer install' manually later"
        else
            error_exit "Failed to install Composer dependencies"
        fi
    }
fi

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

    # Set default queue driver
    if [ -z "$QUEUE_DRIVER" ]; then
        QUEUE_DRIVER="database"
    fi

    # Set default cache driver
    if [ -z "$CACHE_DRIVER" ]; then
        CACHE_DRIVER="file"
    fi

    # Set default session driver
    if [ -z "$SESSION_DRIVER" ]; then
        SESSION_DRIVER="file"
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
CACHE_DRIVER=${CACHE_DRIVER}
FILESYSTEM_DISK=local
QUEUE_CONNECTION=${QUEUE_DRIVER}
SESSION_DRIVER=${SESSION_DRIVER}
SESSION_LIFETIME=120

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379
EOF
fi

# Set proper ownership for .env file
sudo chown www-data:www-data .env
sudo chmod 644 .env

# Generate application key
echo "Generating application key..."
sudo -u www-data php artisan key:generate || error_exit "Failed to generate application key"

# Update database and driver credentials in .env
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

# Update driver configurations if they were set
if [ ! -z "$QUEUE_DRIVER" ]; then
    sudo sed -i "s/QUEUE_CONNECTION=.*/QUEUE_CONNECTION=${QUEUE_DRIVER}/" .env
fi

if [ ! -z "$CACHE_DRIVER" ]; then
    sudo sed -i "s/CACHE_DRIVER=.*/CACHE_DRIVER=${CACHE_DRIVER}/" .env
fi

if [ ! -z "$SESSION_DRIVER" ]; then
    sudo sed -i "s/SESSION_DRIVER=.*/SESSION_DRIVER=${SESSION_DRIVER}/" .env
fi

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

# Create storage link
echo "Creating storage symbolic link..."
sudo -u www-data php artisan storage:link || echo "Storage link already exists or failed to create"

# Handle NPM dependencies and build process
handle_npm_build() {
    echo ""
    echo "=== Frontend Assets Setup ==="

    # Check if package.json exists
    if [ -f "package.json" ]; then
        echo "✓ Found package.json - Frontend dependencies available"

        # Detect frontend framework/build tools
        echo "Detecting frontend setup..."
        if grep -q "vite" package.json; then
            echo "  📦 Detected: Vite (Laravel's default)"
            BUILD_TOOL="vite"
        elif grep -q "webpack" package.json; then
            echo "  📦 Detected: Webpack/Laravel Mix"
            BUILD_TOOL="webpack"
        elif grep -q "react" package.json; then
            echo "  ⚛️ Detected: React components"
        elif grep -q "vue" package.json; then
            echo "  🟢 Detected: Vue.js components"
        fi

        # Show available scripts
        echo ""
        echo "Available NPM scripts:"
        if command -v jq >/dev/null 2>&1 || sudo apt install -y jq >/dev/null 2>&1; then
            # Use jq if available for better formatting
            jq -r '.scripts // {} | to_entries[] | "  - \(.key): \(.value)"' package.json 2>/dev/null || {
                echo "  - Check package.json for available scripts"
            }
        else
            # Fallback: simple grep
            grep -A 10 '"scripts"' package.json | grep '"' | head -10 | sed 's/^/  /' || echo "  - Unable to parse scripts"
        fi

        echo ""
        if confirm "Do you want to install NPM dependencies and build assets?"; then

            # Install dependencies with progress
            echo "Installing NPM dependencies (this may take a few minutes)..."
            echo "Progress will be shown below:"

            if sudo -u www-data npm install --progress=true; then
                echo "✓ NPM dependencies installed successfully"

                echo ""
                echo "Build Options:"
                if [ "$BUILD_TOOL" = "vite" ]; then
                    echo "1) npm run build (Vite production build - recommended)"
                    echo "2) npm run dev (Vite development build)"
                elif [ "$BUILD_TOOL" = "webpack" ]; then
                    echo "1) npm run prod (Webpack production build - recommended)"
                    echo "2) npm run dev (Webpack development build)"
                else
                    echo "1) npm run build (production build - recommended)"
                    echo "2) npm run dev (development build)"
                    echo "3) npm run prod (production build - alternative)"
                fi
                echo "4) Custom build command"
                echo "5) Skip build process"

                safe_read "Select build option (1-5)" "1" build_choice

                case $build_choice in
                    1)
                        if [ "$BUILD_TOOL" = "webpack" ]; then
                            echo "Running Webpack production build..."
                            sudo -u www-data npm run prod
                        else
                            echo "Running production build..."
                            sudo -u www-data npm run build || sudo -u www-data npm run prod
                        fi

                        if [ $? -eq 0 ]; then
                            echo "✓ Production build completed successfully"

                            # Check if public assets were created
                            if [ -d "public/build" ] || [ -d "public/js" ] || [ -d "public/css" ]; then
                                echo "✓ Built assets found in public directory"
                            fi
                        else
                            echo "❌ Production build failed"
                        fi
                        ;;
                    2)
                        echo "Running development build..."
                        if sudo -u www-data npm run dev; then
                            echo "✓ Development build completed"
                        else
                            echo "❌ Development build failed"
                        fi
                        ;;
                    3)
                        if [ "$BUILD_TOOL" != "webpack" ]; then
                            echo "Running production build (alternative)..."
                            sudo -u www-data npm run prod || echo "❌ Production build failed"
                        else
                            echo "Option 3 not applicable for detected setup"
                        fi
                        ;;
                    4)
                        safe_read "Enter custom build command (e.g., 'npm run custom')" "npm run build" custom_cmd
                        echo "Running: $custom_cmd"
                        sudo -u www-data $custom_cmd || echo "❌ Custom build command failed"
                        ;;
                    5)
                        echo "Skipping build process"
                        ;;
                    *)
                        echo "Invalid option, skipping build"
                        ;;
                esac

                # Optional: Development watching
                if [ "$build_choice" = "2" ] && [ "$BUILD_TOOL" = "vite" ]; then
                    echo ""
                    echo "💡 For development with Vite:"
                    echo "   Run 'npm run dev' to start the development server"
                    echo "   It will be available at http://localhost:5173"
                elif [ "$build_choice" = "2" ]; then
                    echo ""
                    if confirm "Do you want to set up file watching for development? (runs in background)"; then
                        echo "Setting up file watcher..."
                        nohup sudo -u www-data npm run watch > /var/log/npm-watch.log 2>&1 &
                        WATCH_PID=$!
                        echo "✓ File watcher started (PID: $WATCH_PID)"
                        echo "  - Logs: tail -f /var/log/npm-watch.log"
                        echo "  - Stop: kill $WATCH_PID"
                    fi
                fi

            else
                echo "❌ NPM install failed"
                echo ""
                echo "Common solutions:"
                echo "  1. Node version compatibility issues"
                echo "  2. Network connectivity problems"
                echo "  3. Permission issues"
                echo "  4. Dependency conflicts"
                echo ""
                if confirm "Do you want to try alternative install methods?"; then
                    echo "Trying with legacy peer deps..."
                    if sudo -u www-data npm install --legacy-peer-deps; then
                        echo "✓ NPM install succeeded with legacy peer deps"
                    else
                        echo "Trying with force flag..."
                        if sudo -u www-data npm install --force; then
                            echo "✓ NPM install succeeded with force flag"
                        else
                            echo "❌ All NPM install methods failed"
                            echo ""
                            echo "Manual troubleshooting steps:"
                            echo "  cd /var/www/html/$REPO_NAME"
                            echo "  sudo -u www-data npm cache clean --force"
                            echo "  sudo -u www-data rm -rf node_modules package-lock.json"
                            echo "  sudo -u www-data npm install"
                        fi
                    fi
                fi
            fi
        else
            echo "Skipping NPM setup."
            echo ""
            echo "To set up frontend assets manually later:"
            echo "  cd /var/www/html/$REPO_NAME"
            echo "  sudo -u www-data npm install"
            if [ "$BUILD_TOOL" = "vite" ]; then
                echo "  sudo -u www-data npm run build    # For production"
                echo "  sudo -u www-data npm run dev      # For development"
            elif [ "$BUILD_TOOL" = "webpack" ]; then
                echo "  sudo -u www-data npm run prod     # For production"
                echo "  sudo -u www-data npm run dev      # For development"
            else
                echo "  sudo -u www-data npm run build    # For production"
            fi
        fi
    else
        echo "ℹ No package.json found - skipping NPM setup"
        echo "This is normal for:"
        echo "  - Backend-only Laravel applications"
        echo "  - APIs without frontend assets"
        echo "  - Applications using CDN assets"
    fi
}

# Run NPM setup
handle_npm_build

# Cache configuration for production
echo "Optimizing Laravel for production..."
sudo -u www-data php artisan config:cache
sudo -u www-data php artisan route:cache
sudo -u www-data php artisan view:cache

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
    create_advanced_queue_config
fi

# Install Redis if needed (based on driver selection or user choice)
if [ "$INSTALL_REDIS" = true ]; then
    echo "Installing Redis (required for selected drivers)..."
    sudo apt install -y redis-server || error_exit "Failed to install Redis"
    sudo systemctl enable redis-server
    sudo systemctl start redis-server
    echo "✓ Redis installed and configured for your selected drivers!"
elif confirm "Do you want to install Redis for future use (caching/sessions/queues)?"; then
    echo "Installing Redis..."
    sudo apt install -y redis-server || error_exit "Failed to install Redis"
    sudo systemctl enable redis-server
    sudo systemctl start redis-server
    echo "✓ Redis installed and ready for use!"
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

# Check if NPM build was successful
if [ -f "/var/www/html/${REPO_NAME}/package.json" ]; then
    if [ -d "/var/www/html/${REPO_NAME}/public/build" ] || [ -d "/var/www/html/${REPO_NAME}/public/js" ] || [ -d "/var/www/html/${REPO_NAME}/public/css" ]; then
        echo "Frontend Assets: ✓ Built and ready"
    else
        echo "Frontend Assets: ⚠ May need manual build"
    fi
else
    echo "Frontend Assets: Not applicable (no package.json)"
fi

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
if [ -x "$(command -v node)" ]; then
    echo "- Node.js: Installed"
fi

echo ""
echo "Next Steps:"
echo "1. Configure your domain's DNS to point to this server"
echo "2. Test your application at http://${DOMAIN_NAME}"
echo "3. Monitor queue workers: sudo supervisorctl status"
echo "4. Check application logs: tail -f /var/www/html/${REPO_NAME}/storage/logs/laravel.log"

# Add frontend-specific next steps
if [ -f "/var/www/html/${REPO_NAME}/package.json" ]; then
    echo ""
    echo "Frontend Development Commands:"
    if grep -q "vite" "/var/www/html/${REPO_NAME}/package.json"; then
        echo "  npm run dev      # Start Vite development server"
        echo "  npm run build    # Build for production"
    else
        echo "  npm run dev      # Development build"
        echo "  npm run watch    # Watch for changes"
        echo "  npm run build    # Production build"
    fi
fi

echo ""
echo "Important Files:"
echo "- Environment: /var/www/html/${REPO_NAME}/.env"
if [ -f "/etc/supervisor/conf.d/${REPO_NAME}_"*".conf" ]; then
    echo "- Queue Configs: /etc/supervisor/conf.d/${REPO_NAME}_*.conf"
fi
if [ "$web_server_choice" = "1" ]; then
    echo "- Apache Config: /etc/apache2/sites-available/${DOMAIN_NAME}.conf"
else
    echo "- Nginx Config: /etc/nginx/sites-available/${DOMAIN_NAME}"
fi

echo ""
echo "🎉 Your Laravel application is ready to use!"
if [ -f "/var/www/html/${REPO_NAME}/package.json" ]; then
    echo "💡 Frontend assets have been set up and built for optimal performance!"
fi