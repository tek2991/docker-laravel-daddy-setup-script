# Laravel Docker Setup Script with Caddy, MySQL & Redis

This script automates the creation of a robust, containerized **development and production environment** for Laravel applications. It interactively prompts for configuration details and generates all necessary Docker and Laravel configuration files, including services for the web server, database, caching, and queue workers.

---

## 🚀 Features

- **Interactive Setup:** No manual editing of config files needed — the script guides you through the entire process.  
- **Dockerized Environment:** Fully containerized stack using official images for PHP, Caddy, MySQL 8, and Redis.  
- **Dual Environment Support:** Easily configure for **local development (HTTP)** or **production (automatic HTTPS via Caddy)**.  
- **Caddy Web Server:** A modern, powerful web server that automatically handles HTTPS for production deployments.  
- **Redis Integration:** Preconfigured for caching, session management, and queueing.  
- **Dedicated Queue Worker:** Includes a separate worker service to process Laravel jobs in the background.  
- **Developer Tools Included:**
  - Laravel Horizon — dashboard and code-driven queue configuration.  
  - Laravel Telescope — elegant debug assistant for local development.  
- **Secure by Default:** Generates a secure `APP_KEY`, keeps secrets in `.env`, and separates local overrides from base configuration.  
- **Helpful Aliases:** Suggests convenient shell aliases for running Artisan and Composer inside the container.

---

## 🧱 Prerequisites

Before you begin, ensure you have the following installed:

