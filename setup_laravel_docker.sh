#!/bin/bash

# =============================================================================
# Laravel Docker Setup Script - LOCAL DEVELOPMENT OPTIMIZED
# =============================================================================
# PHP 8.4 | Caddy 2 | MySQL 8.0 | Redis | Horizon | Telescope
# Optimized for local development with sensible defaults and automation
# =============================================================================

# --- Configuration (Defaults) ---
PHP_VERSION="8.4"
PROJECT_NAME=""
INSTALL_DIR=""
WEB_HOST_PORT="8000"
DB_DATABASE="laravel_db"
DB_USERNAME="docker_user"
DB_PASSWORD=""
DOMAIN_NAME="localhost"
DB_HOST_PORT="33061"
REDIS_EXTERNAL_PORT="6379"
LARAVEL_STARTER_KIT="laravel/laravel"

# --- Functions ---

# Function to prompt user and validate input
prompt_for_input() {
    local prompt_msg=$1
    local var_name=$2
    local validation_func=$3
    local default_value=$4
    local is_secret=$5

    while true; do
        local current_default=""
        if [ -n "$default_value" ]; then
            current_default=" (Default: $default_value)"
        fi
        
        if [ "$is_secret" = "true" ]; then
            read -r -p "$prompt_msg: " -s input
            echo 
        else
            read -p "$prompt_msg$current_default: " input
        fi

        if [ -z "$input" ] && [ -n "$default_value" ]; then
            input="$default_value"
        fi

        if [ -n "$validation_func" ]; then
            if ! "$validation_func" "$input"; then
                continue
            fi
        fi

        if [ -z "$input" ]; then
            echo "Input cannot be empty. Please try again."
        else
            eval "$var_name=\"$input\""
            break
        fi
    done
}

# Prompt user for Laravel starter kit selection
prompt_for_starter_kit() {
    echo "--- Select Laravel Starter Kit ---"
    echo "1) laravel/laravel (Default - Basic App Skeleton)"
    echo "2) laravel/livewire-starter-kit"
    echo "3) laravel/vue-starter-kit"
    echo "4) laravel/react-starter-kit"
    
    local choice
    while true; do
        read -p "Enter selection number (1-4, Default: 1): " choice
        # Default to 1 if empty
        if [ -z "$choice" ]; then
            choice=1
        fi
        case $choice in
            1) LARAVEL_STARTER_KIT="laravel/laravel"; break ;;
            2) LARAVEL_STARTER_KIT="laravel/livewire-starter-kit"; break ;;
            3) LARAVEL_STARTER_KIT="laravel/vue-starter-kit"; break ;;
            4) LARAVEL_STARTER_KIT="laravel/react-starter-kit"; break ;;
            *) echo "Invalid selection. Please enter a number between 1 and 4." ;;
        esac
    done
    echo "-> Selected Starter Kit: $LARAVEL_STARTER_KIT"
}

# Validation for existing directory
validate_directory() {
    if [ "$1" == "." ]; then return 0; fi
    if [ ! -d "$1" ]; then
        echo "The directory '$1' does not exist. Please create it first or provide an existing path."
        return 1
    fi
    return 0
}

# Check if Docker is running
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "❌ ERROR: Docker command not found. Please install Docker first." 
        exit 1
    fi
    if ! docker info &> /dev/null; then
        echo "❌ ERROR: Docker daemon is not running. Please start Docker." 
        exit 1
    fi
    echo "✅ Docker is running"
}

# Wait for the MySQL container to be ready
wait_for_db() {
    echo "   ⏳ Waiting for database to become ready (Max 60s)..."
    local attempts=0
    while ! docker compose exec db mysqladmin ping -h db --silent &> /dev/null; do
        sleep 2
        attempts=$((attempts+1))
        if [ $attempts -ge 30 ]; then
            echo "   ❌ ERROR: Database failed to start within 60 seconds."
            echo "   💡 Try: docker compose logs db"
            exit 1
        fi
    done
    echo "   ✅ Database is ready"
}

# Detect user's shell configuration file
detect_shell_config() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        if [ -f "$HOME/.bashrc" ]; then
            echo "$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            echo "$HOME/.bash_profile"
        fi
    fi
}

# --- Main Script ---

clear
echo "==================================================="
echo "   🚀 Laravel Docker Setup - Local Development"
echo "==================================================="
echo "   PHP $PHP_VERSION | Caddy | MySQL | Redis"
echo "   Horizon + Telescope Pre-configured"
echo "==================================================="
echo ""

