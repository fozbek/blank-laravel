FROM unit:1.34.1-php8.3 AS build

RUN apt update && apt install -y \
    curl unzip git libicu-dev libzip-dev libpng-dev libjpeg-dev libfreetype6-dev libssl-dev libpq-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) pcntl opcache pdo pdo_mysql pgsql pdo_pgsql intl zip gd exif ftp bcmath \
    && pecl install redis \
    && docker-php-ext-enable redis

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html

COPY composer.json composer.lock ./

RUN composer install --prefer-dist --no-scripts --no-autoloader --no-interaction

COPY . .

RUN composer dump-autoload --optimize && composer run-script post-autoload-dump || true

RUN mkdir -p storage/logs bootstrap/cache \
    && touch storage/logs/laravel.log \
    && chown -R unit:unit storage bootstrap/cache \
    && chmod -R ug+rwX storage bootstrap/cache

FROM unit:1.34.1-php8.3

WORKDIR /var/www/html

COPY --from=build /var/www/html /var/www/html

RUN chown -R unit:unit storage bootstrap/cache && chmod -R ug+rwX storage bootstrap/cache

RUN echo "opcache.enable=1" > /usr/local/etc/php/conf.d/custom.ini \
    && echo "opcache.jit=tracing" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "opcache.jit_buffer_size=256M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "memory_limit=512M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "upload_max_filesize=64M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "post_max_size=64M" >> /usr/local/etc/php/conf.d/custom.ini

COPY unit.json /docker-entrypoint.d/unit.json

EXPOSE 8000

CMD ["unitd", "--no-daemon"]
