#!/bin/bash

# Load function library 
source $(dirname -- "$0";)/wp-staging-lib.sh

### Configuration variables
# Load .env file
source $(dirname -- "$0";)/.env

### Configuration variables
# Installation Directories (no trailing slashes please)

: ${DIR_STAGING:=$(wp find ${HOME} |egrep "staging|stage|dev|development" |awk -F '/wp-includes/version.php' '{print $1}' |tail -n1)}
echo "Directory: $DIR_STAGING"

: ${DOM_STAGING:=$(wp option get siteurl --path=${DIR_STAGING} |awk -F'^http[s]?://' '{print $2}')}
echo "Domain: $DOM_STAGING"

# Clean database Tables
wp db reset --path=${DIR_STAGING}

# Remove all files from staging
yes_or_no "Remove all Files in ${DIR_STAGING}?" && rm -r ${DIR_STAGING}/* && rm -rf ${DIR_STAGING}/.* 2>/dev/null

# echo 
echo "INFO: Write new index.html file"
echo "${DOM_STAGING} is not availible" > ${DIR_STAGING}/index.html