# 1. Get Project Details
prompt_for_input "Enter the **Project Name** (e.g., my-blog-app)" "PROJECT_NAME" "" "" "false"
prompt_for_input "Enter the **Installation Directory**" "INSTALL_DIR" validate_directory "." "false"

# 2. Select Laravel Starter Kit
echo ""
prompt_for_starter_kit

# 3. Get Port Configuration
echo ""
echo "--- Port Configuration ---"
prompt_for_input "Enter the **Host Port** for HTTP access" "WEB_HOST_PORT" "" "$WEB_HOST_PORT" "false"
prompt_for_input "Enter the **Host Port** for Database access" "DB_HOST_PORT" "" "$DB_HOST_PORT" "false"
prompt_for_input "Enter the **Host Port** for Redis access" "REDIS_EXTERNAL_PORT" "" "$REDIS_EXTERNAL_PORT" "false"

# 4. Get Database Configuration
echo ""
echo "--- Database Configuration ---"
prompt_for_input "Enter the **Database Name**" "DB_DATABASE" "" "$DB_DATABASE" "false"
prompt_for_input "Enter the **Database User**" "DB_USERNAME" "" "$DB_USERNAME" "false"
prompt_for_input "Enter the **Database Password** (for local dev)" "DB_PASSWORD" "" "" "true"

PROJECT_DIR="$INSTALL_DIR/$PROJECT_NAME"

# 5. Check and Create Project Directory
echo ""
if [ -d "$PROJECT_DIR" ]; then
    read -r -p "⚠️  Directory '$PROJECT_DIR' already exists. Overwrite? (y/N): " response
    case "$response" in
        [yY][eE][sS]|[yY]) echo "Proceeding..." ;;
        *) echo "❌ Aborting setup." ; exit 1 ;;
    esac
else
    echo "📁 Creating project directory: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
fi

cd "$PROJECT_DIR" || exit

# --- Generate APP_KEY ---
echo ""
echo "🔑 Generating secure APP_KEY..."
if command -v openssl &> /dev/null; then
    APP_KEY_BASH_GENERATED="base64:$(openssl rand -base64 32 | tr -d '\n')"
    echo "   ✅ Key generated using OpenSSL"
elif command -v head &> /dev/null && command -v base64 &> /dev/null; then
    APP_KEY_BASH_GENERATED="base64:$(head /dev/urandom | base64 | tr -d '\n' | head -c 44)"
    echo "   ✅ Key generated using head/base64"
else
    echo "❌ ERROR: Neither openssl nor base64 found. Cannot generate APP_KEY."
    exit 1
fi

# 6. Create Project Structure
echo ""
echo "📦 Creating project structure..."
mkdir -p src docker/php docker/caddy

# --- A. .env (Local Development Configuration)
cat << EOF > .env
# =================================================
# LOCAL DEVELOPMENT ENVIRONMENT
# =================================================

# --- Network Configuration ---
WEB_HOST_PORT=$WEB_HOST_PORT
DOMAIN=$DOMAIN_NAME

# --- Database Configuration ---
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=$DB_DATABASE
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD

# --- MySQL Container Initialization ---
MYSQL_ROOT_PASSWORD=$DB_PASSWORD
MYSQL_DATABASE=$DB_DATABASE
MYSQL_USER=$DB_USERNAME
MYSQL_PASSWORD=$DB_PASSWORD

# --- Laravel Application ---
APP_NAME=$PROJECT_NAME
APP_ENV=local
APP_KEY=$APP_KEY_BASH_GENERATED
APP_DEBUG=true
APP_TIMEZONE=UTC
APP_URL=http://$DOMAIN_NAME:$WEB_HOST_PORT

LOG_CHANNEL=stack
LOG_LEVEL=debug

# --- Redis Configuration ---
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=null

# --- Cache, Session, Queue (Using Redis) ---
CACHE_DRIVER=redis
SESSION_DRIVER=redis
SESSION_LIFETIME=120
QUEUE_CONNECTION=redis

# --- Mail (Log driver for local dev) ---
MAIL_MAILER=log

# --- Vite ---
VITE_APP_NAME="\${APP_NAME}"
EOF
echo "   ✅ Created .env file"

# --- B. .env.example
cat << EOF > .env.example
# =================================================
# ENVIRONMENT CONFIGURATION TEMPLATE
# =================================================
# Copy this file to .env and fill in your values

# --- Network Configuration ---
WEB_HOST_PORT=$WEB_HOST_PORT
DOMAIN=$DOMAIN_NAME

# --- Database Configuration ---
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=$DB_DATABASE
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=

