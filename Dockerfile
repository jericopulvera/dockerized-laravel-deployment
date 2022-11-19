# syntax = docker/dockerfile:experimental

# Default to PHP 8.1, but we attempt to match
# the PHP version from the user (wherever `flyctl launch` is run)
# Valid version values are PHP 7.4+
ARG PHP_VERSION=8.0
FROM serversideup/php:${PHP_VERSION}-fpm-nginx-v2.0.2 as base

# PHP_VERSION needs to be repeated here
# See https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
ARG PHP_VERSION

# See https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
RUN apt-get update && apt-get install -y \
    git curl zip unzip rsync ca-certificates vim htop cron \
    php${PHP_VERSION}-mysql php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-swoole php${PHP_VERSION}-xml php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-intl php${PHP_VERSION}-memcache php${PHP_VERSION}-memcached \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html
# copy application code, skipping files based on .dockerignore
COPY . /var/www/html

RUN composer install --optimize-autoloader --no-dev \
    && mkdir -p storage/logs \
    && php artisan optimize:clear \
    && chown -R webuser:webgroup /var/www/html \
    && sed -i 's/protected \$proxies/protected \$proxies = "*"/g' app/Http/Middleware/TrustProxies.php \
    && echo "MAILTO=\"\"\n* * * * * webuser /usr/bin/php /var/www/html/artisan schedule:run" > /etc/cron.d/laravel \
    && rm -rf /etc/cont-init.d/* \
    && cp .fly/entrypoint.sh /entrypoint \
    && chmod +x /entrypoint

RUN rm /etc/nginx/sites-available/ssl-off \
    && cp .fly/nginx-default-2.0.2 /etc/nginx/sites-available/ssl-off

EXPOSE 8080

CMD ["su", "webuser", "-c", "php artisan queue:work --tries=3"]
