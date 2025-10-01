#!/bin/bash

# --- Configuration ---
PHP_VERSION="8.4"
PROJECT_NAME=""
INSTALL_DIR=""
WEB_HOST_PORT=""
DB_DATABASE=""
DB_USERNAME=""
DB_PASSWORD=""

# --- Functions ---

# Function to prompt user and validate input
prompt_for_input() {
    local prompt_msg=$1
    local var_name=$2
    local validation_func=$3
    local default_value=$4

    while true; do
        # Display prompt with default value if provided
        if [ -n "$default_value" ]; then
            read -p "$prompt_msg (Default: $default_value): " input
        else
            read -p "$prompt_msg: " input
        fi

        # Use default value if input is empty and a default exists
        if [ -z "$input" ] && [ -n "$default_value" ]; then
            input="$default_value"
        fi

        # Run custom validation function if provided
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

# Simple validation for non-empty directory
validate_directory() {
    if [ ! -d "$1" ]; then
        echo "The directory '$1' does not exist. Please create it first or provide an existing path."
        return 1
    fi
    return 0
}

# --- Main Script ---

echo "==================================================="
echo "    Laravel Docker Setup Script (PHP $PHP_VERSION, Caddy)"
echo "==================================================="

# 1. Get Project Details
prompt_for_input "Enter the **Project Name** (e.g., my-blog-app)" "PROJECT_NAME"
prompt_for_input "Enter the **Installation Directory** (e.g., /Users/user/Projects)" "INSTALL_DIR" validate_directory

# 2. Get Custom Credentials and Port
echo "--- Customizing Environment Variables ---"
prompt_for_input "Enter the **Host Port** for HTTP access" "WEB_HOST_PORT" "" "8000"
prompt_for_input "Enter the **Database Name**" "DB_DATABASE" "" "laravel_db"
prompt_for_input "Enter the **Database User**" "DB_USERNAME" "" "docker_user"
prompt_for_input "Enter the **Database Password** (REQUIRED)" "DB_PASSWORD"

PROJECT_DIR="$INSTALL_DIR/$PROJECT_NAME"

# 3. Check and Create Project Directory
if [ -d "$PROJECT_DIR" ]; then
    read -r -p "Directory '$PROJECT_DIR' already exists. Overwrite contents? (y/N): " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            echo "Proceeding with existing directory..."
            ;;
        *)
            echo "Aborting setup. Please choose a different project name or directory."
            exit 1
            ;;
    esac
else
    echo "Creating project directory: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
fi

cd "$PROJECT_DIR" || exit

# 4. Create necessary subdirectories
echo "Creating subdirectories..."
mkdir -p src docker/php docker/caddy

# 5. Create Blueprints and Configuration Files (using variables)

# --- A. .env.example (Template for Configuration) ---
# Note: The .env.example contains the variables themselves, not the user's input values.
cat << EOF > .env.example
# --- Host/Network Configuration ---
WEB_HOST_PORT=8000
DOMAIN=localhost

# --- Database Configuration ---
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=laravel_db
DB_USERNAME=docker_user
DB_PASSWORD=password_secret

# --- Laravel Application Configuration ---
APP_ENV=local
APP_DEBUG=true
APP_URL=http://localhost:\${WEB_HOST_PORT}
APP_KEY=
EOF

# --- B. .env (Local Copy with User's Values) ---
cat << EOF > .env
# --- Host/Network Configuration ---
WEB_HOST_PORT=$WEB_HOST_PORT
DOMAIN=localhost

# --- Database Configuration ---
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=$DB_DATABASE
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD

# --- Laravel Application Configuration ---
APP_ENV=local
APP_DEBUG=true
APP_URL=http://localhost:\${WEB_HOST_PORT}
APP_KEY=
EOF

# --- C. .gitignore ---
# (Content remains the same as before)
cat << EOF > .gitignore
# Sensitive Data
.env

