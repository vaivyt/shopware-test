FROM php:8.2-apache

# Install dependencies
RUN apt-get update \
    && apt-get install -y \
       git \
       libicu-dev \
       libpng-dev \
       libjpeg62-turbo-dev \
       libzip-dev \
       unzip \
       default-mysql-client \
    && docker-php-ext-configure gd --with-jpeg \
    && docker-php-ext-install -j$(nproc) intl gd zip pdo_mysql \
    && a2enmod rewrite \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && rm composer-setup.php

WORKDIR /var/www/html

# Ensure runtime directory exists (bind mount will populate at runtime)
RUN mkdir -p /var/www/html

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri 's#DocumentRoot /var/www/html#DocumentRoot ${APACHE_DOCUMENT_ROOT}#g' /etc/apache2/sites-available/000-default.conf \
    && sed -ri 's#<Directory /var/www/>#<Directory /var/www/html/>#g' /etc/apache2/apache2.conf

EXPOSE 8000

ENTRYPOINT ["entrypoint.sh"]
CMD ["apache2-foreground"]