- A Bash-compatible shell (like **bash** or **zsh**)
- **Docker Engine:** [Installation Guide](https://docs.docker.com/engine/install/)
- **Docker Compose:** [Installation Guide](https://docs.docker.com/compose/install/)

The script also relies on `openssl` or `head/base64` to generate the application key — standard tools available on most Linux and macOS systems.

---

## ⚙️ How to Use

### 1. Save the Script
Save the script content to a file named `setup-laravel.sh`.

### 2. Make it Executable
`chmod +x setup-laravel.sh`

### 3. Run the Script
Execute the script from the directory where you want to create your project:
`./setup-laravel.sh`


### 4. Follow the Prompts

You’ll be asked for:

- **Project Name:** e.g., `my-blog-app`  
- **Installation Directory:** defaults to current directory (`.`)  
- **Deployment Environment:** `local` or `production`  
- **Domain Name (for production):** e.g., `example.com`  
- **Host Ports:** for web, DB, and Redis access  
- **Database Credentials:** username, DB name, and password  

After completion, the script will generate all configuration files, build Docker images, install Laravel, and start the containers.

---

## 📁 Project Structure Explained

Example structure after setup:
```text
/my-blog-app
├── docker/
│ ├── caddy/
│ │ ├── Caddyfile.local
│ │ └── Caddyfile.production
│ └── php/
│   └── Dockerfile
├── src/ <-- YOUR LARAVEL CODE GOES HERE
├── .env <-- Contains all secrets. DO NOT COMMIT.
├── .env.example
├── .gitignore
├── docker-compose.yml
└── docker-compose.override.yml <-- Local-only settings. DO NOT COMMIT.
```

**Key Directories:**

- `src/`: Root of your Laravel application.  
- `docker/`: Contains Dockerfiles and Caddy configurations.  
- `.env`: Runtime environment variables, including DB credentials and `APP_KEY`.  
- `docker-compose.yml`: Defines all core services — app, web, db, redis, worker.  
- `docker-compose.override.yml`: For local development overrides (ignored by Git).

---

## ⚡ Post-Setup Instructions & Common Commands

### Accessing Your Application

- Local URL: `http://localhost:PORT`  
- Horizon Dashboard: `http://localhost:PORT/horizon`  
- Telescope Dashboard: `http://localhost:PORT/telescope`
- View logs for the worker service: `docker compose logs -f project_worker`

### To enable npm run dev add the following to vite.config.js 

``` text
    // *** DOCKER-SPECIFIC HMR CONFIGURATION ***
    server: {
        // Set the host for the Vite server to 0.0.0.0 to listen on all interfaces
        host: '0.0.0.0',
        hmr: {
            // The client must connect to the host machine's address, not the container's internal IP.
            // This URL will be embedded in the JS/CSS files to tell the browser where to find the HMR server.
            host: 'localhost', 
        },
        // IMPORTANT: Must also expose this port in docker-compose.yml
        port: 5173 
    },

```

### Database and Redis Connections

| Service | Host | Port | Credentials            |
|----------|------|------|------------------------|
| MySQL    | localhost | e.g., 33061 | Use values set during setup |
| Redis    | localhost | 6379        | Default or as configured    |

---

### Essential Docker Commands

Run these from your project root (`/my-blog-app`):

#### Stop all containers:
`docker compose down`


#### Start all containers in the background:
`docker compose up -d`


#### View logs for all services:
`docker compose logs -f`


#### View logs for a specific service (e.g., app):
`docker compose logs -f project_app`


#### Rebuild PHP image after Dockerfile changes(docker/php/Dockerfile):
`docker compose build`


#### Manage individual containers:
- **Stop a specific container: ** `docker compose stop container_name`
- **Start a specific container: ** `docker compose start container_name`
- **Restart a specific container: ** `docker compose restart container_name`


---

## 🧩 Suggested Shell Aliases

Add the following to your shell config file (`~/.bashrc` or `~/.zshrc`).  
Replace `/path/to/your/project` with your actual project path.


### Laravel Artisan Alias
`alias art='cd /path/to/your/project && docker compose exec app php /var/www/src/artisan'`

### Composer Alias
`alias comp='cd /path/to/your/project && docker compose exec app composer'`


### Reload your shell:
`source ~/.bashrc`


### Now you can run:
- ** Run migrations: ** `art migrate`
- ** Create a new model: ** `art make:model Product`
- ** Install a new composer package: ** `comp require spatie/laravel-permission`



# ☁️ Deployment to a Remote Server (EC2/VPS)
When deploying to a remote machine, the key differences are setting up the server, transferring the code securely, and launching the containers using the production configuration.

### Server Prerequisites & Setup
Launch Instance: Provision an EC2 instance or VPS (e.g., Ubuntu/Debian).
Install Docker: SSH into the server and install Docker Engine and Docker Compose.

### Example for Ubuntu/Debian

    sudo apt update
    sudo apt install docker.io docker-compose -y
    sudo usermod -aG docker $USER # Add user to docker group (required for non-root usage)
    newgrp docker # Apply group changes immediately

Open Firewall Ports: Ensure your server's firewall (Security Group for EC2, or ufw) permits traffic on:

 1. Port 22 (SSH): For administrative access. Port 80 (HTTP): Required for Caddy to handle redirects.
 2. Port 443 (HTTPS): The main port for production web traffic.
 3. Ports for DB/Redis: Do not open these publicly. They should only be accessible via SSH tunneling.
 4. Prepare Code and Configuration.
 5. Transfer Code: Securely copy your entire project directory (excluding the local .env, but including the empty src/ directory) to the remote server using scp or a similar tool.

**Example to copy your project**

    scp -r /local/path/to/my-blog-app user@server_ip:/remote/path/

Create Production .env: On the remote server, navigate to your project directory and manually create the final production-ready .env file. This file must use your production domain and the actual, strong credentials you intend to use.

Ensure:

 1. APP_ENV=production
 2. APP_URL=https://your-domain.com
 3. WEB_HOST_PORT=443
 4. The correct DOMAIN variable (e.g., DOMAIN=your-domain.com)

Run composer install: Although the script runs this locally, it's best practice to ensure production packages are installed.

### Navigate to project root on the server

    cd /remote/path/my-blog-app

### Use the app container to run composer install
    docker compose run --rm app composer install --no-dev

### Launch Services

 1. Start Containers: Use the standard docker compose up -d command.
 2. Run Migrations: Wait a moment for the DB container to start, then run migrations to set up the production database tables.
 3. `docker compose exec app php /var/www/src/artisan migrate --force`
 4. Check Status: Verify all services are running without errors. `docker compose ps`
 5. `docker compose logs -f web` (The Caddy logs should show it successfully obtaining a Let's Encrypt certificate for your domain.)
 6. Ensure your domain's A record is pointing to the remote server's IP address.
 7. Check worker status: `docker compose logs -f worker`


## 🛡️ Security: 
- Double-check that no unnecessary ports (like 33061 or 6379) are publicly open in the server's firewall configuration.
- SSH Tunnel: Remember to use the SSH Tunneling method to connect your local GUI tools for database and Redis administration.
- Do **not** commit `.env` or `docker-compose.override.yml`.  
- Use separate `.env` files for local and production environments.  
- For production deployments, ensure your domain is correctly configured for HTTPS with Caddy.

---

Made with ❤️ for Laravel developers who want clean, consistent Docker setups.
