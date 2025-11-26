# Shopware Store with Docker

This repository provides a lightweight infrastructure to spin up a default Shopware store using Docker and Docker Compose. The setup mirrors the simple infrastructure of the original lens-configurator template, but installs a full Shopware instance (with demo data) instead of the sample API.

## What you get
- Shopware 6 installed via Composer inside the container
- Apache + PHP 8.2 with required extensions (intl, gd, zip, pdo_mysql)
- MySQL database with persistent volume
- Automatic first-boot installation with demo data and an admin user

## Quick start

1. Copy the environment file and adjust values if needed:

   ```bash
   cp .env.example .env
   ```

2. Start the stack (builds the PHP image, installs Shopware on first run, and loads demo data):

   ```bash
   docker compose up --build
   ```

3. Access the storefront and admin:

   - Storefront: http://localhost:8000
   - Admin: http://localhost:8000/admin

4. Default admin credentials (override in `.env`):

   - **User:** admin
   - **Password:** shopware

## Project layout

- `Dockerfile` — PHP + Apache image with Composer
- `docker-compose.yml` — services for Shopware app and MySQL
- `scripts/entrypoint.sh` — installs Shopware on first boot and keeps Apache running
- `shopware/` — bind-mounted project directory populated at runtime (kept out of version control)

## First-boot install details

On the first container start, the entrypoint will:
1. Download the Shopware production template via Composer if the `shopware/public/index.php` file is missing.
2. Wait for MySQL to become reachable.
3. Run `bin/console system:install` with demo data and the admin credentials from `.env`.
4. Clear the cache and start Apache.

Subsequent container restarts reuse the existing installation and database data.

## Useful commands

- Access the Shopware console:
  ```bash
  docker compose exec app bin/console system:info
  ```

- Reinstall the shop (destroys data):
  ```bash
  docker compose down -v
  rm -rf shopware/*
  docker compose up --build
  ```

## Notes
- The install includes Shopware demo data so you get default store items out of the box.
- The `APP_URL` in `.env` defaults to `http://localhost:8000`; change it if you bind to another host/port.
