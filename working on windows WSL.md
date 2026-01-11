# 🪟 Continue Laravel Development on Windows (WSL)

Complete step-by-step guide for working on your Laravel Docker project using Windows Subsystem for Linux (WSL).

---

## 📋 Part 1: One-Time Windows Setup

### Step 1: Install Required Software

#### 1.1 Install WSL 2 with Ubuntu

Open **PowerShell as Administrator** and run:

```powershell
wsl --install
```

This installs WSL 2 with Ubuntu by default. **Restart your computer** when prompted.

After restart, Ubuntu will open automatically and ask you to create a username and password.

#### 1.2 Install Docker Desktop for Windows

1. Download from: https://www.docker.com/products/docker-desktop/
2. Install with default settings
3. **Important:** In Docker Desktop settings:
   - Go to **Settings → General**
   - Ensure **"Use the WSL 2 based engine"** is checked ✅
   - Go to **Settings → Resources → WSL Integration**
   - Enable integration with your Ubuntu distribution ✅
4. Restart Docker Desktop

#### 1.3 Verify Docker Works in WSL

Open **Ubuntu (WSL)** terminal and run:

```bash
docker --version
docker compose version
```

You should see version numbers. ✅

---

### Step 2: Setup SSH for Git (One-Time)

#### 2.1 Copy Your SSH Key to WSL

If you already have an SSH key for GitHub on your Linux desktop, you need to copy it to WSL.

**On your Linux desktop:**

```bash
# Display your private key
cat ~/.ssh/githubtek2991

# Display your public key
cat ~/.ssh/githubtek2991.pub
```

Copy both outputs.

**On Windows WSL terminal:**

```bash
# Create .ssh directory
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Create and paste private key
nano ~/.ssh/githubtek2991
# Paste the private key content, then save: Ctrl+X, Y, Enter

# Create and paste public key
nano ~/.ssh/githubtek2991.pub
# Paste the public key content, then save: Ctrl+X, Y, Enter

# Set correct permissions
chmod 600 ~/.ssh/githubtek2991
chmod 644 ~/.ssh/githubtek2991.pub
```

#### 2.2 Configure SSH

```bash
# Create/edit SSH config
nano ~/.ssh/config
```

Add this content:

```
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/githubtek2991
    IdentitiesOnly yes
```

Save and exit (Ctrl+X, Y, Enter)

```bash
# Set permissions
chmod 600 ~/.ssh/config
```

#### 2.3 Setup Keychain (Auto-load SSH Key)

```bash
# Install keychain
sudo apt update
sudo apt install keychain -y
```

```bash
# Edit your bash configuration
nano ~/.bashrc
```

**Scroll to the very bottom** and add these lines:

```bash
# SSH Agent with keychain
eval $(keychain --eval --agents ssh ~/.ssh/githubtek2991)
```

Save and exit (Ctrl+X, Y, Enter)

```bash
# Reload your shell configuration
source ~/.bashrc
```

**You'll be prompted for your SSH key passphrase** - enter it. This is the **only time** you'll need to enter it (until you restart Windows).

#### 2.4 Test SSH Connection

```bash
ssh -T git@github.com
```

You should see: `Hi username! You've successfully authenticated...` ✅

---

### Step 3: Clone Your Project

```bash
# Navigate to home directory (or create a projects folder)
cd ~
# Or: mkdir -p ~/projects && cd ~/projects

# Clone your repository
git clone git@github.com:yourusername/your-repo.git

# Navigate into project
cd your-repo
```

---

### Step 4: Initial Project Setup

#### 4.1 Create Environment File

```bash
# Copy example environment file
cp .env.example .env

# Edit the .env file
nano .env
```

**Find and update these lines:**

```env
DB_PASSWORD=your_secure_password_here
```

Make sure `APP_KEY` is already present (it should be from your Linux setup).

Save and exit (Ctrl+X, Y, Enter)

#### 4.2 Verify Docker Compose Files

