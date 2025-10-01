
# 🚀 Dockerized Laravel Development Environment (PHP 8.4, Caddy/Automatic HTTPS)

This repository contains a modern, production-ready setup for developing Laravel applications using Docker Compose. It leverages **Caddy** as a reverse proxy for automatic local and production HTTPS management, replacing the need for separate Nginx and Certbot configurations.

## ✨ Features

* **Custom PHP 8.4 FPM/Alpine Image:** Lightweight, pre-configured with required Laravel extensions (`pdo_mysql`, `zip`, `opcache`).
* **Caddy Web Server:** Handles all web traffic, providing **automatic HTTPS** (via Let's Encrypt in production, self-signed locally) and acting as a reverse proxy to PHP-FPM.
* **MySQL 8.0:** Dedicated container for database persistence.
* **One-Command Setup:** Use the provided script to initialize the entire project, including Laravel installation, configuration, and environment variable setup.
* **Zero Configuration Change for Production:** All environment differences (ports, domains, debug status) are managed via the `.env` file, meaning the core Docker files remain static and committed to Git.

***

## 1. Prerequisites

You must have the following installed on your local machine:

* **Git**
* **Docker Engine** (Minimum Version 20.10)
* **Docker Compose (v2)** (Available via `docker compose` command)

***

## 2. Project Architecture

The application is split into three core services defined in `docker-compose.yml`:

| Service | Image/Version | Role | Internal Port |
| :--- | :--- | :--- | :--- |
| **`app`** | Custom PHP 8.4 FPM | Runs the Laravel application, Composer, and Artisan commands. | 9000 |
| **`web`** | `caddy:2-alpine` | Web server, reverse proxy, and **automatic HTTPS/SSL termination**. | 80, 443 |
| **`db`** | `mysql:8.0` | Persistent MySQL database. | 3306 |

### Directory Structure

```text
.
├── src/                      # Laravel application files (bind mounted)
├── docker/
│   ├── caddy/
│   │   └── Caddyfile         # Caddy config for proxying to PHP-FPM
│   └── php/
│       └── Dockerfile        # Custom PHP image blueprint
├── docker-compose.yml        # Orchestration file
├── .env                      # Local variables (Ignored by Git)
├── .env.example              # Template for all required variables (Committed)
└── setup_laravel_docker.sh   # Automation script
```

***

## 3. Quick Start (Using the Automation Script)

The provided script automates directory creation, file generation, Docker building, and initial Laravel installation.

1.  **Run the script:**
    ```bash
    chmod +x setup_laravel_docker.sh
    ./setup_laravel_docker.sh
    ```

2.  **Follow the prompts:** The script will ask for:
    * **Project Name** (e.g., `my-blog-app`)
    * **Installation Directory** (e.g., `/Users/dev/Code`)
    * **Host Port** (e.g., `8000`)
    * **Database Credentials** (Name, User, Password)

3.  **Access the Application:** Once the script finishes, your app will be available at:
    * `http://localhost:<YOUR_HOST_PORT>` (e.g., `http://localhost:8000`)

***

## 4. Development Workflow & Shortcuts

The most efficient way to interact with the containers is by setting up **shell aliases**.

### A. Setup Shell Aliases

Add the following lines to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.). **Be sure to update the `cd` path to your project directory.**

```bash
# Example Aliases (Update the path and project name)
alias art='cd /path/to/your/project && docker compose exec app php /var/www/src/artisan'
alias comp='cd /path/to/your/project && docker compose exec app composer'
```

### B. Usage
| Task                | Alias Command             | Equivalent Full Command                                         |
|----------------------|---------------------------|-----------------------------------------------------------------|
| Run migrations       | `art migrate`             | `docker compose exec app php /var/www/src/artisan migrate`      |
| Make a model         | `art make:model Post`     | `docker compose exec app php /var/www/src/artisan make:model Post` |
| Install dependencies | `comp install`            | `docker compose exec app composer install`                      |
| Run tests            | `art test`                | `docker compose exec app php /var/www/src/artisan test`         |



## 5. Multi-Project Management
You can run multiple Laravel projects simultaneously with this architecture:

**Service Names:** Keep service names (app, web, db) identical in all projects' docker-compose.yml files. Docker uses the project directory name to prevent container name conflicts.

**Host Port:** Ensure each project uses a unique WEB_HOST_PORT in its respective .env file (e.g., Project A uses 8000, Project B uses 8001).

**Execution:** Always execute docker compose commands from the target project's root directory.

## 6. Deployment to EC2 (Production)
Deployment requires zero changes to your docker-compose.yml, Dockerfile, or Caddyfile. All modifications are handled via the production .env file.

### A. Production .env Changes
On your remote server (EC2):
Manually create a secure production .env file (never commit it to Git).
Update the critical variables:

| Key           | Local                 | Production                  |
|---------------|-----------------------|-----------------------------|
| APP_ENV       | local                 | production                  |
| APP_DEBUG     | true                  | false                       |
| WEB_HOST_PORT | 8000                  | 80                          |
| DOMAIN        | localhost             | your_domain.com             |
| DB_PASSWORD   | (Simple)              | (Strong, unique secret)     |
| APP_URL       | http://localhost:8000 | https://your_domain.com     |


### B. Execution Steps on the Server
Clone the repository and cd into the project directory.
Run the containers and enable Caddy/SSL:

```Bash
docker compose up --build -d
Caddy automatically requests a Let's Encrypt certificate for the domain specified in the .env file.
```

Run post-deployment commands:

```Bash
# Generate/ensure unique key (if not done previously)
docker compose exec app php /var/www/src/artisan key:generate

# Run migrations
docker compose exec app php /var/www/src/artisan migrate --force

# Optimize Laravel for performance
docker compose exec app php /var/www/src/artisan config:cache
docker compose exec app php /var/www/src/artisan route:cache
```
