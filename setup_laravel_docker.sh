#!/bin/bash

# --- Configuration (Defaults) ---
PHP_VERSION="8.4"
PROJECT_NAME=""
INSTALL_DIR=""
WEB_HOST_PORT="8000"
DB_DATABASE="laravel_db"
DB_USERNAME="docker_user"
DB_PASSWORD=""
DEPLOY_ENV="local"
DOMAIN_NAME="localhost"
DB_HOST_PORT="33061" # NEW DEFAULT PORT
REDIS_EXTERNAL_PORT="6379" # Default port exposed to host machine

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

# Validation for non-empty and existing directory
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
        echo "? ERROR: Docker command not found." ; exit 1
    fi
    if ! docker info &> /dev/null; then
        echo "? ERROR: Docker daemon is not running." ; exit 1
    fi
}

# Wait for the MySQL container to be ready
wait_for_db() {
    echo "     -> Waiting for database to become ready (Max 30s)..."
    local attempts=0
    while ! docker compose exec db mysqladmin ping -h db --silent &> /dev/null; do
        sleep 2
        attempts=$((attempts+1))
        if [ $attempts -ge 15 ]; then
            echo "     -> ERROR: Database failed to start within 30 seconds. Check 'docker compose logs db'."
            exit 1
        fi
    done
    echo "     -> Database is ready."
}

# Validation for environment selection
validate_env() {
    local env_input=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    if [[ "$env_input" != "local" && "$env_input" != "production" ]]; then
        echo "Invalid choice. Please enter 'local' or 'production'."
        return 1
    fi
    return 0
}

# --- Main Script ---

echo "==================================================="
echo "     Laravel Docker Setup Script (PHP $PHP_VERSION, Caddy)"
echo "==================================================="

# 1. Get Project Details
prompt_for_input "Enter the **Project Name** (e.g., my-blog-app)" "PROJECT_NAME" "" "" "false"
prompt_for_input "Enter the **Installation Directory**" "INSTALL_DIR" validate_directory "." "false"

# 2. Get Custom Credentials and Environment
echo "--- Customizing Environment Variables ---"
prompt_for_input "Enter the **Deployment Environment** ('local' or 'production')" "DEPLOY_ENV" validate_env "$DEPLOY_ENV" "false"

if [[ "$DEPLOY_ENV" == "production" ]]; then
    prompt_for_input "Enter the **Domain Name** (e.g., myapp.com) for Caddy" "DOMAIN_NAME" "" "" "false"
    WEB_HOST_PORT="443" # Force standard HTTPS port
    echo "     -> Setting Host Port to 443 (HTTPS) for production."
else
    prompt_for_input "Enter the **Host Port** for HTTP access" "WEB_HOST_PORT" "" "$WEB_HOST_PORT" "false"
    DOMAIN_NAME="localhost" # Ensure it is set to localhost
fi

echo "--- Database Configuration ---"
prompt_for_input "Enter the **Host Port** for Database access (Default: 33061)" "DB_HOST_PORT" "" "$DB_HOST_PORT" "false"
prompt_for_input "Enter the **Database Name**" "DB_DATABASE" "" "$DB_DATABASE" "false"
prompt_for_input "Enter the **Database User**" "DB_USERNAME" "" "$DB_USERNAME" "false"
prompt_for_input "Enter the **Database Password** (REQUIRED)" "DB_PASSWORD" "" "" "true" 

echo "--- Redis Configuration ---"
# NEW PROMPT for the external host port
prompt_for_input "Enter the **Host Port** for Redis access (External/GUI Tools)" "REDIS_EXTERNAL_PORT" "" "$REDIS_EXTERNAL_PORT" "false"

PROJECT_DIR="$INSTALL_DIR/$PROJECT_NAME"

# 3. Check and Create Project Directory
if [ -d "$PROJECT_DIR" ]; then
    read -r -p "Directory '$PROJECT_DIR' already exists. Overwrite contents? (y/N): " response
    case "$response" in
        [yY][eE][sS]|[yY]) echo "Proceeding..." ;;
        *) echo "Aborting setup." ; exit 1 ;;
    esac
else
    echo "Creating project directory: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
fi

cd "$PROJECT_DIR" || exit

# --- Generate APP_KEY ---
echo "--- Generating Cryptographically Secure APP_KEY in Bash ---"
if command -v openssl &> /dev/null; then
    APP_KEY_BASH_GENERATED="base64:$(openssl rand -base64 32 | tr -d '\n')"
    echo "     -> Key generated using OpenSSL."
elif command -v head &> /dev/null && command -v base64 &> /dev/null; then
    APP_KEY_BASH_GENERATED="base64:$(head /dev/urandom | base64 | tr -d '\n' | head -c 44)"
    echo "     -> Key generated using head/base64 fallback."
