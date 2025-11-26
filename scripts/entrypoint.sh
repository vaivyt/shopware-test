#!/usr/bin/env bash
set -euo pipefail

SHOPWARE_DIR="/var/www/html"
INSTALL_MARKER="$SHOPWARE_DIR/.installed"

# Raise PHP memory limit (configurable via PHP_MEMORY_LIMIT env)
echo "memory_limit=${PHP_MEMORY_LIMIT:-512M}" > /usr/local/etc/php/conf.d/memory-limit.ini

if [ ! -f "$SHOPWARE_DIR/public/index.php" ]; then
  echo "[entrypoint] Installing Shopware source..."
  shopt -s dotglob
  rm -rf "${SHOPWARE_DIR:?}"/*
  shopt -u dotglob
  composer create-project shopware/production "$SHOPWARE_DIR" --no-interaction
  touch "$SHOPWARE_DIR/.gitkeep"
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

# Persist environment so the runtime uses the container DB host/port
APP_URL_VALUE="${APP_URL:-http://localhost:8500}"
DATABASE_URL_VALUE="mysql://${DATABASE_USER:-shopware}:${DATABASE_PASSWORD:-shopware}@${HOST}:${PORT}/${DATABASE_NAME:-shopware}"

# Write both .env.local (takes precedence) and .env to keep the runtime and CLI
# aligned with the containerised database host instead of defaulting to localhost.
cat > .env.local <<EOF
APP_ENV=${APP_ENV:-prod}
APP_DEBUG=${APP_DEBUG:-0}
APP_URL=${APP_URL_VALUE}
DATABASE_URL=${DATABASE_URL_VALUE}
EOF

if [ -f .env ]; then
  sed -i \
    -e "s#^APP_URL=.*#APP_URL=${APP_URL_VALUE}#" \
    -e "s#^DATABASE_URL=.*#DATABASE_URL=${DATABASE_URL_VALUE}#" \
    .env
else
  cat > .env <<EOF
APP_ENV=${APP_ENV:-prod}
APP_DEBUG=${APP_DEBUG:-0}
APP_URL=${APP_URL_VALUE}
DATABASE_URL=${DATABASE_URL_VALUE}
EOF
fi

# If not installed, run installer with demo data
if [ ! -f "$INSTALL_MARKER" ]; then
  echo "[entrypoint] Running Shopware installer..."
  export APP_URL="$APP_URL_VALUE"
  export DATABASE_URL="$DATABASE_URL_VALUE"
  bin/console system:install \
    --create-database \
    --force \
    --drop-database \
    --basic-setup \
    --shop-name="${SHOP_NAME:-Demo Store}" \
    --shop-email="${SHOP_EMAIL:-example@example.com}" \
    --shop-locale="${SHOP_LOCALE:-en-GB}" \
    --shop-currency="${SHOP_CURRENCY:-EUR}" \
    --skip-first-run-wizard

  # Ensure an admin account exists (ignored if already created)
  set +e
  bin/console user:create "${ADMIN_USERNAME:-admin}" --admin \
    --email="${ADMIN_EMAIL:-example@example.com}" \
    --password="${ADMIN_PASSWORD:-shopware}" \
    --firstName="${ADMIN_FIRSTNAME:-Demo}" \
    --lastName="${ADMIN_LASTNAME:-Admin}" \
    --locale="${ADMIN_LOCALE:-en-GB}" \
    --no-interaction
  set -e

  # Mark installation to skip reinstall on next boot
  touch "$INSTALL_MARKER"
fi

bin/console cache:clear

exec "$@"
