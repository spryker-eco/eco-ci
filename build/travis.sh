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

pwd
echo "shop dir is $SHOP_DIR"
echo "Cloning $PRODUCT_NAME..."
git clone https://github.com/spryker-shop/$PRODUCT_NAME.git $SHOP_DIR
cd $SHOP_DIR
pwd
echo "shop dir is $SHOP_DIR"

composer global require hirak/prestissimo
composer self-update && composer --version
composer install --optimize-autoloader --no-interaction

nvm install 12

mkdir -p shared/data/common/jenkins
mkdir -p shared/data/common/jenkins/jobs
mkdir -p data/DE/cache/Yves/twig -m 0777
mkdir -p data/DE/cache/Zed/twig -m 0777
mkdir -p data/DE/logs
chmod -R 777 data/
chmod -R 660 config/Zed/dev_only_private.key
chmod -R 660 config/Zed/dev_only_public.key
chmod -R a+x config/Shared/ci/travis/
./config/Shared/ci/travis/install_elasticsearch_6_8.sh
./config/Shared/ci/travis/install_mailcatcher.sh
./config/Shared/ci/travis/configure_postgres.sh

cat config/Shared/ci/travis/postgresql_ci.config >> config/Shared/config_local.php
cp config/Shared/ci/travis/params_test_env.sh deploy/setup/params_test_env.sh
cd ..

chmod a+x ./ecoci/build/travis.sh

./ecoci/build/validate.sh