Your project should have these Docker Compose files from the setup script:

**`docker-compose.yml`** - Base configuration (committed to Git)
- Defines all services (app, web, db, redis, worker)
- Does NOT expose ports to host (for security in production)

**`docker-compose.override.yml`** - Local development overrides (NOT in Git)
- Exposes ports to your host machine for local development
- **Port mappings:**
  - `${WEB_HOST_PORT}:80` - Access your Laravel app
  - `${DB_HOST_PORT}:3306` - Connect to MySQL with GUI tools
  - `${REDIS_EXTERNAL_PORT}:6379` - Connect to Redis with GUI tools
  - `5173:5173` - Vite HMR (hot module replacement)

**Important:** The `docker-compose.override.yml` file should already exist in your cloned repo. If it's missing, create it:

```bash
# Check if it exists
ls -la docker-compose.override.yml

# If missing, create it manually:
nano docker-compose.override.yml
```

Paste this content:

```yaml
# This file overrides the base docker-compose.yml with local, user-specific settings.
# It should be EXCLUDED from version control via .gitignore.

services:
    # 1. PHP Application Service (app)
    app:
        ports:
            # REMARK: Exposes Vite HMR internal port (5173) to the host machine for dev.
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
```

Save and exit (Ctrl+X, Y, Enter)

**Why this file matters:**
- Without it, you can't access your app from Windows browser
- Without it, database GUI tools (like MySQL Workbench) can't connect
- Without it, Vite hot reload won't work
- It's in `.gitignore` because different developers might want different ports

#### 4.3 Start Docker Services

```bash
# Start all Docker containers
docker compose up -d
```

Wait about 10 seconds for containers to fully start.

#### 4.3 Install Dependencies

```bash
# Install PHP dependencies
docker compose exec app composer install

# Install JavaScript dependencies
docker compose exec app npm install
```

#### 4.4 Fix Permissions

```bash
# Set correct ownership and permissions
docker compose exec app chown -R www-data:www-data /var/www/src/storage /var/www/src/bootstrap/cache
docker compose exec app chmod -R 775 /var/www/src/storage /var/www/src/bootstrap/cache
```

#### 4.5 Run Database Migrations

```bash
# Run migrations (including Horizon and Telescope)
docker compose exec app php /var/www/src/artisan migrate
```

#### 4.6 Verify Everything Works

Open your Windows browser and visit:
- **Application:** http://localhost:8000 (or your configured port)
- **Horizon Dashboard:** http://localhost:8000/horizon
- **Telescope Dashboard:** http://localhost:8000/telescope

You should see your Laravel application! ✅

---

## 🔄 Part 2: Daily Workflow

### Starting Work on Windows

#### Step 1: Open WSL Terminal

Open **Ubuntu** app from Windows Start Menu

#### Step 2: Navigate to Project

```bash
cd ~/your-repo
```

#### Step 3: Get Latest Changes

```bash
# Pull latest changes from GitHub
git pull
```

#### Step 4: Check for Updates

**If `composer.json` or `composer.lock` changed:**
```bash
docker compose exec app composer install
```

**If `package.json` or `package-lock.json` changed:**
```bash
docker compose exec app npm install
```

**If new migration files were added:**
```bash
docker compose exec app php /var/www/src/artisan migrate
```

#### Step 5: Start Services (if not already running)

```bash
# Start all services
docker compose up -d

# Check if services are running
docker compose ps
```

#### Step 6: Start Vite Dev Server (for frontend work)

```bash
# Start Vite with hot module replacement
docker compose exec app npm run dev
```

Keep this terminal open while you work. Open a **new WSL terminal** for other commands.

#### Step 7: Start Coding!

**Option A: Use VS Code (Recommended)**

In WSL terminal:
```bash
# Open project in VS Code
code .
```

This opens VS Code on Windows connected to your WSL project! ✅

**Option B: Use any Windows editor**

