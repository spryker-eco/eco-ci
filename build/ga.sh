#!/usr/bin/env bash

set -e

composerPreference=$1

echo "Version of CI scripts:"
cd ecoci
git log | head -1
cd ..

echo "Moving module to subfolder..."

mkdir $MODULE_DIR
ls -1 | grep -v ^$MODULE_DIR | grep -v ^ecoci | xargs -I{} mv {} $MODULE_DIR

echo "Cloning $PRODUCT_NAME..."

git clone -b feature/dev-te-7947-add-github-action-and-remove-travis-from-eco https://github.com/spryker-shop/$PRODUCT_NAME.git $SHOP_DIR
cd $SHOP_DIR

mkdir -p shared/data/common/jenkins
mkdir -p shared/data/common/jenkins/jobs
mkdir -p data/DE/cache/Yves/twig -m 0777
mkdir -p data/DE/cache/Zed/twig -m 0777
mkdir -p data/DE/logs
chmod -R 777 data/
chmod -R 660 config/Zed/dev_only_private.key
chmod -R 660 config/Zed/dev_only_public.key

cd ..

./ecoci/build/install_mailcatcher.sh
./ecoci/build/validate.sh $composerPreference
