# **************************************************************************** #
#                                                                              #
#                                                         ::::::::             #
#    Dockerfile                                         :+:    :+:             #
#                                                      +:+                     #
#    By: rpet <marvin@codam.nl>                       +#+                      #
#                                                    +#+                       #
#    Created: 2020/01/13 10:57:35 by rpet          #+#    #+#                  #
#    Updated: 2020/01/23 14:07:48 by rpet          ########   odam.nl          #
#                                                                              #
# **************************************************************************** #

FROM debian:buster

# install Nginx, MySQL, php, phMmyAdmin, SSL, WordPress
RUN apt-get update && apt-get install -y \
	nginx \
	mariadb-server \
	php7.3 php7.3-fpm php7.3-mysql php7.3-mbstring php7.3-gd php7.3-curl php7.3-dom php7.3-imagick php7.3-zip \
	wget \
	libnss3-tools \
	sudo \
	sendmail

# configuration Nginx
COPY srcs/nginx.conf /tmp/
RUN cp /tmp/nginx.conf /etc/nginx/sites-available/default

# configuration SSL
RUN wget -O mkcert https://github.com/FiloSottile/mkcert/releases/download/v1.4.1/mkcert-v1.4.1-linux-amd64 && \
	chmod +x /mkcert && ./mkcert -install && ./mkcert localhost && mv /localhost.pem /localhost-key.pem /tmp

# configuration MySQL
RUN service mysql start && \
	mysql -e "CREATE USER 'rpet'@'localhost' IDENTIFIED BY 'codam'" && \
	mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'rpet'@'localhost'" && \
	mysql -e "FLUSH PRIVILEGES"

# configuration phpMyAdmin
RUN wget https://files.phpmyadmin.net/phpMyAdmin/5.0.1/phpMyAdmin-5.0.1-all-languages.tar.gz && \
	tar -zxvf phpMyAdmin-5.0.1-all-languages.tar.gz && \
	mv phpMyAdmin-5.0.1-all-languages /var/www/html/phpmyadmin && \
	rm phpMyAdmin-5.0.1-all-languages.tar.gz
COPY srcs/config.inc.php /var/www/html/phpmyadmin
COPY srcs/php.ini /etc/php/7.3/fpm/
RUN mkdir /var/www/html/phpmyadmin/tmp && \
	chmod 777 /var/www/html/phpmyadmin/tmp && \
	service mysql start && mysql -e "CREATE DATABASE phpmyadmin" && \
	mysql phpmyadmin < /var/www/html/phpmyadmin/sql/create_tables.sql

# configuration WordPress
WORKDIR /var/www/html
RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
	chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp && \
	chown www-data /var/www && chown www-data /var/www/html && \
	sudo -u www-data wp core download && \
	service mysql start && \
	sudo -u www-data wp config create --dbname=wordpress --dbuser=rpet --dbpass=codam && \
	sudo -u www-data wp db create && \
	sudo -u www-data wp core install --url=localhost --title=WordPress --admin_user=rpet --admin_password=codam --admin_email=rpet@student.codam.nl

# automatic quit prevention && port expose
EXPOSE 80 443 25
CMD service nginx start && \
	service mysql start && \
	service php7.3-fpm start && \
	echo "$(hostname -i)	$(hostname) $(hostname).localhost" >> /etc/hosts && \
	service sendmail start && \
	tail -f /dev/null