Access your files at: `\\wsl$\Ubuntu\home\yourusername\your-repo`

You can bookmark this in Windows Explorer.

---

### During Work

#### Common Artisan Commands

```bash
# Create migration
docker compose exec app php /var/www/src/artisan make:migration create_posts_table

# Create model
docker compose exec app php /var/www/src/artisan make:model Post -m

# Create controller
docker compose exec app php /var/www/src/artisan make:controller PostController

# Run tinker (Laravel REPL)
docker compose exec app php /var/www/src/artisan tinker

# Clear caches
docker compose exec app php /var/www/src/artisan cache:clear
docker compose exec app php /var/www/src/artisan config:clear
docker compose exec app php /var/www/src/artisan route:clear
docker compose exec app php /var/www/src/artisan view:clear

# Run tests
docker compose exec app php /var/www/src/artisan test
```

#### View Logs

```bash
# View all container logs
docker compose logs -f

# View specific container logs
docker compose logs -f app
docker compose logs -f web
docker compose logs -f db

# View Laravel logs
docker compose exec app tail -f /var/www/src/storage/logs/laravel.log
```

#### Access Container Shell

```bash
# Access app container shell
docker compose exec app sh

# Once inside, you can run commands without 'docker compose exec app'
# Exit with: exit
```

#### Database Access

```bash
# Access MySQL CLI
docker compose exec db mysql -u docker_user -p laravel_db
# Enter your DB password when prompted
```

Or use GUI tools (MySQL Workbench, DBeaver, etc.) with:
- **Host:** localhost
- **Port:** 33061 (or your configured `DB_HOST_PORT`)
- **Username:** docker_user (or your configured username)
- **Password:** your DB password

---

### Finishing Work on Windows

#### Step 1: Stop Vite (if running)

In the terminal where Vite is running, press `Ctrl+C`

#### Step 2: Stage and Commit Changes

```bash
# Check what files changed
git status

# Add all changes
git add .

# Or add specific files
git add src/app/Models/Post.php src/database/migrations/2024_01_11_create_posts_table.php

# Commit with a descriptive message
git commit -m "Added Post model and migration"
```

#### Step 3: Push to GitHub

```bash
git push
```

#### Step 4: Stop Docker (Optional)

```bash
# Stop all containers (saves system resources)
docker compose down

# Or keep them running for faster startup next time
# Just close the terminal
```

---

### Continuing Work on Linux Desktop

When you switch back to your Linux desktop:

```bash
cd /path/to/your-repo

# Get latest changes
git pull

# Check for dependency updates
docker compose exec app composer install
docker compose exec app npm install

# Run any new migrations
docker compose exec app php /var/www/src/artisan migrate

# Restart services
docker compose restart

# Start Vite
docker compose exec app npm run dev
```

---

## 🛠️ Part 3: Useful Tools & Commands

### VS Code Setup (Highly Recommended)

1. **Install VS Code on Windows:** https://code.visualstudio.com/

2. **Install WSL Extension:**
   - Open VS Code
   - Go to Extensions (Ctrl+Shift+X)
   - Search for "WSL"
   - Install the official "WSL" extension by Microsoft

3. **Open Project from WSL:**
   ```bash
   cd ~/your-repo
   code .
   ```

4. **Recommended VS Code Extensions:**
   - Laravel Extension Pack
   - PHP Intelephense
   - ESLint
   - Prettier
   - Tailwind CSS IntelliSense
   - GitLens

### Quick Access to WSL Files from Windows

**Method 1: File Explorer**
- Press `Win+R`
- Type: `\\wsl$\Ubuntu\home\yourusername\your-repo`
- Bookmark this location

**Method 2: From WSL Terminal**
```bash
# Open current directory in Windows Explorer
explorer.exe .
```

### Git Shortcuts

Add these aliases to `~/.bashrc` for faster git commands:

```bash
nano ~/.bashrc
```

Add at the end:

```bash
# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git pull'
alias glog='git log --oneline --graph --all'
```

