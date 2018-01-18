#!/bin/sh

#set -e
setup_mariadb_data_dir(){
    test ! -d "$MARIADB_DATA_DIR" && echo "INFO: $MARIADB_DATA_DIR not found. creating ..." && mkdir -p "$MARIADB_DATA_DIR"

    # check if 'mysql' database exists
    if [ ! -d "$MARIADB_DATA_DIR/mysql" ]; then
	echo "INFO: 'mysql' database doesn't exist under $MARIADB_DATA_DIR. So we think $MARIADB_DATA_DIR is empty."
	echo "Copying all data files from the original folder /var/lib/mysql to $MARIADB_DATA_DIR ..."
	cp -R /var/lib/mysql/. $MARIADB_DATA_DIR
    else
	echo "INFO: 'mysql' database already exists under $MARIADB_DATA_DIR."
    fi

    rm -rf /var/lib/mysql
    ln -s $MARIADB_DATA_DIR /var/lib/mysql
    chown -R mysql:mysql $MARIADB_DATA_DIR
    test ! -d /run/mysqld && echo "INFO: /run/mysqld not found. creating ..." && mkdir -p /run/mysqld
    chown -R mysql:mysql /run/mysqld
}

start_mariadb(){
    # /etc/init.d/mariadb setup
    /usr/bin/mysql_install_db --user=mysql --datadir=${MARIADB_DATA_DIR}
    rc-service mariadb start 

    rm -f /tmp/mysql.sock
    ln -s /var/run/mysqld/mysqld.sock /tmp/mysql.sock

    # create default database 'azurelocaldb'
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS azurelocaldb; FLUSH PRIVILEGES;"
}

#unzip phpmyadmin
setup_phpmyadmin(){
    test ! -d "$PHPMYADMIN_HOME" && echo "INFO: $PHPMYADMIN_HOME not found. creating..." && mkdir -p "$PHPMYADMIN_HOME"
    cd $PHPMYADMIN_SOURCE
    tar -xf phpmyadmin.tar.gz -C $PHPMYADMIN_HOME --strip-components=1
    cp -R phpmyadmin-config.inc.php $PHPMYADMIN_HOME/config.inc.php
    rm -rf $PHPMYADMIN_SOURCE
    chown -R www-data:www-data $PHPMYADMIN_HOME
}

load_phpmyadmin(){
        if ! grep -q "^Include conf/httpd-phpmyadmin.conf" $HTTPD_CONF_FILE; then
                echo 'Include conf/httpd-phpmyadmin.conf' >> $HTTPD_CONF_FILE
        fi
}

setup_wordpress(){
	test ! -d "$WORDPRESS_HOME" && echo "INFO: $WORDPRESS_HOME not found. creating ..." && mkdir -p "$WORDPRESS_HOME"

	cd $WORDPRESS_SOURCE
	tar -xf wp.tar.gz -C $WORDPRESS_HOME/ --strip-components=1
	
	chown -R www-data:www-data $WORDPRESS_HOME
    
}

update_wordpress_config(){	
    
	DATABASE_HOST=${DATABASE_HOST:-localhost}
	DATABASE_NAME=${DATABASE_NAME:-azurelocaldb}
	# if DATABASE_USERNAME equal phpmyadmin, it means it's nothing at beginning.
	if [ "${DATABASE_USERNAME}" == "phpmyadmin" ]; then
	    DATABASE_USERNAME='wordpress'
	fi	
	DATABASE_PASSWORD=${DATABASE_PASSWORD:-MS173m_QN}   
}

load_wordpress(){
        if ! grep -q "^Include conf/httpd-wordpress.conf" $HTTPD_CONF_FILE; then
                echo 'Include conf/httpd-wordpress.conf' >> $HTTPD_CONF_FILE
        fi
}

test ! -d "$APP_HOME" && echo "INFO: $APP_HOME not found. creating..." && mkdir -p "$APP_HOME"
if [ ! $WEBSITES_ENABLE_APP_SERVICE_STORAGE ]; then 
    echo "INFO: NOT in Azure, chown for "$APP_HOME 
    chown -R www-data:www-data $APP_HOME
fi

test ! -d "$HTTPD_LOG_DIR" && echo "INFO: $HTTPD_LOG_DIR not found. creating..." && mkdir -p "$HTTPD_LOG_DIR"
if [ ! $WEBSITES_ENABLE_APP_SERVICE_STORAGE ]; then 
    echo "INFO: NOT in Azure, chown for "$HTTPD_LOG_DIR 
    chown -R www-data:www-data $HTTPD_LOG_DIR
fi

echo "Setup openrc ..." && openrc && touch /run/openrc/softlevel

DATABASE_TYPE=$(echo ${DATABASE_TYPE}|tr '[A-Z]' '[a-z]')