# --- MySQL Container Initialization ---
MYSQL_ROOT_PASSWORD=
MYSQL_DATABASE=$DB_DATABASE
MYSQL_USER=$DB_USERNAME
MYSQL_PASSWORD=

# --- Laravel Application ---
APP_NAME=$PROJECT_NAME
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_TIMEZONE=UTC
APP_URL=http://\${DOMAIN}:\${WEB_HOST_PORT}

LOG_CHANNEL=stack
LOG_LEVEL=debug

# --- Redis Configuration ---
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=null

# --- Cache, Session, Queue ---
CACHE_DRIVER=redis
SESSION_DRIVER=redis
SESSION_LIFETIME=120
QUEUE_CONNECTION=redis

# --- Mail ---
MAIL_MAILER=log

# --- Vite ---
VITE_APP_NAME="\${APP_NAME}"
EOF
echo "   ✅ Created .env.example"

# --- C. .gitignore
cat << EOF > .gitignore
# Environment & Secrets
.env
.env.backup

# Docker Local Overrides
docker-compose.override.yml

# Laravel
/vendor
/node_modules
/public/hot
/public/storage
/storage/*.key
/storage/app/*
!/storage/app/.gitignore
/storage/framework/cache/*
!/storage/framework/cache/.gitignore
/storage/framework/sessions/*
!/storage/framework/sessions/.gitignore
/storage/framework/views/*
!/storage/framework/views/.gitignore
/storage/logs/*
!/storage/logs/.gitignore
/bootstrap/cache/*
!/bootstrap/cache/.gitignore

# IDE
.idea
.vscode
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Docker Volumes
db-data
caddy_data
redis-data

# Logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
EOF
echo "   ✅ Created .gitignore"

# --- D. .dockerignore
cat << EOF > .dockerignore
.git
.gitignore
.env
.env.example
node_modules
vendor
storage/logs
storage/framework/cache
storage/framework/sessions
storage/framework/views
.DS_Store
Thumbs.db
*.log
EOF
echo "   ✅ Created .dockerignore"

# --- E. docker/php/Dockerfile
cat << EOF > docker/php/Dockerfile
FROM php:${PHP_VERSION}-fpm-alpine

# Install system dependencies and PHP extensions
RUN set -eux; \
    apk add --no-cache \
        git \
        curl \
        libxml2-dev \
        libzip-dev \
        oniguruma-dev \
        nodejs \
        npm \
        postgresql-dev \
        libpng \
        libjpeg-turbo \
        freetype \
    && apk add --no-cache --virtual .build-deps \
        autoconf \
        g++ \
        make \
        pcre-dev \
        freetype-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        icu-dev \
        curl-dev \
        linux-headers \
    && docker-php-ext-install -j\$(nproc) \
        bcmath \
        curl \
        gd \
        intl \
        mbstring \
        pcntl \
        pdo_mysql \
        pdo_pgsql \
        sockets \
        zip \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/* /tmp/pear

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Set working directory
WORKDIR /var/www

# Expose PHP-FPM port
EXPOSE 9000

CMD ["php-fpm"]
EOF
echo "   ✅ Created docker/php/Dockerfile"

# --- F. docker/caddy/Caddyfile (Local Development)
cat << EOF > docker/caddy/Caddyfile
:80 {
    # Root directory
    root * /var/www/src/public

    # PHP-FPM configuration
    php_fastcgi app:9000

    # Serve static files
    file_server

    # Enable gzip compression
    encode gzip

    # Logging
    log {
        output stdout
        level INFO
    }
}
EOF
echo "   ✅ Created docker/caddy/Caddyfile"

# --- G. docker-compose.yml
cat << EOF > docker-compose.yml
services:
  # PHP Application
  app:
    build:
      context: ./docker/php
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME}_app
    restart: unless-stopped
    working_dir: /var/www/src
    volumes:
      - ./src:/var/www/src
    expose:
      - "5173"
    env_file:
      - .env
    networks:
      - laravel-net
    depends_on:
      - db
      - redis

  # Caddy Web Server
  web:
    image: caddy:2-alpine
    container_name: ${PROJECT_NAME}_web
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./src:/var/www/src
      - ./docker/caddy/Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - app
    networks:
      - laravel-net

  # MySQL Database
  db:
    image: mysql:8.0
    container_name: ${PROJECT_NAME}_db
    restart: unless-stopped
    env_file:
      - .env
    volumes:
      - db-data:/var/lib/mysql
    networks:
      - laravel-net
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis Cache/Queue
  redis:
    image: redis:alpine
    container_name: ${PROJECT_NAME}_redis
    restart: unless-stopped
    volumes:
      - redis-data:/data
    networks:
      - laravel-net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Laravel Queue Worker
  worker:
    build:
      context: ./docker/php
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME}_worker
    restart: unless-stopped
    working_dir: /var/www/src
    volumes:
      - ./src:/var/www/src
    command: php artisan queue:work --verbose --tries=3 --timeout=90
    env_file:
      - .env
    depends_on:
      - app
      - redis
      - db
    networks:
      - laravel-net

networks:
  laravel-net:
    driver: bridge

volumes:
  db-data:
    driver: local
  caddy_data:
    driver: local
  caddy_config:
    driver: local
  redis-data:
    driver: local
EOF
echo "   ✅ Created docker-compose.yml"

# --- H. docker-compose.override.yml (Local port mappings)
cat << EOF > docker-compose.override.yml
# =================================================
# LOCAL DEVELOPMENT OVERRIDES
# =================================================
# This file is excluded from version control
# It exposes ports for local development tools

services:
  app:
    ports:
      # Vite HMR
      - "5173:5173"

  web:
    ports:
      # HTTP (overrides the base file for custom port)
      - "${WEB_HOST_PORT}:80"

  db:
    ports:
      # MySQL (for database GUI tools)
      - "${DB_HOST_PORT}:3306"

  redis:
    ports:
      # Redis (for Redis GUI tools)
      - "${REDIS_EXTERNAL_PORT}:6379"
EOF
echo "   ✅ Created docker-compose.override.yml"

# --- 7. Execute Setup Commands ---
echo ""
echo "==================================================="
echo "🐳 Starting Docker Setup"
echo "==================================================="

check_docker

echo ""
echo "📦 Step 1: Building custom PHP image..."
docker compose build --no-cache

echo ""
echo "📦 Step 2: Creating Laravel project ($LARAVEL_STARTER_KIT)..."
docker compose run --rm app composer create-project "$LARAVEL_STARTER_KIT" /var/www/src --no-scripts

echo ""
echo "📦 Step 3: Copying environment configuration..."
cp .env ./src/.env

echo ""
echo "📦 Step 4: Installing NPM dependencies..."
docker compose run --rm app npm install

echo ""
echo "📦 Step 5: Installing Laravel Horizon (Queue Monitoring)..."
docker compose run --rm app composer require laravel/horizon --quiet

echo ""
echo "📦 Step 6: Installing Laravel Telescope (Debugging)..."
docker compose run --rm app composer require laravel/telescope --quiet

echo ""
echo "🚀 Step 7: Starting all services..."
docker compose up -d

echo ""
echo "⏳ Step 8: Waiting for services to be ready..."
sleep 5

echo ""
echo "📦 Step 9: Publishing Horizon assets..."
docker compose exec app php /var/www/src/artisan horizon:install --quiet

echo ""
echo "📦 Step 10: Publishing Telescope assets..."
docker compose exec app php /var/www/src/artisan telescope:install --quiet

echo ""
echo "🔧 Step 11: Configuring Vite for Docker..."
# Auto-configure vite.config.js for Docker HMR
cat << 'VITE_EOF' > src/vite.config.js
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
        }),
    ],
    server: {
        host: '0.0.0.0',
        port: 5173,
        hmr: {
            host: 'localhost'
        },
        watch: {
            usePolling: true
        }
    }
});
VITE_EOF
echo "   ✅ Vite configured for Docker HMR"

echo ""
echo "🔧 Step 12: Setting up storage and permissions..."
docker compose exec app php /var/www/src/artisan storage:link
docker compose exec app chown -R www-data:www-data /var/www/src/storage /var/www/src/bootstrap/cache
docker compose exec app chmod -R 775 /var/www/src/storage /var/www/src/bootstrap/cache
echo "   ✅ Storage linked and permissions set"

echo ""
echo "🔧 Step 13: Clearing configuration cache..."
docker compose exec app php /var/www/src/artisan config:clear

# Prompt for migrations
echo ""
read -r -p "📊 Run database migrations now? (y/N): " run_migrations
if [[ "$run_migrations" =~ ^[yY]$ ]]; then
    wait_for_db
    echo ""
    echo "🔄 Running migrations (includes Horizon and Telescope)..."
    docker compose exec app php /var/www/src/artisan migrate --force
    echo "   ✅ Migrations completed"
else
    echo "   ⏭️  Skipping migrations (run manually later)"
fi

# --- Add helpful aliases ---
echo ""
SHELL_CONFIG=$(detect_shell_config)
if [ -n "$SHELL_CONFIG" ]; then
    read -r -p "🔧 Add helpful aliases to $SHELL_CONFIG? (y/N): " add_aliases
    if [[ "$add_aliases" =~ ^[yY]$ ]]; then
        cat << ALIAS_EOF >> "$SHELL_CONFIG"

# ===== Laravel Docker Aliases for $PROJECT_NAME =====
alias ${PROJECT_NAME}-art='cd $PROJECT_DIR && docker compose exec app php /var/www/src/artisan'
alias ${PROJECT_NAME}-composer='cd $PROJECT_DIR && docker compose exec app composer'
alias ${PROJECT_NAME}-npm='cd $PROJECT_DIR && docker compose exec app npm'
alias ${PROJECT_NAME}-test='cd $PROJECT_DIR && docker compose exec app php /var/www/src/artisan test'
alias ${PROJECT_NAME}-shell='cd $PROJECT_DIR && docker compose exec app sh'
alias ${PROJECT_NAME}-logs='cd $PROJECT_DIR && docker compose logs -f'
alias ${PROJECT_NAME}-up='cd $PROJECT_DIR && docker compose up -d'
alias ${PROJECT_NAME}-down='cd $PROJECT_DIR && docker compose down'
alias ${PROJECT_NAME}-restart='cd $PROJECT_DIR && docker compose restart'
ALIAS_EOF
        echo "   ✅ Aliases added! Run: source $SHELL_CONFIG"
    fi
fi

# --- Final Success Message ---
echo ""
echo "==================================================="
echo "✨ SETUP COMPLETE! Your Laravel project is ready!"
echo "==================================================="
echo ""
echo "📁 Project Location:"
echo "   $PROJECT_DIR"
echo ""
echo "🌐 Access URLs:"
echo "   Application:  http://localhost:$WEB_HOST_PORT"
echo "   Horizon:      http://localhost:$WEB_HOST_PORT/horizon"
echo "   Telescope:    http://localhost:$WEB_HOST_PORT/telescope"
echo ""
echo "🔌 Database Connection (for GUI tools):"
echo "   Host:     localhost"
echo "   Port:     $DB_HOST_PORT"
echo "   Database: $DB_DATABASE"
echo "   Username: $DB_USERNAME"
echo ""
echo "🔴 Redis Connection (for GUI tools):"
echo "   Host:     localhost"
echo "   Port:     $REDIS_EXTERNAL_PORT"
echo ""
echo "📦 Starter Kit: $LARAVEL_STARTER_KIT"
echo ""
echo "==================================================="
echo "🚀 QUICK START COMMANDS"
echo "==================================================="
echo ""
echo "Start Vite dev server (for hot reload):"
echo "   cd $PROJECT_DIR"
echo "   docker compose exec app npm run dev"
echo ""
echo "Run artisan commands:"
echo "   docker compose exec app php /var/www/src/artisan [command]"
echo ""
echo "Run migrations:"
echo "   docker compose exec app php /var/www/src/artisan migrate"
echo ""
echo "View logs:"
echo "   docker compose logs -f"
echo ""
echo "Stop all services:"
echo "   docker compose down"
echo ""
echo "Restart services:"
echo "   docker compose restart"
echo ""
echo "Access container shell:"
echo "   docker compose exec app sh"
echo ""
if [ -n "$SHELL_CONFIG" ] && [[ "$add_aliases" =~ ^[yY]$ ]]; then
    echo "==================================================="
    echo "🎯 CUSTOM ALIASES (After sourcing shell config)"
    echo "==================================================="
    echo ""
    echo "   ${PROJECT_NAME}-art [command]    - Run artisan commands"
    echo "   ${PROJECT_NAME}-composer [cmd]   - Run composer commands"
    echo "   ${PROJECT_NAME}-npm [command]    - Run npm commands"
    echo "   ${PROJECT_NAME}-test             - Run PHPUnit tests"
    echo "   ${PROJECT_NAME}-shell            - Access container shell"
    echo "   ${PROJECT_NAME}-logs             - Follow container logs"
    echo "   ${PROJECT_NAME}-up               - Start services"
    echo "   ${PROJECT_NAME}-down             - Stop services"
    echo "   ${PROJECT_NAME}-restart          - Restart services"
    echo ""
    echo "💡 Don't forget to run: source $SHELL_CONFIG"
    echo ""
fi
echo "==================================================="
echo "Happy coding! 🎉"
echo "==================================================="

exit 0
