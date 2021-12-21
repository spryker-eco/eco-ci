#!/usr/bin/env bash

RED='\033[1;31m'
GREEN='\033[1;32m'
buildResult=1
buildMessage=""
result=0
composerPreference=$1

capitalizeCommand="echo ucfirst('$MODULE_NAME');"
moduleNameCapitalized=$(php -r "$capitalizeCommand")

if [ "$GITHUB_HEAD_REF" = "" ]; then
  moduleVersion='@dev'
else
  moduleVersion="dev-$GITHUB_HEAD_REF"
fi

echo 'module version'
echo $moduleVersion

function runTests {
    echo "Setup for tests..."
    "$GITHUB_WORKSPACE/$SHOP_DIR/vendor/bin/install" DE -r ci -x frontend -x fixtures -v

    if [ "$?" = 0 ]; then
        buildMessage="${buildMessage}\n${GREEN}Install for testing was successful"
    else
        buildMessage="${buildMessage}\n${RED}Install for testing was not successful"
        result=$((result+1))
    fi

    echo "Running tests..."
    "$GITHUB_WORKSPACE/$SHOP_DIR/vendor/bin/codecept" build -c "vendor/spryker-eco/$MODULE_NAME/"
    "$GITHUB_WORKSPACE/$SHOP_DIR/vendor/bin/codecept" run -c "vendor/spryker-eco/$MODULE_NAME/"
    if [[ "$?" = 0 ]]; then
        buildMessage="${buildMessage}\n${GREEN}Tests are passing"
    else
        buildMessage="${buildMessage}\n${RED}Tests are failing"
        result=$((result+1))
    fi
    cd "$GITHUB_WORKSPACE/$SHOP_DIR"
    echo "Tests finished"

    return $result
}

function checkArchRules {
    echo "Running Architecture sniffer..."
    errors=`vendor/bin/console code:sniff:architecture -p 2 -m SprykerEco."$moduleNameCapitalized" -v`
    errorsPresent=$?

    if [[ "$errorsPresent" = "0"  ]]; then
        buildMessage="$buildMessage\n${GREEN}Architecture sniffer reports no errors"
    else
        errorsCount=`echo "$errors" | wc -l`
        echo -e "$errors"
        buildResult=1
    fi
}

function checkCodeSniffRules {
    licenseFile="$GITHUB_WORKSPACE/.license"
    if [[ -f "$licenseFile" ]]; then
        echo "Preparing correct license for code sniffer..."
        cp "$licenseFile" "$GITHUB_WORKSPACE/$SHOP_DIR/.license"
    fi

    echo "Running code sniffer..."
    errors=`vendor/bin/console code:sniff:style "vendor/spryker-eco/$MODULE_NAME/src"`
    errorsPresent=$?

    if [[ "$errorsPresent" = "0" ]]; then
        buildMessage="$buildMessage\n${GREEN}Code sniffer reports no errors"
    else
        echo -e "$errors"
        buildMessage="$buildMessage\n${RED}Code sniffer reports some error(s)"
        buildResult=1
    fi
}

function checkPHPStan {
    echo "Running PHPStan..."
    errors=`vendor/bin/console code:phpstan -m SprykerEco."$moduleNameCapitalized"`
    errorsPresent=$?

    if [[ "$errorsPresent" = "0" ]]; then
        buildMessage="$buildMessage\n${GREEN}PHPStan reports no errors"
    else
        echo -e "$errors"
        buildMessage="$buildMessage\n${RED}PHPStan reports some error(s)"
        buildResult=1
    fi
}

function checkDependencyViolationFinder {
    echo "Running DependencyViolationFinder"
    errors=`vendor/bin/console dev:dependency:find "SprykerEco.$MODULE_NAME" -vvv`
    errorsPresent=$?

    if [[ "$errorsPresent" = "0" ]]; then
        buildMessage="$buildMessage\n${GREEN}DependencyViolationFinder reports no errors"
    else
        echo -e "$errors"
        buildMessage="$buildMessage\n${RED}DependencyViolationFinder reports some error(s)"
        buildResult=1
    fi
}

function checkWithLatestShop {
    echo "Checking module with latest $PRODUCT_NAME..."

    foundModule=`composer show | grep "spryker-eco/$MODULE_NAME"`;

    echo $foundModule;

    if [ $foundModule ]; then
      echo "composer remove spryker-eco/$MODULE_NAME";
      composer remove "spryker-eco/$MODULE_NAME"
    fi

    echo $GITHUB_WORKSPACE

    echo "Running composer update --with-all-dependencies $composerPreference"
    composer update --with-all-dependencies $composerPreference

    echo "Running composer require "spryker-eco/$MODULE_NAME $moduleVersion" --prefer-source"
    composer require "spryker-eco/$MODULE_NAME $moduleVersion" --prefer-source

    result=$?

    if [[ "$result" = 0 ]]; then
        buildMessage="${buildMessage}\n${GREEN}$MODULE_NAME is compatible with the modules used in $PRODUCT_NAME"
        if runTests; then
            buildResult=0
            checkLatestVersionOfModuleWithShop
        fi
    else
        buildMessage="${buildMessage}\n${RED}$MODULE_NAME is not compatible with the modules used in $PRODUCT_NAME"
        checkLatestVersionOfModuleWithShop
    fi
}

function checkLatestVersionOfModuleWithShop {
    echo "Merging composer.json dependencies..."
    updates=`php "$GITHUB_WORKSPACE/ecoci/build/merge-composer.php" "$GITHUB_WORKSPACE/$MODULE_DIR/composer.json" composer.json "$GITHUB_WORKSPACE/$MODULE_DIR/composer.json"`
    if [[ "$updates" = "" ]]; then
        buildMessage="${buildMessage}\n${GREEN}$MODULE_NAME is compatible with the latest version of modules used in $PRODUCT_NAME"
        return
    fi

    buildMessage="${buildMessage}\nUpdated dependencies in module to match $PRODUCT_NAME\n$updates"
    echo "Installing module with updated dependencies..."
    composer require "spryker-eco/$MODULE_NAME $moduleVersion" --prefer-source

    result=$?
    if [[ "$result" = 0 ]]; then
        buildMessage="${buildMessage}\n${GREEN}$MODULE_NAME is compatible with the latest version of modules used in $PRODUCT_NAME"
        runTests
    else
        buildMessage="${buildMessage}\n${RED}$MODULE_NAME is not compatible with the latest version of modules used in $PRODUCT_NAME"
    fi
}

cd $SHOP_DIR
checkWithLatestShop

if [[ -d "vendor/spryker-eco/$MODULE_NAME/src" ]]; then
    checkArchRules
    checkCodeSniffRules
    checkPHPStan

    # will be added:
    #checkDependencyViolationFinder
fi

echo -e "$buildMessage"
exit $buildResult
