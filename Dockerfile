# Inherit from Heroku's stack
FROM heroku/heroku:18-build

# Internally, we arbitrarily use port 3000
ENV PORT 3000

# Which versions?
ENV PHP_VERSION 7.3.7
ENV HTTPD_VERSION 2.4.39
ENV NGINX_VERSION 1.16.0

# Create some needed directories
RUN mkdir -p /app/.heroku/php /app/.profile.d
WORKDIR /app/user

# so we can run PHP in here
ENV PATH /app/.heroku/php/bin:/app/.heroku/php/sbin:$PATH

# Install Apache
RUN curl --silent --location https://lang-php.s3.amazonaws.com/dist-heroku-18-develop/apache-$HTTPD_VERSION.tar.gz | tar xz -C /app/.heroku/php
# Config
RUN curl --silent --location https://raw.githubusercontent.com/heroku/heroku-buildpack-php/ded7e8a02e472387fb9cdb98e84b7f82d8eb3b91/conf/apache2/httpd.conf.default > /app/.heroku/php/etc/apache2/httpd.conf
# FPM socket permissions workaround when run as root
RUN echo "\n\
Group root\n\
" >> /app/.heroku/php/etc/apache2/httpd.conf

# Install Nginx
RUN curl --silent --location https://lang-php.s3.amazonaws.com/dist-heroku-18-develop/nginx-$NGINX_VERSION.tar.gz | tar xz -C /app/.heroku/php
# Config
RUN curl --silent --location https://raw.githubusercontent.com/heroku/heroku-buildpack-php/ded7e8a02e472387fb9cdb98e84b7f82d8eb3b91/conf/nginx/nginx.conf.default > /app/.heroku/php/etc/nginx/nginx.conf
# FPM socket permissions workaround when run as root
RUN echo "\n\
user nobody root;\n\
" >> /app/.heroku/php/etc/nginx/nginx.conf

# Install PHP
RUN curl --silent --location https://lang-php.s3.amazonaws.com/dist-heroku-18-develop/php-$PHP_VERSION.tar.gz | tar xz -C /app/.heroku/php
# Config
RUN mkdir -p /app/.heroku/php/etc/php/conf.d
RUN curl --silent --location https://raw.githubusercontent.com/heroku/heroku-buildpack-php/ded7e8a02e472387fb9cdb98e84b7f82d8eb3b91/conf/php/php.ini > /app/.heroku/php/etc/php/php.ini
# Enable all optional exts
RUN echo "\n\
user_ini.cache_ttl = 30 \n\
zend_extension = opcache.so \n\
opcache.enable_cli = 1 \n\
opcache.validate_timestamps = 1 \n\
opcache.revalidate_freq = 0 \n\
opcache.fast_shutdown = 0 \n\
extension=bcmath.so \n\
extension=calendar.so \n\
extension=exif.so \n\
extension=ftp.so \n\
extension=gd.so \n\
extension=gettext.so \n\
extension=intl.so \n\
extension=mbstring.so \n\
extension=pcntl.so \n\
extension=shmop.so \n\
extension=soap.so \n\
extension=sqlite3.so \n\
extension=pdo_sqlite.so \n\
extension=xmlrpc.so \n\
extension=xsl.so\n\
" >> /app/.heroku/php/etc/php/php.ini

# Install Composer
RUN curl --silent --location "https://lang-php.s3.amazonaws.com/dist-heroku-18-develop/composer-1.8.6.tar.gz" | tar xz -C /app/.heroku/php

# copy dep files first so Docker caches the install step if they don't change
ONBUILD COPY composer.lock /app/user/
ONBUILD COPY composer.json /app/user/
# run install but without scripts as we don't have the app source yet
ONBUILD RUN composer install --no-scripts
# require the buildpack for execution
ONBUILD RUN composer show --installed heroku/heroku-buildpack-php || { echo 'Your composer.json must have "heroku/heroku-buildpack-php" as a "require-dev" dependency.'; exit 1; }
# rest of app
ONBUILD ADD . /app/user/
# run install hooks
ONBUILD RUN cat composer.json | python -c 'import sys,json; sys.exit("post-install-cmd" not in json.load(sys.stdin).get("scripts", {}));' && composer run-script post-install-cmd || true

# TODO: run "composer compile", like Heroku?

# ENTRYPOINT ["/usr/bin/init.sh"]
