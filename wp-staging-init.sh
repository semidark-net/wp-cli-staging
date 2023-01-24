#!/bin/bash

# Load function library 
source $(dirname -- "$0";)/wp-staging-lib.sh

### Configuration variables
# Load .env file
source $(dirname -- "$0";)/.env

echo "=== Production Environment ==="

# Install wp-cli find command if needed
if [[ $(wp package list |grep "wp-cli/find-command" |wc -l) -lt 1 ]]; then
    echo "INFO: Install wp-cli find-command"
    wp package install wp-cli/find-command
fi

# DIR_PRODUCTION - autodetect none staging wordpress installation
: ${DIR_PRODUCTION:=$(wp find ${HOME} |egrep -v "staging|stage|dev|development" |awk -F '/wp-includes/version.php' '{print $1}' |tail -n1)}
echo "Directory: $DIR_PRODUCTION"

# DOM_PRODUCTION - autodetect production domain
: ${DOM_PRODUCTION:=$(wp option get siteurl --path=${DIR_PRODUCTION} |awk -F'^http[s]?://' '{print $2}')}
echo "Domain: $DOM_PRODUCTION"

echo 
echo "=== Staging Environment ==="

# DIR_STAGING - generate staging directory
: ${DIR_STAGING:=${HOME}/staging.${DOM_PRODUCTION}}
echo "Directory: $DIR_STAGING"

# DOM_STAGING - autogenerate staging domain
: ${DOM_STAGING:=staging.${DOM_PRODUCTION}}
echo "Domain: $DOM_STAGING"

# DB_STAGING_NAME - SET PER .env file
: ${DB_STAGING_NAME:="!!!change_pass!!!"}
echo "Database Name: $DB_STAGING_NAME"

# DB_STAGING_USER - SET PER .env file
: ${DB_STAGING_USER:="!!!change_user!!!"}
echo "Database User: $DB_STAGING_USER"

# DB_STAGING_PASS - SET PER .env file
: ${DB_STAGING_PASS:="!!!change_pass!!!"}
echo "Database Password: $DB_STAGING_PASS"

echo
echo "Database contents and files in staging will be deleted"
yes_or_no "Continue...?" 
if [[ $? -ne 0 ]]; then
    exit 1
fi

### Syncronize all files into the staging area
echo "INFO: Syncronize all files from production into the staging area"
rsync -ah ${DIR_PRODUCTION}/ ${DIR_STAGING} --delete

### change db configuration in staging environment
wp config set DB_NAME ${DB_STAGING_NAME} --path=${DIR_STAGING}
wp config set DB_USER ${DB_STAGING_USER} --path=${DIR_STAGING}
wp config set DB_PASSWORD ${DB_STAGING_PASS} --path=${DIR_STAGING}
wp config set WP_TEMP_DIR ${DIR_STAGING}/wp-content/uploads --path=${DIR_STAGING}

### Enable Staging / Development Features in WordPress
# https://wordpress.org/support/article/debugging-in-wordpress/
wp config set WP_DEBUG true --raw --path=${DIR_STAGING}
wp config set WP_DEBUG_LOG true --raw --path=${DIR_STAGING}
wp config set WP_DEBUG_DISPLAY false --raw --path=${DIR_STAGING}
wp config set WP_ENVIRONMENT_TYPE development  --path=${DIR_STAGING}

### Import Database from production to staging
echo "INFO: Clone Database from production to staging."
wp db export --path=${DIR_PRODUCTION} - | wp db import --path=${DIR_STAGING} -

### Replace Domain in Database
echo "INFO: replace all domain strings in database if staging"
wp search-replace --report-changed-only "://${DOM_PRODUCTION}" "://${DOM_STAGING}" --path=${DIR_STAGING}

### Clean all caches

# TODO: Add more Caching Plugin support

echo "INFO: Flush wordpress caches"
wp cache flush --path=${DIR_STAGING}

### WP-Rocket support
# https://github.com/wp-media/wp-rocket-cli
if [[ $(wp plugin is-active wp-rocket --path=${DIR_STAGING}) -eq 0 ]]; then

    if [[ $(wp package list|grep "wp-rocket-cli" |wc -l) -lt 1 ]]; then
        echo "INFO: Install wp-cli wp-rocket-cli"
        wp package install wp-media/wp-rocket-cli --path=${DIR_STAGING}
    fi

    echo "INFO: Clean all wp-rocket and wp cache files"
    wp rocket clean --confirm --path=${DIR_STAGING}
fi

echo "INFO:Disable staging for search engine indexing via robots.txt"
cat > ${DIR_STAGING}/robots.txt<< EOF
User-agent: *
Disallow: /
EOF

echo "INFO: Set x-robots-tag to noindex,nofollow for staging to keep search engines out"
cat >> ${DIR_STAGING}/.htaccess<< EOF
<IfModule mod_headers.c>
  Header set X-Robots-Tag "noindex, nofollow"
</IfModule>
EOF

echo "INFO: Set Wordpress instalation as non-public."
wp option set blog_public 0 --path=${DIR_STAGING}