else
    echo "? ERROR: Neither openssl nor base64 utilities found to generate APP_KEY. Aborting."
    exit 1
fi

# Determine Caddyfile to use based on environment
CADDY_CONFIG_FILE="Caddyfile.$DEPLOY_ENV"

# 4. Create Blueprints and Configuration Files
echo "Creating subdirectories and configuration files..."
mkdir -p src docker/php docker/caddy

# --- A. .env (Contains Secrets and now Redis config)
cat << EOF > .env
# --- Host/Network Configuration ---
WEB_HOST_PORT=$WEB_HOST_PORT
DOMAIN=$DOMAIN_NAME

# --- Database Configuration ---
DB_CONNECTION=mysql
DB_HOST=db
# The internal port used by the app container
DB_PORT=3306
# The host port used for external connections is $DB_HOST_PORT
DB_DATABASE=$DB_DATABASE
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD

# --- Database Configuration (MySQL Container Initialization) ---
# NOTE: These variables are required by the 'mysql:8.0' image entrypoint.
MYSQL_ROOT_PASSWORD=$DB_PASSWORD
MYSQL_DATABASE=$DB_DATABASE
MYSQL_USER=$DB_USERNAME
MYSQL_PASSWORD=$DB_PASSWORD

# --- Laravel Application Configuration ---
APP_ENV=$DEPLOY_ENV
APP_DEBUG=true
APP_URL=http://$DOMAIN_NAME:\${WEB_HOST_PORT}
APP_KEY=$APP_KEY_BASH_GENERATED 

# --- Redis Configuration ---
# 'redis' is the service name defined in docker-compose.yml
# The internal port used by the app container is 6379 (standard Redis port).
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=

# --- Laravel Driver Configuration (Enabled Redis Features) ---
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
EOF
echo "     -> Created .env file with secrets and Redis configuration."
unset DB_PASSWORD

# --- B. .env.example (No Secrets)
cat << EOF > .env.example
# --- Host/Network Configuration ---
WEB_HOST_PORT=$WEB_HOST_PORT
DOMAIN=$DOMAIN_NAME

# --- Database Configuration ---
DB_CONNECTION=mysql
DB_HOST=db
# The internal port used by the app container
DB_PORT=3306
# The host port used for external connections is $DB_HOST_PORT
DB_DATABASE=$DB_DATABASE
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=

# --- Database Configuration (MySQL Container Initialization) ---
# NOTE: These variables are required by the 'mysql:8.0' image entrypoint.
MYSQL_ROOT_PASSWORD=
MYSQL_DATABASE=$DB_DATABASE
MYSQL_USER=$DB_USERNAME
MYSQL_PASSWORD=

# --- Laravel Application Configuration ---
APP_ENV=$DEPLOY_ENV
APP_DEBUG=true
APP_URL=http://\${DOMAIN}:\${WEB_HOST_PORT}
APP_KEY=

# --- Redis Configuration ---
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=

# --- Laravel Driver Configuration ---
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
EOF
echo "     -> Created clean .env.example file."

# --- C. .gitignore
cat << EOF > .gitignore
# Sensitive Data
.env

# Docker Local Overrides
docker-compose.override.yml
docker-compose.production.yml

