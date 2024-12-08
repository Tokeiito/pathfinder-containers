FROM php:7.4-fpm-alpine as build

# Install dependencies
RUN apk add --no-cache \
    libpng-dev \
    zeromq-dev \
    git \
    bash \
    $PHPIZE_DEPS && \
    docker-php-ext-install \
    gd \
    pdo_mysql && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

COPY pathfinder /app
WORKDIR /app

RUN composer self-update 2.1.8
RUN composer install

FROM trafex/alpine-nginx-php7:1.10.0

USER root

RUN apk update && apk add --no-cache busybox-suid sudo php7-redis php7-pdo php7-pdo_mysql \
    php7-fileinfo php7-event shadow gettext bash apache2-utils logrotate ca-certificates

# fix expired DST Cert
RUN sed -i '/^mozilla\/DST_Root_CA_X3.crt$/ s/^/!/' /etc/ca-certificates.conf \
    && update-ca-certificates 

# symlink nginx logs to stdout/stderr for supervisord
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log

# we need to create sites_enabled directory in order for entrypoint.sh being able to copy file after envsubst
RUN mkdir -p /etc/nginx/sites_enabled/

WORKDIR /var/www/html
COPY  --chown=nobody --from=build /app  pathfinder

RUN chmod 0766 pathfinder/logs pathfinder/tmp/ 
RUN rm index.php && touch /etc/nginx/.setup_pass 
# RUN chmod +x /entrypoint.sh

WORKDIR /var/www/html
EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
