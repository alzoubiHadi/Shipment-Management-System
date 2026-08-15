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
EXPOSE 8080
CMD php artisan config:clear && php artisan serve --host=0.0.0.0 --port=${PORT:-8080}
