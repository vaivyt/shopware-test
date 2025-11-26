#!/usr/bin/env bash
set -euo pipefail

SHOPWARE_DIR="/var/www/html"
INSTALL_MARKER="$SHOPWARE_DIR/.installed"

if [ ! -f "$SHOPWARE_DIR/public/index.php" ]; then
  echo "[entrypoint] Installing Shopware source..."
  rm -rf "$SHOPWARE_DIR"/*
  composer create-project shopware/production "$SHOPWARE_DIR" --no-interaction
fi

# Ensure permissions for web user
chown -R www-data:www-data "$SHOPWARE_DIR"

# Wait for database
HOST=${DATABASE_HOST:-db}
PORT=${DATABASE_PORT:-3306}
until mysqladmin ping -h"$HOST" -P"$PORT" --silent; do
  echo "[entrypoint] Waiting for database at $HOST:$PORT..."
  sleep 2
done

cd "$SHOPWARE_DIR"

# If not installed, run installer with demo data
if [ ! -f "$INSTALL_MARKER" ]; then
  echo "[entrypoint] Running Shopware installer..."
  bin/console system:install \
    --create-database \
    --force \
    --drop-database \
    --basic-setup \
    --shop-name="${SHOP_NAME:-Demo Store}" \
    --shop-locale="${SHOP_LOCALE:-en-GB}" \
    --shop-currency="${SHOP_CURRENCY:-EUR}" \
    --app-url="${APP_URL:-http://localhost:8500}" \
    --admin-email="${ADMIN_EMAIL:-admin@example.com}" \
    --admin-username="${ADMIN_USERNAME:-admin}" \
    --admin-password="${ADMIN_PASSWORD:-shopware}" \
    --admin-first-name="${ADMIN_FIRSTNAME:-Demo}" \
    --admin-last-name="${ADMIN_LASTNAME:-Admin}" \
    --demo-data

  # Mark installation to skip reinstall on next boot
  touch "$INSTALL_MARKER"
fi

bin/console cache:clear

exec "$@"