Save and reload:
```bash
source ~/.bashrc
```

Now you can use:
```bash
gs              # instead of git status
ga .            # instead of git add .
gc "message"    # instead of git commit -m "message"
gp              # instead of git push
gl              # instead of git pull
```

### Docker Shortcuts

Add these to `~/.bashrc`:

```bash
# Laravel Docker aliases for your-project-name
alias art='docker compose exec app php /var/www/src/artisan'
alias composer='docker compose exec app composer'
alias npm='docker compose exec app npm'
alias test='docker compose exec app php /var/www/src/artisan test'
alias logs='docker compose logs -f'
```

After adding, reload:
```bash
source ~/.bashrc
```

Now you can use:
```bash
art migrate              # instead of docker compose exec app php /var/www/src/artisan migrate
art make:model Post      # instead of docker compose exec app php /var/www/src/artisan make:model Post
composer require package # instead of docker compose exec app composer require package
npm run dev              # instead of docker compose exec app npm run dev
test                     # instead of docker compose exec app php /var/www/src/artisan test
```

---

## 🐛 Part 4: Troubleshooting

### Issue: "Permission denied" errors

**Solution:**
```bash
docker compose exec app chown -R www-data:www-data /var/www/src/storage /var/www/src/bootstrap/cache
docker compose exec app chmod -R 775 /var/www/src/storage /var/www/src/bootstrap/cache
```

### Issue: "Port is already allocated"

**Solution:**
```bash
# Check what's using the port
sudo lsof -i :8000

# Either kill that process or change port in .env
nano .env
# Change WEB_HOST_PORT=8080

# After changing .env, restart containers
docker compose down
docker compose up -d
```

### Issue: Can't access app from Windows browser

**Problem:** Visiting `http://localhost:8000` shows "connection refused"

**Solution:**
```bash
# Verify docker-compose.override.yml exists
ls -la docker-compose.override.yml

# If missing, create it (see Step 4.2 in Part 1)

# Check if ports are actually mapped
docker compose ps

# Look for web service showing something like:
# 0.0.0.0:8000->80/tcp

# If not showing, recreate containers
docker compose down
docker compose up -d
```

### Issue: MySQL Workbench / Database GUI can't connect

**Problem:** Connection refused when trying to connect from Windows

**Solution:**
```bash
# Verify database port is exposed
docker compose ps

# Look for db service showing:
# 0.0.0.0:33061->3306/tcp (or your DB_HOST_PORT)

# If not showing, check docker-compose.override.yml exists
# and has the db ports section

# Connection details for GUI tools:
# Host: localhost (or 127.0.0.1)
# Port: 33061 (or your DB_HOST_PORT from .env)
# Username: docker_user (or your DB_USERNAME from .env)
# Password: (your DB_PASSWORD from .env)
```

### Issue: Vite HMR not working from Windows browser

**Problem:** Vite dev server running but hot reload doesn't work

**Solution:**
```bash
# Check if port 5173 is exposed
docker compose ps

# Look for app service showing:
# 0.0.0.0:5173->5173/tcp

# Verify vite.config.js has correct settings
cat src/vite.config.js

# Should contain:
# server: {
#     host: '0.0.0.0',
#     port: 5173,
#     hmr: { host: 'localhost' }
# }

# Restart Vite
docker compose exec app npm run dev
```

### Issue: Database connection refused

**Solution:**
```bash
# Check if database container is running
docker compose ps

# Check database logs
docker compose logs db

# Restart database
docker compose restart db

# Wait a bit and restart app
sleep 5
docker compose restart app
```

### Issue: Changes not showing up

**Solution:**
```bash
# Clear all Laravel caches
docker compose exec app php /var/www/src/artisan cache:clear
docker compose exec app php /var/www/src/artisan config:clear
docker compose exec app php /var/www/src/artisan route:clear
docker compose exec app php /var/www/src/artisan view:clear

# Restart containers
docker compose restart

# If still not working, rebuild
docker compose down
docker compose up -d --build
```

