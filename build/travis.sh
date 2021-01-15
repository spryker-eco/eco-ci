#!/usr/bin/env bash

echo "Version of CI scripts:"
cd ecoci
git log | head -1
cd ..

phpenv config-add ./ecoci/build/travis.php.ini

echo "Moving module to subfolder..."
if [[ *$TRAVIS_EVENT_TYPE* = 'cron' ]]; then git checkout $(git tag | tail -n 1); fi
mkdir $MODULE_DIR
ls -1 | grep -v ^$MODULE_DIR | grep -v ^ecoci | xargs -I{} mv {} $MODULE_DIR

echo "Cloning $PRODUCT_NAME..."
git clone https://github.com/spryker-shop/$PRODUCT_NAME.git $SHOP_DIR
cd $SHOP_DIR

composer self-update && composer --version
composer install --optimize-autoloader --no-interaction
composer require "ruflin/elastica:6.*" "spryker/elastica:5.*" --update-with-dependencies --optimize-autoloader --no-interaction

nvm install 8

mkdir -p shared/data/common/jenkins
mkdir -p shared/data/common/jenkins/jobs
mkdir -p data/DE/cache/Yves/twig -m 0777
mkdir -p data/DE/cache/Zed/twig -m 0777
mkdir -p data/DE/logs
chmod -R 777 data/
chmod -R 660 config/Zed/dev_only_private.key
chmod -R 660 config/Zed/dev_only_public.key
chmod -R a+x config/Shared/ci/travis/

FILE_PATH_INSTALL_ELASTIC_SEARCH=./config/Shared/ci/travis/install_elasticsearch_6_8.sh

if [ -f $FILE_PATH_INSTALL_ELASTIC_SEARCH ]; then
  bash $FILE_PATH_INSTALL_ELASTIC_SEARCH
else
  mkdir /home/travis/elasticsearch
  wget -O - https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.8.4.tar.gz | tar xz --directory=/home/travis/elasticsearch --strip-components=1 > /dev/null
  /home/travis/elasticsearch/bin/elasticsearch --daemonize
fi

FILE_PATH_INSTALL_MAILCATCHER=./config/Shared/ci/travis/install_mailcatcher.sh

if [ -f $FILE_PATH_INSTALL_MAILCATCHER ]; then
  bash $FILE_PATH_INSTALL_MAILCATCHER
else
  gem install mailcatcher --no-document > /dev/null
  mailcatcher > /dev/null
fi

cd ..

chmod a+x ./ecoci/build/configure_postgres.sh
./ecoci/build/configure_postgres.sh

chmod a+x ./ecoci/build/travis.sh

./ecoci/build/validate.sh
