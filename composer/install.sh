#!/bin/bash

installComposer() {
  echo "Installing Composer prerequisites, development tools (cli & rest-server)"

  curl -O https://hyperledger.github.io/composer/latest/prereqs-ubuntu.sh
  chmod u+x prereqs-ubuntu.sh
  ./prereqs-ubuntu.sh
  # This hack to fix EACESS errors. Look at https://docs.npmjs.com/getting-started/fixing-npm-permissions
  if [ ! -f "~/.npm-global" ]
  then
    echo "creating npm-global to avoid EACCESS conflicts"
    mkdir ~/.npm-global
    npm config set prefix '~/.npm-global'
    export PATH=~/.npm-global/bin:$PATH
    echo "PATH=$PATH:~/.npm-global" >> ~/.bashrc
    source ~/.profile 
  fi
  #done
  
  echo "Installing Version : "$COMPOSER_VER
  npm install -g composer-cli@$COMPOSER_VER
  npm install -g composer-rest-server@$COMPOSER_VER
  npm install -g generator-hyperledger-composer@$COMPOSER_VER
  npm install -g yo

echo
echo "========= All GOOD, installation completed =========== "

}
