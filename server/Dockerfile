FROM php:8.3-cli

# System packages + PHP extensions Laravel/Postgres need. pdo_pgsql/pgsql
# talk to the Neon database; zip is required by Composer for package
# installs.
RUN apt-get update && apt-get install -y \
        libpq-dev \
        libzip-dev \
        unzip \
        git \
    && docker-php-ext-install pdo pdo_pgsql pgsql zip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy dependency manifests first so Docker can cache the composer layer
# across deploys that don't touch composer.json/lock.
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --optimize-autoloader --no-interaction

COPY . .
RUN composer dump-autoload --optimize \
    && mkdir -p storage/framework/{cache,sessions,views} storage/logs bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Render sets $PORT at runtime and routes external traffic to it — the
# service must bind to that exact port, not a hardcoded one.
#
# --no-reload is required for PHP_CLI_SERVER_WORKERS (set on Render, under
# Environment) to actually take effect — without it, `php artisan serve`
# silently falls back to a single worker (logs a WARN and ignores the env
# var), which under Render's periodic health-check pings plus real traffic
# causes requests to queue up or get dropped ("connection abort" / generic
# 500s), since only one request can be handled at a time.
EXPOSE 8080
# `storage:link` creates public/storage -> storage/app/public. It was never
# run anywhere for the deployed container (only exists locally because dev
# machines ran `php artisan storage:link` by hand), and public/storage is
# git-ignored on purpose (Laravel convention: generated at deploy time, not
# committed) — so on Render every request to a file URL under /storage/...
# 404'd unconditionally, for every uploaded document/license/receipt across
# the whole app. --force makes it safe to run on every boot.
CMD php artisan config:clear && php artisan storage:link --force && php artisan serve --host=0.0.0.0 --port=${PORT:-8080} --no-reload
