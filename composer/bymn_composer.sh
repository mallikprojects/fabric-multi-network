#!/bin/bash

# This script will orchestrate a sample end-to-end execution of the Hyperledger
# composer over multi host fabric network.
#
export PATH=${PWD}:${PWD}:$PATH
export PATH=~/.npm-global/bin:$PATH
export VERBOSE=false

#configuration parameters
CHANNEL_NAME="gcchannel"
COMPOSER_VER="0.20"
ORG1_PEER0_ADDRESS="104.215.188.7"
ORG1_PEER1_ADDRESS="13.67.44.215"
ORG1_PEER2_ADDRESS="13.67.41.97"
ORDERER0_ADDRESS="104.215.188.7"
ORDERER1_ADDRESS="13.67.41.145"
ORG1_CA_ADDRESS="13.67.44.215"
ORG1_HLF_NETWORK_NAME="bymn-org1"
ENDORSEMENT_POLICY_FILE="endorsement_policy.json" #edorsement policy. currently requires endorsement from all the three peers
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
CRYPTO_DIR=$DIR/../crypto-config
CRT_DIR="certificates/org1"; #out directory to store required certificates
BNA_FILE="tutorial-network.bna" #default bna file
USERNAME="testuser"


#import install.sh and bna.sh
. install.sh
. bna.sh
# Print the usage message
function printHelp() {
  echo "Usage: "
  echo "  bymn_composer.sh <mode> [-c <channel name>] [-i <composer_ver>] [-f BNA file] [-f <docker-compose-file>] [-u <username>] [-r resource_namespace] [-v]"
  echo "    <mode> - one of 'install' 'config', 'up', 'upgrade' or add_network_admin"
  echo "      - 'install' - installs composer and related dependencies"
  echo "      - 'config' - generate required certificates, endorsement  and connection profiles to start  "
  echo "      - 'up' - bring up the composer business network"
  echo "      - 'upgrade' - upgrades existing bna"
  echo "      - 'add_network_admin' - Add new network admin to existing business network"
  echo "    -v - verbose mode"
  echo "  bymn_composer.sh -h (print this message)"
  echo "Taking all defaults:"
  echo "	bymn_composer.sh install"
  echo "	bymn_composer.sh generate"
  echo "	bymn_composer.sh up -f <bna file with version in the name tutorial-network@0.0.1@bna>"
  echo "	bymn_composer.sh upgrade -f <bna file with version in the name tutorial-network@0.0.1@bna>"
  
}

# Ask user for confirmation to proceed
function askProceed() {
  read -p "Continue? [Y/n] " ans
  case "$ans" in
  y | Y | "")
    echo "proceeding ..."
    ;;
  n | N)
    echo "exiting..."
    exit 1
    ;;
  *)
    echo "invalid response"
    askProceed
    ;;
  esac
}


# Generate the needed certificates, the genesis block and start the network.
function networkUp() {
  # install and start bna network
  if [  -d "$CRT_DIR" ]; then
    installNetwork $BNA_FILE $ORG1_HLF_NETWORK_NAME
    startNetwork $BNA_FILE $ORG1_HLF_NETWORK_NAME $ENDORSEMENT_POLICY_FILE
    testNetwork $BNA_FILE
  else
  echo "BNA configuration is not done yet. Run ./bymn_composer config first"
  fi
  
}

function networkConfig(){
  configNetwork $CRYPTO_DIR $CRT_DIR $ORG1_PEER0_ADDRESS $ORG1_PEER1_ADDRESS $ORG1_PEER2_ADDRESS $ORDERER0_ADDRESS $ORG1_CA_ADDRESS $ORG1_HLF_NETWORK_NAME $CHANNEL_NAME $ORDERER1_ADDRESS
  createPeerAdmin $CRYPTO_DIR $CRT_DIR $ORG1_HLF_NETWORK_NAME
}




# Obtain the OS and Architecture string that will be used to select the correct
# native binaries for your platform, e.g., darwin-amd64 or linux-amd64
OS_ARCH=$(echo "$(uname -s | tr '[:upper:]' '[:lower:]' | sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
if [ "$1" = "-m" ]; then # supports old usage, muscle memory is powerful!
  shift
fi
MODE=$1
shift
# Determine whether starting, stopping, restarting, generating or upgrading
if [ "$MODE" == "install" ]; then
  EXPMODE="Install pre requisites ,composer, composer-rest-server and other related dependencies to run business network"
elif [ "$MODE" == "config" ]; then
  EXPMODE="Copy certs ,configure connection.json and endorsement policy file"
elif [ "$MODE" == "up" ]; then
  EXPMODE="Starting Business Network"
elif [ "$MODE" == "upgrade" ]; then
  EXPMODE="Upgrading the business network"
elif [ "$MODE" == "add_network_admin" ]; then
  EXPMODE="Add new participant to the business network"
else
  printHelp
  exit 1
fi

ROLE=$2

while getopts "h?c:u:r:f:i:v:j" opt; do
  case "$opt" in
  h | \?)
    printHelp
    exit 0
    ;;
  c)
    CHANNEL_NAME=$OPTARG
    ;;
  i)
    COMPOSER_VER=$OPTARG
    ;;
  f)
    BNA_FILE=$OPTARG
    ;;
  u)
    USERNAME=$OPTARG
    ;;
  v)
    VERBOSE=true
    ;;
  esac
done


# Announce what was requested

  echo "${EXPMODE}"
# ask for confirmation to proceed
askProceed

#Create the network using docker compose
if [ "${MODE}" == "install" ]; then
  installComposer 
elif [ "${MODE}" == "up" ]; then
  networkUp
elif [ "${MODE}" == "config" ]; then ## Copy certificates, configure connection.json and endorsement policy
  networkConfig
elif [ "${MODE}" == "upgrade" ]; then ## Upgrade the network from version 1.1.x to 1.2.x
  upgradeNetwork $BNA_FILE $ORG1_HLF_NETWORK_NAME
elif [ "${MODE}" == "add_network_admin" ]; then ## Upgrade the network from version 1.1.x to 1.2.x
  addNetworkAdmin $BNA_FILE $USERNAME 
    
else
  printHelp
  exit 1
fi
