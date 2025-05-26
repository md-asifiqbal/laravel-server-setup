# 🚀 Server Setup Scripts

**One-command server setup for Laravel applications with enterprise-grade features.**

> 🍴 **Fork Notice**: This is an enhanced fork of the original script from [sohag-pro/SingleCommand](https://github.com/sohag-pro/SingleCommand). Special thanks to the original author for the foundation!

## ⚡ Quick Start

### Method 1: Download & Execute (Recommended)
```bash
curl -fsSL https://raw.githubusercontent.com/theihasan/server-setup/main/lamp.sh -o setup.sh
chmod +x setup.sh
./setup.sh
```

### Method 2: Process Substitution
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/theihasan/server-setup/main/lamp.sh)
```

### Method 3: Direct Pipe (Basic - Limited Interaction)
```bash
curl -fsSL https://raw.githubusercontent.com/theihasan/server-setup/main/lamp.sh | bash
```

> **💡 Tip**: Method 1 is recommended as it allows you to review the script first and provides full interactive capabilities.

## 🔥 What You Get

- **Web Server**: Apache or Nginx (your choice)
- **PHP**: Versions 7.4 to 8.4 with all Laravel extensions
- **Database**: MySQL or PostgreSQL (your choice)
- **Queue Management**: Advanced Supervisor configuration with multiple queues
- **Queue Drivers**: Database, Redis, or hybrid setup
- **Cache & Sessions**: File, Database, or Redis drivers
- **Process Manager**: PM2 for Node.js applications
- **Package Managers**: Composer, NPM, Yarn
- **Caching**: Redis support with intelligent driver selection
- **SSL**: Automatic Let's Encrypt certificate
- **Permissions**: Bulletproof Laravel permissions setup
- **Optimization**: Production-ready Laravel caching
- **Monitoring**: Built-in queue monitoring tools

## 📋 Requirements

- **OS**: Ubuntu 18.04+ or Debian 9+
- **Access**: Root or sudo privileges
- **Network**: Active internet connection
- **Domain**: Optional (for SSL setup)

## 🎯 Perfect For

- ✅ Laravel production deployments
- ✅ Development environment setup
- ✅ VPS quick configuration
- ✅ CI/CD pipeline integration
- ✅ Multiple project hosting

## 🛠️ Installation Options

### Option 1: Download & Execute (Recommended)
```bash
# Download and review the script
curl -fsSL https://raw.githubusercontent.com/theihasan/server-setup/main/lamp.sh -o setup.sh

# Review the script (optional but recommended)
cat setup.sh

# Make executable and run
chmod +x setup.sh
./setup.sh
```

### Option 2: Process Substitution
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/theihasan/server-setup/main/lamp.sh)
```

### Option 3: Direct Pipe (Limited Features)
```bash
curl -fsSL https://raw.githubusercontent.com/theihasan/server-setup/main/lamp.sh | bash
```

### Option 4: Wget Alternative
```bash
wget -qO setup.sh https://raw.githubusercontent.com/theihasan/server-setup/main/lamp.sh
chmod +x setup.sh
./setup.sh
```

> **⚠️ Note**: Methods 3 may have limited interactive capabilities due to stdin redirection. Use Method 1 or 2 for full functionality.

## 🎮 Interactive Setup

The script will guide you through:

1. **Web Server Selection** (Apache/Nginx)
2. **PHP Version** (7.4 to 8.4)
3. **Database Selection** (MySQL/PostgreSQL)
4. **Database Configuration** (Username, Password, Database)
5. **Node.js Installation** (Optional)
6. **Repository Cloning** (Your GitHub repo)
7. **Advanced Queue Setup**:
   - Queue driver selection (Database/Redis/Hybrid)
   - Cache driver (File/Database/Redis)
   - Session driver (File/Database/Redis)
   - Multiple queue configuration
   - Process count optimization based on server specs
   - Priority and timeout settings