# Laravel Build Artifacts
/vendor
/node_modules
/storage
/bootstrap/cache/*.php

# Docker Volumes/Logs
db-data
caddy_data
redis-data
*.log
EOF

# --- D. docker/php/Dockerfile (No change, Redis extension already installed)
cat << EOF > docker/php/Dockerfile
FROM php:${PHP_VERSION}-fpm-alpine

# Install all dependencies and extensions in a single, clean, chained RUN command.
RUN set -eux; \
apk add --no-cache \
git \
curl \
libxml2-dev \
libzip-dev \
oniguruma-dev \
nodejs \
npm \
supervisor \
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

WORKDIR /var/www
EXPOSE 9000
EOF
echo "     -> Created docker/php/Dockerfile."


# --- E. docker/caddy/Caddyfile.local
cat << EOF > docker/caddy/Caddyfile.local
:80 {
    # 1. Set the root to the application's public folder
    root * /var/www/src/public

    # 2. Caddy's dedicated PHP directive automatically handles
    # the try_files logic: it checks if the requested file exists, 
    # serves it if it does, otherwise it rewrites to index.php.
    php_fastcgi app:9000

    # 3. Explicitly enable the file server. 
    # Caddy is smart enough to serve files that exist before proxying.
    file_server

    # Additional Directives
    encode gzip
    log
}
EOF

# --- F. docker/caddy/Caddyfile.production
cat << EOF > docker/caddy/Caddyfile.production
${DOMAIN} {
    # Caddy handles automatic HTTPS using the domain from the .env file
    # and redirects HTTP (port 80) to HTTPS (port 443)
    
    # 1. Set the root to the public directory
    root * /var/www/src/public
    
    # 2. Add the file_server directive to handle static assets
    # This must come before (or be correctly handled by) the PHP proxy.
    file_server 

    # 3. Use the php_fastcgi directive to handle dynamic requests.
    # This directive implicitly includes the necessary "try_files" logic 
    # to send non-existing files to index.php.
    php_fastcgi app:9000
    
    # Other Directives
    encode gzip
    log
}
EOF

# --- G. docker-compose.yml (Added Redis service and volume, and the new Worker service)
cat << EOF > docker-compose.yml
services:
    # 1. PHP Application Service (app)
    app:
        build:
            context: ./docker/php
            dockerfile: Dockerfile
        # REMARK: Unique name for this project's app container
        container_name: ${PROJECT_NAME}_app
        working_dir: /var/www/src/
        volumes:
            - ./src:/var/www/src
		# Expose Vite port internally to the docker network
        expose:
            - "5173"
        # REMARK: Loads application environment variables from the .env file
        env_file:
            - .env
        networks:
            - laravel-net

    # 2. Caddy Web Server Service (web)
    web:
        image: caddy:2-alpine
        # REMARK: Unique name for this project's web container
        container_name: ${PROJECT_NAME}_web
        ports:
            # LOCAL USE: This port is mapped in the local override file.
            # PRODUCTION CHANGE: UNCOMMENT '80:80' and ensure '443:443' is kept.
            # - "80:80"
            - "443:443"
        volumes:
            - ./src:/var/www/src
            # DYNAMIC MOUNT: Caddyfile used is determined by DEPLOY_ENV variable.
            - ./docker/caddy/$CADDY_CONFIG_FILE:/etc/caddy/Caddyfile 
            - caddy_data:/data
        environment:
            # PRODUCTION CHANGE: Set the live domain name in your production .env file.
            DOMAIN: ${DOMAIN_NAME}
        depends_on:
            - app
        networks:
            - laravel-net

    # 3. Database Service (db)
    db:
        image: mysql:8.0
        # REMARK: Unique name for this project's database container
        container_name: ${PROJECT_NAME}_db
        # PORTS ARE REMOVED HERE and defined in the local override/production file for security.
        # PRODUCTION CHANGE: REMOVE the entire 'ports' section for security.
        # ports:
            # - "\${DB_HOST_PORT:-33061}:3306"
        
        # REMARK: Loads all DB credentials from the .env file.
        env_file:
            - .env
        
        volumes:
            - db-data:/var/lib/mysql
        networks:
            - laravel-net

    # 4. Redis Caching/Queue Service (redis)
    redis:
        image: redis:alpine
        # REMARK: Unique name for this project's redis container
        container_name: ${PROJECT_NAME}_redis
        volumes:
            - redis-data:/data
        networks:
            - laravel-net

    # 5. Laravel Queue Worker Service (worker)
    worker:
        build:
            context: ./docker/php
            dockerfile: Dockerfile
        # REMARK: Unique name for this project's worker container
        container_name: ${PROJECT_NAME}_worker
        working_dir: /var/www/src/
        volumes:
            - ./src:/var/www/src
        # COMMAND: Run the Laravel queue worker continuously.
        # --verbose shows job logs; --tries=3 retries failures; --timeout=90 sets a job limit.
        command: php artisan queue:work --verbose --tries=3 --timeout=90
        env_file:
            - .env
        depends_on:
            - app
            - redis # Worker must wait for redis to be ready to process jobs
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
    redis-data:
        driver: local
EOF
echo "     -> Created all Caddy, Docker Compose (with Redis and Worker), and Volume files."


# --- H. docker-compose.override.yml (The local file, IGNORED by Git)
cat << EOF > docker-compose.override.yml
# This file overrides the base docker-compose.yml with local, user-specific settings.
# It should be EXCLUDED from version control via .gitignore.

services:
	# 1. PHP Application Service (app)
    web:
        ports:
            # REMARK: Exposes Vite HMR internal port (5173) to the host machine for dev.
			# Remove this in production
            - "5173:5173"
    # 2. Caddy Web Server Service (web)
    web:
        ports:
            # REMARK: Overrides the host port for local HTTP access.
            - "${WEB_HOST_PORT}:80"

    # 3. Database Service (db)
    db:
        ports:
            # REMARK: Exposes the DB internal port (3306) to the host machine (for tools).
            - "${DB_HOST_PORT}:3306"

    # 4. Redis Caching/Queue Service (redis)
    redis:
        ports:
            # REMARK: Exposes the Redis internal port (6379) to the host machine (for GUI tools).
            - "${REDIS_EXTERNAL_PORT}:6379"
EOF
echo "     -> Created docker-compose.override.yml for local settings."

# 5. Execute Setup Commands
echo "--- Checking Docker Status ---"
check_docker

echo "--- Executing Docker Setup Commands ---"

# 1. Build Image (This will now work)
echo "1. Building the custom PHP image..."
docker compose build

# 2. Create Laravel Project
echo "2. Running Composer to create the Laravel project (without internal scripts)..."
# We run composer in the 'app' container which has the PHP image built.
# Use --no-scripts to prevent the post-install scripts (like key:generate) from running
# and causing warnings, as we handle the environment configuration externally.
docker compose run --rm app composer create-project laravel/laravel /var/www/src --no-scripts

# 2.1. Copy the full host-generated .env (with APP_KEY and DB credentials) into the
# Laravel source root so 'artisan' and other commands inside the container can access it.
echo "2.1. Copying host-generated .env into Laravel source directory..."
cp .env ./src/.env

# NPM INSTALL
echo "2.2. Installing front-end dependencies with npm..."
# We use 'docker compose run' again to execute npm in the same temporary container
docker compose run --rm app npm install

# 2.3. Install Laravel Horizon
echo "2.3. Installing Laravel Horizon for queue monitoring..."
docker compose run --rm app composer require laravel/horizon

# 2.4. Publish Horizon Assets and Configuration
echo "2.4. Publishing Horizon assets and configuration..."
docker compose run --rm app php /var/www/src/artisan horizon:install

# 2.5. Install Laravel Telescope
echo "2.5. Installing Laravel Telescope for general debugging..."
docker compose run --rm app composer require laravel/telescope

# 2.6. Publish Telescope Assets and Configuration
echo "2.6. Publishing Telescope assets and configuration..."
docker compose run --rm app php /var/www/src/artisan telescope:install


# 3. Start Containers (Single Run)
echo "3. Starting services (app, web, db, redis, worker) in detached mode..."
docker compose up -d

# 4. Clear config cache and set Permissions
echo "4. Clearing config cache and fixing directory permissions..."
docker compose exec app php /var/www/src/artisan config:clear

# Set Permissions
docker compose exec app chmod -R 777 /var/www/src/storage /var/www/src/bootstrap/cache

# 5. Prompt for Migrations (Database wait is essential here)
read -r -p "5. Do you want to run database migrations now? (y/N): " run_migrations
if [[ "$run_migrations" =~ ^[yY]$ ]]; then
    wait_for_db 
    echo "     -> Running migrations (includes Horizon and Telescope tables)..."
    docker compose exec app php /var/www/src/artisan migrate
else
    echo "     -> Skipping migrations."
fi

# 6. Final Instructions
echo "==================================================="
echo "? SETUP COMPLETE! Your project is ready."
echo "==================================================="
echo "Project Location: $PROJECT_DIR"
if [[ "$DEPLOY_ENV" == "production" ]]; then
    echo "Access URL: https://$DOMAIN_NAME"
else
    echo "Access URL: http://localhost:$WEB_HOST_PORT"
    # Provide the dashboard URLs
    echo "Horizon Dashboard: http://localhost:$WEB_HOST_PORT/horizon"
    echo "Telescope Dashboard: http://localhost:$WEB_HOST_PORT/telescope"
fi
echo "Environment: $DEPLOY_ENV"
echo "---------------------------------------------------"
echo "DATABASE HOST CONNECTION DETAILS:"
echo "Host: localhost"
echo "Port: $DB_HOST_PORT"
echo "User: $DB_USERNAME"
echo "---------------------------------------------------"
echo "REDIS HOST CONNECTION DETAILS (External/GUI Tools):"
echo "Host: localhost"
echo "Port: $REDIS_EXTERNAL_PORT"
echo "---------------------------------------------------"
echo "NEXT STEPS:"
echo "1. Source your shell profile (e.g., ~/.bashrc or ~/.zshrc) after adding aliases."
    echo "     alias art='cd $PROJECT_DIR && docker compose exec app php /var/www/src/artisan'"
    echo "     alias comp='cd $PROJECT_DIR && docker compose exec app composer'"
echo "2. Start coding in the '$PROJECT_DIR/src' directory!"
echo "3. To stop: docker compose down (This stops app, web, db, redis, and worker)"
echo "4. To enable Hot Module Replacement (HMR) for assets, run the Vite server inside the container in a separate terminal: docker compose exec app npm run dev"

exit 0