### Issue: Vite not connecting / HMR not working

**Solution:**
```bash
# Make sure Vite is running
docker compose exec app npm run dev

# Check if port 5173 is exposed
docker compose ps

# Restart app container
docker compose restart app

# Clear browser cache and hard refresh (Ctrl+Shift+R)
```

### Issue: SSH key not loaded (asks for passphrase)

**Solution:**
```bash
# Check if keychain is running
ssh-add -l

# If not working, reload bashrc
source ~/.bashrc

# Enter passphrase when prompted (only once per Windows session)
```

### Issue: Git asking for username/password instead of using SSH

**Solution:**
```bash
# Check remote URL
git remote -v

# If it shows https://, change to SSH
git remote set-url origin git@github.com:yourusername/your-repo.git

# Verify it changed
git remote -v
```

### Issue: Docker containers keep stopping

**Solution:**
```bash
# Check logs to see what's failing
docker compose logs

# Restart Docker Desktop
# Right-click Docker Desktop icon → Restart

# Try starting containers again
docker compose up -d
```

---

## ✅ Part 5: Quick Reference Checklist

### First Time Setup on Windows
- [ ] WSL 2 with Ubuntu installed
- [ ] Docker Desktop installed with WSL 2 integration enabled
- [ ] SSH keys copied to WSL
- [ ] Keychain installed and configured
- [ ] Git configured with SSH
- [ ] Repository cloned
- [ ] `docker-compose.override.yml` file exists (verify with `ls -la`)
- [ ] `.env` file created with DB password
- [ ] `docker compose up -d` successful
- [ ] Ports are exposed (verify with `docker compose ps`)
- [ ] Dependencies installed (composer & npm)
- [ ] Permissions fixed
- [ ] Migrations run
- [ ] Can access app at http://localhost:8000

### Daily Start
- [ ] Open WSL terminal
- [ ] `cd ~/your-repo`
- [ ] `git pull`
- [ ] Check/install updated dependencies
- [ ] Run new migrations (if any)
- [ ] `docker compose up -d`
- [ ] `docker compose exec app npm run dev` (if doing frontend)
- [ ] Start coding!

### Daily End
- [ ] Stop Vite (Ctrl+C)
- [ ] `git add .`
- [ ] `git commit -m "description"`
- [ ] `git push`
- [ ] `docker compose down` (optional)

---

## 🎯 Pro Tips

1. **Keep WSL updated:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Use Windows Terminal** (better than default Ubuntu terminal):
   - Install from Microsoft Store
   - Supports multiple tabs, better fonts, themes

3. **Backup your work frequently:**
   - Commit and push often
   - Don't wait until end of day

4. **Use meaningful commit messages:**
   - ✅ "Added user authentication with email verification"
   - ❌ "updates" or "fixes"

5. **Create `.wslconfig`** to limit WSL resource usage:
   
   In Windows, create `C:\Users\YourName\.wslconfig`:
   ```ini
   [wsl2]
   memory=4GB
   processors=2
   ```

6. **Access Windows files from WSL:**
   ```bash
   cd /mnt/c/Users/YourName/Documents
   ```

7. **Understand the Docker Compose file structure:**
   - `docker-compose.yml` = Base config (version controlled)
   - `docker-compose.override.yml` = Local overrides (NOT version controlled, enables port access)
   - Both files work together automatically when you run `docker compose up`

8. **Verify port mappings:**
   ```bash
   # Quick check to see what ports are exposed
   docker compose ps
   
   # You should see ports like:
   # 0.0.0.0:8000->80/tcp (web access)
   # 0.0.0.0:33061->3306/tcp (database)
   # 0.0.0.0:5173->5173/tcp (Vite HMR)
   ```

---

Happy coding! 🚀

If you have any issues, check the troubleshooting section or check container logs with `docker compose logs -f`.
