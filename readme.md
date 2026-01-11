# 🚀 Laravel Docker Setup Script

Automated setup script for Laravel projects with Docker, featuring PHP 8.4, Caddy web server, MySQL 8.0, Redis, Laravel Horizon (queue monitoring), and Laravel Telescope (debugging).

---

## 📋 Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [What Gets Created](#what-gets-created)
- [Quick Start](#quick-start)
- [Configuration Options](#configuration-options)
- [What the Script Does](#what-the-script-does)
- [Project Structure](#project-structure)
- [Accessing Your Application](#accessing-your-application)
- [Common Commands](#common-commands)
- [Working Across Multiple Machines](#working-across-multiple-machines)
- [Troubleshooting](#troubleshooting)
- [Customization](#customization)
- [License](#license)

---

## ✨ Features

- 🐘 **PHP 8.4** with FPM (Alpine-based for smaller image size)
- 🌐 **Caddy 2** web server (automatic HTTPS, modern config)
- 🗄️ **MySQL 8.0** database
- 🔴 **Redis** for caching, sessions, and queues
- 📊 **Laravel Horizon** pre-installed (queue monitoring dashboard)
- 🔭 **Laravel Telescope** pre-installed (debugging and monitoring)
- ⚡ **Vite** auto-configured for Docker with HMR (Hot Module Replacement)
- 👷 **Queue Worker** service (automatically processes background jobs)
- 🔐 **Secure** APP_KEY generation
- 📦 **Multiple Laravel Starter Kits** support:
  - `laravel/laravel` (default)
  - `laravel/livewire-starter-kit`
  - `laravel/vue-starter-kit`
  - `laravel/react-starter-kit`
- 🎯 **Git-ready** with proper `.gitignore`
- 🔧 **Development-optimized** with helpful aliases and clear instructions

---

## 📦 Prerequisites

### Required Software

- **Docker** (version 20.10 or higher)
- **Docker Compose** (version 2.0 or higher)
- **Bash** (Linux/macOS built-in, Windows users should use WSL 2)
- **Git** (for version control)

### System Requirements

- At least 4GB of RAM available for Docker
- 5GB of free disk space
- Ports available: 8000 (web), 33061 (MySQL), 6379 (Redis), 5173 (Vite)

### For Windows Users

- **Windows 10/11** with WSL 2 enabled
- **Ubuntu** (or preferred Linux distribution) installed in WSL
- **Docker Desktop for Windows** with WSL 2 integration enabled

---

## 📂 What Gets Created

The script creates a complete Laravel Docker development environment:

```
your-project-name/
├── .env                          # Environment variables (with secrets)
├── .env.example                  # Template for environment variables
├── .gitignore                    # Git ignore rules
├── .dockerignore                 # Docker ignore rules
├── docker-compose.yml            # Base Docker services configuration
├── docker-compose.override.yml   # Local development port mappings (not in Git)
├── docker/
│   ├── php/
│   │   └── Dockerfile           # Custom PHP 8.4-FPM image
│   └── caddy/
│       └── Caddyfile            # Caddy web server configuration
└── src/                         # Your Laravel application
    ├── app/
    ├── bootstrap/
    ├── config/
    ├── database/
    ├── public/
    ├── resources/
    ├── routes/
    ├── storage/
    ├── tests/
    └── vendor/
```

### Docker Services

The setup includes 5 containerized services:

1. **app** - PHP-FPM application server
2. **web** - Caddy web server (serves your app)
3. **db** - MySQL 8.0 database
4. **redis** - Redis cache/queue server
5. **worker** - Laravel queue worker (processes background jobs)

---

## 🎬 Quick Start

### Step 1: Download the Script

```bash
# Download the script
curl -O https://your-repo/setup-laravel-docker.sh

# Or if you have it locally
chmod +x setup-laravel-docker.sh
```

### Step 2: Run the Setup

```bash
./setup-laravel-docker.sh
```

### Step 3: Follow the Prompts

The script will ask you for:

1. **Project Name** (e.g., `my-blog-app`)
2. **Installation Directory** (default: current directory `.`)
3. **Laravel Starter Kit** (1-4, default: 1)
4. **Host Port for HTTP** (default: `8000`)
5. **Host Port for Database** (default: `33061`)
6. **Host Port for Redis** (default: `6379`)
7. **Database Name** (default: `laravel_db`)
8. **Database Username** (default: `docker_user`)
9. **Database Password** (required, hidden input)
10. **Run Migrations?** (y/N)

### Step 4: Access Your Application

Once setup completes, open your browser:

- **Application:** http://localhost:8000
- **Horizon Dashboard:** http://localhost:8000/horizon
- **Telescope Dashboard:** http://localhost:8000/telescope

---

## ⚙️ Configuration Options

### Laravel Starter Kits

Choose from 4 official Laravel starter kits:

1. **laravel/laravel** (Default)
   - Basic Laravel application skeleton
   - Minimal setup, maximum flexibility

2. **laravel/livewire-starter-kit**
   - Laravel + Livewire (full-stack framework)
   - Real-time, reactive components without writing JavaScript

3. **laravel/vue-starter-kit**
   - Laravel + Vue.js 3
   - Modern JavaScript framework with composition API

4. **laravel/react-starter-kit**
   - Laravel + React 18
   - Popular JavaScript library for building UIs

### Port Configuration

All ports can be customized during setup:

| Service | Default Port | Purpose |
|---------|-------------|---------|
| Web (HTTP) | 8000 | Access your Laravel app |
| MySQL | 33061 | Connect with database GUI tools |
| Redis | 6379 | Connect with Redis GUI tools |
| Vite HMR | 5173 | Frontend hot module replacement |

To change ports after setup, edit `.env` and restart:
```bash
# Edit .env
nano .env

# Restart containers
docker compose down
docker compose up -d
```

---

## 🔧 What the Script Does

### 1. Validation & Setup
- ✅ Checks Docker is installed and running
- ✅ Validates directory paths
- ✅ Generates cryptographically secure `APP_KEY`
- ✅ Creates project directory structure

### 2. Configuration Files
- ✅ Creates `.env` with your credentials and configuration
- ✅ Creates `.env.example` template (without secrets)
- ✅ Creates `.gitignore` (excludes sensitive files)
- ✅ Creates `.dockerignore` (optimizes Docker builds)
- ✅ Creates `docker-compose.yml` (base services)
- ✅ Creates `docker-compose.override.yml` (local port mappings)

### 3. Docker Setup
- ✅ Creates custom PHP Dockerfile with extensions:
  - bcmath, curl, gd, intl, mbstring
  - pcntl, pdo_mysql, pdo_pgsql, sockets, zip
  - redis (via PECL)
- ✅ Creates Caddyfile for web server
- ✅ Configures all 5 services with proper networking

### 4. Laravel Installation
- ✅ Builds custom PHP image
- ✅ Creates Laravel project using selected starter kit
- ✅ Installs Composer dependencies
- ✅ Installs NPM dependencies
- ✅ Installs and configures Laravel Horizon
- ✅ Installs and configures Laravel Telescope

### 5. Configuration
- ✅ Auto-configures `vite.config.js` for Docker HMR
- ✅ Creates storage symlink (`storage:link`)
- ✅ Sets correct file permissions (775 for www-data)
- ✅ Clears configuration cache
- ✅ Optionally runs database migrations

### 6. Final Setup
- ✅ Provides access URLs and connection details
- ✅ Suggests helpful shell aliases
- ✅ Shows next steps and common commands

---

## 📁 Project Structure

### Configuration Files

**`.env`** - Contains all environment variables including secrets
- ❌ **NOT committed to Git** (in `.gitignore`)
- ✅ Machine-specific configuration
- ✅ Contains database passwords, APP_KEY

**`.env.example`** - Template without secrets
- ✅ **Committed to Git**
- ✅ Shows required variables
- ✅ Safe to share publicly

**`docker-compose.yml`** - Base service definitions
- ✅ **Committed to Git**
- ✅ Defines all 5 services
- ✅ Production-ready (no exposed ports)

**`docker-compose.override.yml`** - Local development overrides
- ❌ **NOT committed to Git** (in `.gitignore`)
- ✅ Exposes ports for local development
- ✅ Machine-specific settings

### Why Two Docker Compose Files?

Docker Compose automatically merges both files:

1. **docker-compose.yml** = Base configuration (shared across team)
2. **docker-compose.override.yml** = Local overrides (personal settings)

This allows:
- Team members to use different ports if needed
- Production deployment without exposed database ports
- Local development with all necessary tool access

---

## 🌐 Accessing Your Application

### From Your Browser

- **Laravel App:** http://localhost:8000
- **Horizon:** http://localhost:8000/horizon (queue monitoring)
- **Telescope:** http://localhost:8000/telescope (debugging)

### Database Access (GUI Tools)

Use MySQL Workbench, DBeaver, TablePlus, etc.:

```
Host:     localhost (or 127.0.0.1)
Port:     33061 (or your configured DB_HOST_PORT)
Database: laravel_db (or your configured DB_DATABASE)
Username: docker_user (or your configured DB_USERNAME)
Password: (your DB_PASSWORD from .env)
```

### Redis Access (GUI Tools)

Use RedisInsight, Medis, etc.:

```
Host: localhost (or 127.0.0.1)
Port: 6379 (or your configured REDIS_EXTERNAL_PORT)
```

---

## 💻 Common Commands

### Docker Management

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart all services
docker compose restart

# View logs (all services)
docker compose logs -f

# View logs (specific service)
docker compose logs -f app

# Check service status
docker compose ps

# Rebuild containers
docker compose up -d --build

# Access app container shell
docker compose exec app sh
```

### Laravel Artisan

```bash
# Run any artisan command
docker compose exec app php /var/www/src/artisan [command]

# Examples:
docker compose exec app php /var/www/src/artisan migrate
docker compose exec app php /var/www/src/artisan make:model Post
docker compose exec app php /var/www/src/artisan make:controller PostController
docker compose exec app php /var/www/src/artisan tinker
docker compose exec app php /var/www/src/artisan queue:work
docker compose exec app php /var/www/src/artisan test

# Clear caches
docker compose exec app php /var/www/src/artisan cache:clear
docker compose exec app php /var/www/src/artisan config:clear
docker compose exec app php /var/www/src/artisan route:clear
docker compose exec app php /var/www/src/artisan view:clear
```

### Composer

```bash
# Install dependencies
docker compose exec app composer install

# Add new package
docker compose exec app composer require vendor/package

# Update dependencies
docker compose exec app composer update

# Dump autoload
docker compose exec app composer dump-autoload
```

### NPM / Vite

```bash
# Install dependencies
docker compose exec app npm install

# Run Vite dev server (with hot reload)
docker compose exec app npm run dev

# Build for production
docker compose exec app npm run build

# Run specific script
docker compose exec app npm run [script-name]
```

### Suggested Aliases

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
# Navigate to project and run commands
alias art='docker compose exec app php /var/www/src/artisan'
alias composer='docker compose exec app composer'
alias npm='docker compose exec app npm'
alias test='docker compose exec app php /var/www/src/artisan test'
```

After sourcing your shell config (`source ~/.bashrc`), you can use:

```bash
art migrate
art make:model Post
composer require laravel/sanctum
npm run dev
test
```

---

## 🔄 Working Across Multiple Machines

This setup is designed to work seamlessly across Linux, macOS, and Windows (WSL).

### Initial Setup on Primary Machine

```bash
# Run the setup script
./setup-laravel-docker.sh

# Initialize Git
cd your-project-name
git init
git add .
git commit -m "Initial Laravel Docker setup"

# Push to your Git repository
git remote add origin git@github.com:username/repo.git
git push -u origin main
```

### Setup on Additional Machine

```bash
# Clone the repository
git clone git@github.com:username/repo.git
cd repo

# Create .env from example
cp .env.example .env

# Edit .env and add your database password
nano .env

# Start Docker services
docker compose up -d

# Install dependencies
docker compose exec app composer install
docker compose exec app npm install

# Fix permissions
docker compose exec app chown -R www-data:www-data /var/www/src/storage /var/www/src/bootstrap/cache
docker compose exec app chmod -R 775 /var/www/src/storage /var/www/src/bootstrap/cache

# Run migrations
docker compose exec app php /var/www/src/artisan migrate
```

### Daily Workflow

**On Machine A (end of work):**
```bash
git add .
git commit -m "Added user authentication"
git push
```

**On Machine B (start of work):**
```bash
git pull
docker compose exec app composer install  # If composer.json changed
docker compose exec app npm install        # If package.json changed
docker compose exec app php /var/www/src/artisan migrate  # If new migrations
```

### What to Sync vs. Not Sync

✅ **DO sync (via Git):**
- All source code (`src/` directory)
- Docker configuration (`docker-compose.yml`, `docker/`)
- `.env.example`
- `.gitignore`, `.dockerignore`

❌ **DON'T sync (in `.gitignore`):**
- `.env` (create separately on each machine)
- `vendor/` (run `composer install`)
- `node_modules/` (run `npm install`)
- `db-data/`, `caddy_data/`, `redis-data/` (Docker volumes)
- `docker-compose.override.yml` (machine-specific ports)

---

## 🐛 Troubleshooting

### Permission Denied Errors

**Problem:** `file_put_contents(): Failed to open stream: Permission denied`

**Solution:**
```bash
docker compose exec app chown -R www-data:www-data /var/www/src/storage /var/www/src/bootstrap/cache
docker compose exec app chmod -R 775 /var/www/src/storage /var/www/src/bootstrap/cache
docker compose exec app php /var/www/src/artisan view:clear
docker compose restart app
```

### Port Already Allocated

**Problem:** `Error: port is already allocated`

**Solution:**
```bash
# Check what's using the port
sudo lsof -i :8000  # Linux/macOS
netstat -ano | findstr :8000  # Windows

# Option 1: Stop the conflicting service
# Option 2: Change port in .env
nano .env
# Change WEB_HOST_PORT=8080

docker compose down
docker compose up -d
```

### Database Connection Refused

**Problem:** `SQLSTATE[HY000] [2002] Connection refused`

**Solution:**
```bash
# Check if database is running
docker compose ps

# Check database logs
docker compose logs db

# Restart database and app
docker compose restart db
sleep 5
docker compose restart app
```

### Vite Not Working / HMR Not Connecting

**Problem:** Changes not reflecting, Vite errors

**Solution:**
```bash
# Ensure vite.config.js is properly configured
cat src/vite.config.js
# Should have: host: '0.0.0.0', hmr: { host: 'localhost' }

# Restart Vite
docker compose exec app npm run dev

# Check if port 5173 is exposed
docker compose ps
# Should show: 0.0.0.0:5173->5173/tcp
```

### Can't Access App from Browser

**Problem:** `http://localhost:8000` shows connection refused

**Solution:**
```bash
# Verify docker-compose.override.yml exists
ls -la docker-compose.override.yml

# Check if ports are mapped
docker compose ps
# web service should show: 0.0.0.0:8000->80/tcp

# Recreate containers
docker compose down
docker compose up -d
```

### Composer/NPM Install Fails

**Problem:** Timeout or network errors during installation

**Solution:**
```bash
# Increase timeout and retry
docker compose exec app composer install --no-interaction --prefer-dist

# For NPM
docker compose exec app npm install --legacy-peer-deps

# If persistent, check Docker memory allocation
# Docker Desktop → Settings → Resources → Memory (increase to 4GB+)
```

---

## 🎨 Customization

### Change PHP Version

Edit `docker/php/Dockerfile`:
```dockerfile
FROM php:8.3-fpm-alpine  # Change 8.4 to 8.3
```

Then rebuild:
```bash
docker compose down
docker compose up -d --build
```

### Add PHP Extensions

Edit `docker/php/Dockerfile`, add to the `docker-php-ext-install` line:
```dockerfile
&& docker-php-ext-install -j$(nproc) \
    bcmath \
    curl \
    gd \
    your-extension-here \
```

### Change Database to PostgreSQL

1. Edit `docker-compose.yml`, replace `db` service:
```yaml
db:
  image: postgres:15-alpine
  environment:
    POSTGRES_DB: ${DB_DATABASE}
    POSTGRES_USER: ${DB_USERNAME}
    POSTGRES_PASSWORD: ${DB_PASSWORD}
```

2. Update `.env`:
```env
DB_CONNECTION=pgsql
DB_PORT=5432
```

### Add More Services

Add to `docker-compose.yml`:
```yaml
mailhog:
  image: mailhog/mailhog
  ports:
    - "8025:8025"
  networks:
    - laravel-net
```

---

## 📝 Notes

### Security Considerations

- `.env` is excluded from Git (contains secrets)
- Database root password same as user password (fine for local dev)
- For production, use separate root password and restrict port access
- Horizon and Telescope should be protected in production (see Laravel docs)

### Performance Tips

- Store projects in WSL filesystem on Windows (not `/mnt/c/...`)
- Allocate at least 4GB RAM to Docker
- Use `.dockerignore` to exclude large folders from build context
- Consider using Docker volume for `vendor/` on slow filesystems

### Laravel Features Pre-configured

- ✅ Redis for cache, session, queue
- ✅ Horizon for queue monitoring
- ✅ Telescope for debugging
- ✅ Vite for frontend assets with HMR
- ✅ Queue worker running automatically
- ✅ Storage symlink created
- ✅ All permissions set correctly

---

## 📄 License

This setup script is open-source and free to use. Laravel is a trademark of Taylor Otwell. All other trademarks are property of their respective owners.

---

## 🆘 Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review container logs: `docker compose logs -f`
3. Verify all services are running: `docker compose ps`
4. Check `.env` configuration matches your setup
5. Ensure Docker Desktop has sufficient resources

---

## 🎯 Quick Reference

```bash
# Setup
./setup-laravel-docker.sh

# Start
docker compose up -d

# Stop
docker compose down

# Logs
docker compose logs -f

# Artisan
docker compose exec app php /var/www/src/artisan [command]

# Vite
docker compose exec app npm run dev

# Shell
docker compose exec app sh
```

**Happy coding! 🚀**