# Laravel Build Artifacts
/vendor
/node_modules
/storage
/bootstrap/cache/*.php

# Docker Volumes/Logs
db-data
caddy_data
*.log
EOF

# --- D. docker/php/Dockerfile --- (Unchanged)
cat << EOF > docker/php/Dockerfile
FROM php:${PHP_VERSION}-fpm-alpine

RUN apk update && apk add --no-cache \\
    git \\
    curl \\
    libxml2-dev \\
    libzip-dev \\
    && docker-php-ext-install pdo_mysql opcache zip \\
    && rm -rf /var/cache/apk/*

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www
EXPOSE 9000
EOF

# --- E. docker/caddy/Caddyfile --- (Unchanged)
cat << EOF > docker/caddy/Caddyfile
# Uses the DOMAIN variable defined in the .env file
{\${DOMAIN}} {

    root * /var/www/src/public
    
    # Automatic HTTPS (handled by Caddy)

    try_files {path} {path}/ /index.php?{query}

    # Pass PHP files to the PHP-FPM service (our 'app' container)
    php_fastcgi app:9000

    encode gzip
    log
}
EOF

# --- F. docker-compose.yml --- (Uses PROJECT_NAME variable for container names)
cat << EOF > docker-compose.yml
version: '3.8'

services:
  # 1. PHP Application Service (app)
  app:
    build:
      context: .
      dockerfile: docker/php/Dockerfile
    container_name: ${PROJECT_NAME}_app
    working_dir: /var/www/src/
    command: php artisan
    volumes:
      - ./src:/var/www/src
    environment:
      DB_HOST: \${DB_HOST}
      DB_DATABASE: \${DB_DATABASE}
      DB_USERNAME: \${DB_USERNAME}
      DB_PASSWORD: \${DB_PASSWORD}
      APP_ENV: \${APP_ENV}
      APP_DEBUG: \${APP_DEBUG}
      APP_URL: \${APP_URL}
      APP_KEY: \${APP_KEY}
    networks:
      - laravel-net

  # 2. Caddy Web Server Service (web)
  web:
    image: caddy:2-alpine
    container_name: ${PROJECT_NAME}_web
    ports:
      - "\${WEB_HOST_PORT}:80"
      - "443:443"
    volumes:
      - ./src:/var/www/src
      - ./docker/caddy/Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
    environment:
      DOMAIN: \${DOMAIN}
    depends_on:
      - app
    networks:
      - laravel-net

  # 3. Database Service (db)
  db:
    image: mysql:8.0
    container_name: ${PROJECT_NAME}_db
    environment:
      MYSQL_ROOT_PASSWORD: \${DB_PASSWORD}
      MYSQL_DATABASE: \${DB_DATABASE}
      MYSQL_USER: \${DB_USERNAME}
      MYSQL_PASSWORD: \${DB_PASSWORD}
    volumes:
      - db-data:/var/lib/mysql
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
EOF

echo "All configuration files created successfully in $PROJECT_DIR."

# 6. Execute Setup Commands

echo "--- Executing Docker Setup Commands ---"

# Build Image
echo "1. Building the custom PHP image..."
docker compose build

# Create Laravel Project
echo "2. Running Composer to create the Laravel project..."
docker compose run --rm app composer create-project laravel/laravel /var/www/src

# Start Containers
echo "3. Starting services (app, web, db) in detached mode..."
docker compose up -d

# Final Configuration
echo "4. Generating Laravel application key and fixing permissions..."
# Generate key
docker compose exec app php /var/www/src/artisan key:generate

# Fix permissions
docker compose exec app chmod -R 777 src/storage src/bootstrap/cache

# 7. Final Instructions
echo "==================================================="
echo "✅ SETUP COMPLETE! Your project is ready."
echo "==================================================="
echo "Project Location: $PROJECT_DIR"
echo "Access URL: http://localhost:$WEB_HOST_PORT"
echo "---------------------------------------------------"
echo "NEXT STEPS:"
echo "1. Add shell aliases (art & comp) to your ~/.bashrc or ~/.zshrc."
echo "   alias art='cd $PROJECT_DIR && docker compose exec app php /var/www/src/artisan'"
echo "   alias comp='cd $PROJECT_DIR && docker compose exec app composer'"
echo "2. Start coding in the '$PROJECT_DIR/src' directory!"
echo "3. To stop: docker compose down"

exit 0
