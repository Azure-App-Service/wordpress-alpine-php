# This repo is not being monitored and managed. The images available in this repo are outdated and no longer maintained and if youa are looking for WordPress on Azure App Service then we recommend to refer this [Repository](https://github.com/Azure/wordpress-linux-appservice) 

# Wordpress-alpine-php Docker Image 
This is a WordPress Docker image which can run on both [Azure Web App on Linux](https://docs.microsoft.com/en-us/azure/app-service-web/app-service-linux-intro) and your Docker engines's host.

## Components
This docker image currently contains the following components:

1. WordPress (4.9.1)   
2. Alpine
3. PHP 
4. Phpmyadmin ( if using Local Database )

## How to configure to use Azure Database for MySQL with web app 
1. Create a Web App for Containers 
2. Update App Setting ```WEBSITES_ENABLE_APP_SERVICE_STORAGE``` = true 
3. Browse your site 
4. Complete WordPress install and Enter the Credentials for Azure database for MySQL 


## How to configure to use Local Database with web app 
1. Create a Web App for Containers 
2. Update App Setting ```WEBSITES_ENABLE_APP_SERVICE_STORAGE``` = true 
3. Add new App Settings 

Name | Default Value
---- | -------------
DATABASE_TYPE | local
DATABASE_USERNAME | wordpress
DATABASE_PASSWORD | some-string
**Note: We create a database "azurelocaldb" when using local mysql . Hence use this name when setting up the app **

4. Browse your site 
5. Complete WordPress install

**Note: Do not use the app setting DATABASE_TYPE=local if using Azure database for MySQL **


## Limitations
- Some unexpected issues may happen after you scale out your site to multiple instances, if you deploy a WordPress site on Azure with this docker image and use the MariaDB built in this docker image as the database.
- The phpMyAdmin built in this docker image is available only when you use the MariaDB built in this docker image as the database.
- Must include  App Setting ```WEBSITES_ENABLE_APP_SERVICE_STORAGE``` = true  since we need files to be persisted. Do not use local storage for WordPress. You can use local storage for transient data or cached data say /tmp folder.