if [ "${DATABASE_TYPE}" == "local" ]; then  
    echo 'mysql.default_socket = /run/mysqld/mysqld.sock' >> $PHP_CONF_FILE     
    echo 'mysqli.default_socket = /run/mysqld/mysqld.sock' >> $PHP_CONF_FILE     
    #setup MariaDB
    echo "INFO: loading local MariaDB and phpMyAdmin ..."
    echo "Setting up MariaDB data dir ..."
    setup_mariadb_data_dir
    echo "Setting up MariaDB log dir ..."
    test ! -d "$MARIADB_LOG_DIR" && echo "INFO: $MARIADB_LOG_DIR not found. creating ..." && mkdir -p "$MARIADB_LOG_DIR"
    chown -R mysql:mysql $MARIADB_LOG_DIR
    echo "Starting local MariaDB ..."
    start_mariadb

    echo "Granting user for phpMyAdmin ..."
    # Set default value of username/password if they are't exist/null.
    DATABASE_USERNAME=${DATABASE_USERNAME:-phpmyadmin}
    DATABASE_PASSWORD=${DATABASE_PASSWORD:-MS173m_QN}
	echo "INFO: ++++++++++++++++++++++++++++++++++++++++++++++++++:"
    echo "phpmyadmin username:" $DATABASE_USERNAME
    echo "phpmyadmin password:" $DATABASE_PASSWORD
    echo "INFO: ++++++++++++++++++++++++++++++++++++++++++++++++++:"
    mysql -u root -e "GRANT ALL ON *.* TO \`$DATABASE_USERNAME\`@'localhost' IDENTIFIED BY '$DATABASE_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"
    echo "Installing phpMyAdmin ..."
    setup_phpmyadmin
    echo "Loading phpMyAdmin conf ..."
    if ! grep -q "^Include conf/httpd-phpmyadmin.conf" $HTTPD_CONF_FILE; then
        echo 'Include conf/httpd-phpmyadmin.conf' >> $HTTPD_CONF_FILE
    fi
fi

# That wp-config.php doesn't exist means WordPress is not installed/configured yet.
if [ ! -e "$WORDPRESS_HOME/wp-config.php" ]; then
	echo "INFO: $WORDPRESS_HOME/wp-config.php not found."
	echo "Installing WordPress for the first time ..." 
	setup_wordpress	

	if [ "${DATABASE_TYPE}" == "local" ]; then
        echo "INFO: local MariaDB is used."
        update_wordpress_config
        echo "INFO: ++++++++++++++++++++++++++++++++++++++++++++++++++:"
        echo "INFO: WORDPRESS_ENVS:"
        echo "INFO: DATABASE_HOST:" $DATABASE_HOST
        echo "INFO: WORDPRESS_DATABASE_NAME:" $DATABASE_NAME
        echo "INFO: WORDPRESS_DATABASE_USERNAME:" $DATABASE_USERNAME
        echo "INFO: WORDPRESS_DATABASE_PASSWORD:" $DATABASE_PASSWORD	        
        echo "INFO: ++++++++++++++++++++++++++++++++++++++++++++++++++:"
        echo "Creating database for WordPress if not exists ..."
	    mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`$DATABASE_NAME\` CHARACTER SET utf8 COLLATE utf8_general_ci;"
	    echo "Granting user for WordPress ..."
	    mysql -u root -e "GRANT ALL ON \`$DATABASE_NAME\`.* TO \`$DATABASE_USERNAME\`@\`$DATABASE_HOST\` IDENTIFIED BY '$DATABASE_PASSWORD'; FLUSH PRIVILEGES;"
	
        cd $WORDPRESS_HOME 
		cp $WORDPRESS_SOURCE/wp-config.php . && chmod 777 wp-config.php && chown -R www-data:www-data wp-config.php
        sed -i "s/getenv('DATABASE_NAME')/${DATABASE_NAME}/g" wp-config.php
        sed -i "s/getenv('DATABASE_USERNAME')/${DATABASE_USERNAME}/g" wp-config.php
        sed -i "s/getenv('DATABASE_PASSWORD')/${DATABASE_PASSWORD}/g" wp-config.php
        sed -i "s/getenv('DATABASE_HOST')/${DATABASE_HOST}/g" wp-config.php

        echo "Starting local Redis ..."
        redis-server --daemonize yes
	fi
else
	echo "INFO: $WORDPRESS_HOME/wp-config.php already exists."
	echo "INFO: You can modify it manually as need."
fi	

echo "Loading WordPress conf ..."
load_wordpress
cd $WORDPRESS_HOME 
rm -rf $WORDPRESS_SOURCE

echo "Starting SSH ..."
rc-service sshd start

echo "Starting Apache httpd -D FOREGROUND ..."
apachectl start -D FOREGROUND