8. **SSL Certificate** (Let's Encrypt)

## 📦 Installed Components

| Component | Purpose | Version |
|-----------|---------|---------|
| Apache/Nginx | Web Server | Latest |
| PHP | Backend Language | 7.4-8.4 |
| MySQL/PostgreSQL | Database | Latest |
| Composer | PHP Dependencies | Latest |
| Node.js | JavaScript Runtime | 16/18/20 |
| Supervisor | Process Manager | Latest |
| Redis | Caching/Sessions | Latest |
| Git | Version Control | Latest |

## 🔧 Post-Installation

After installation, your server will have:

```bash
# Check services status
sudo systemctl status apache2     # or nginx
sudo systemctl status mysql       # or postgresql
sudo systemctl status supervisor
sudo systemctl status redis       # if installed

# Database connections
mysql -u username -p database_name           # For MySQL
psql -U username -d database_name           # For PostgreSQL

# Advanced Queue Management
queue-monitor                                # Check all queue status
sudo supervisorctl status                    # All supervisor processes
sudo supervisorctl restart projectname_*    # Restart all project queues
sudo supervisorctl start projectname_default:*  # Start specific queue

# Queue Monitoring
tail -f /var/www/html/project/storage/logs/queue_default.log
tail -f /var/www/html/project/storage/logs/queue_emails.log

# Laravel commands
cd /var/www/html/your-project
php artisan queue:work redis --queue=high,default  # Work specific queues
php artisan queue:restart                          # Restart all workers
php artisan migrate                                 # Run migrations
```

## 🏗️ Directory Structure

```
/var/www/html/your-project/
├── app/
├── config/
├── public/              # Document root
├── storage/
│   ├── logs/
│   │   ├── laravel.log
│   │   └── queue.log    # Supervisor queue logs
├── .env                 # Environment configuration
└── artisan
```

## 🔒 Security Features

- ✅ Proper file permissions (755/644)
- ✅ Storage directory protection
- ✅ Database user isolation
- ✅ SSL certificate automation
- ✅ Firewall-ready configuration
- ✅ Log file protection

## 🚨 Troubleshooting

### Installation Issues

#### "Invalid selection" Error When Using Pipe
```bash
# This may not work properly:
curl -fsSL https://raw.githubusercontent.com/theihasan/server-setup/main/lamp.sh | bash

# Use this instead:
curl -fsSL https://raw.githubusercontent.com/theihasan/server-setup/main/lamp.sh -o setup.sh
chmod +x setup.sh
./setup.sh

# Or use process substitution:
bash <(curl -fsSL https://raw.githubusercontent.com/theihasan/server-setup/main/lamp.sh)
```

#### Script Download Issues
```bash
# If download fails, try with wget:
wget --no-check-certificate -qO setup.sh https://raw.githubusercontent.com/theihasan/server-setup/main/lamp.sh

# Or force TLS 1.2:
curl --tlsv1.2 -fsSL https://raw.githubusercontent.com/theihasan/server-setup/main/lamp.sh -o setup.sh
```

### Permission Issues
```bash
# Fix Laravel permissions
sudo chown -R www-data:www-data /var/www/html/your-project
sudo chmod -R 755 /var/www/html/your-project
sudo chmod -R 775 /var/www/html/your-project/storage
sudo chmod -R 775 /var/www/html/your-project/bootstrap/cache
```

### Queue Issues
```bash
# Check queue status
queue-monitor

# Check specific queue logs
tail -f /var/www/html/your-project/storage/logs/queue_default.log

# Restart specific queue workers
sudo supervisorctl restart your-project_default:*

# Check Redis queue length (if using Redis)
redis-cli llen queues:default
redis-cli llen queues:emails
```

### Driver Issues
```bash
# Test Redis connection
redis-cli ping

# Check Laravel can connect to queue
cd /var/www/html/your-project
php artisan queue:work --once

# Test database connection
php artisan migrate:status
```

### Web Server Issues
```bash
# Apache
sudo systemctl restart apache2
sudo apache2ctl configtest

# Nginx
sudo systemctl restart nginx
sudo nginx -t
```

## 📊 Performance Optimization

The script automatically configures:

- **OPcache**: PHP bytecode caching
- **Laravel Caching**: Config, route, and view caching
- **Redis**: Session and cache storage
- **Supervisor**: Efficient queue processing
- **Production Settings**: Optimized for live environments

## 🙏 Credits & Acknowledgments

- **Original Script**: [sohag-pro/SingleCommand](https://github.com/sohag-pro/SingleCommand)
- **Original Author**: [@sohag-pro](https://github.com/sohag-pro)
- **Fork Enhancements**: Enhanced with Supervisor, comprehensive permissions, and Laravel optimizations

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 🙋‍♂️ Support

- **Issues**: [GitHub Issues](https://github.com/theihasan/laravel-server-setup/issues)
- **Discussions**: [GitHub Discussions](https://github.com/theihasan/laravel-server-setup/discussions)
- **Email**: [imabulhasan99@gmail.com](mailto:imabulhasan99@gmail.com)

## ⭐ Show Your Support

If this script helped you, please give it a ⭐ star on GitHub!

---

**Made with ❤️ for the Laravel community**

*Deploy once, deploy anywhere!*