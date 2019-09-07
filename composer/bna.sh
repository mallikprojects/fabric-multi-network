#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
#WORKING_DIR="certificates";
KEY1="INSERT_ORDERER0_CA_CERT";
KEY2="INSERT_ORG1_CA_CERT"
KEY3="INSERT_ORDERER1_CA_CERT";
ORG1_PEER0_KEY="INSERT_ORG1_PEER0_ADDRESS";
ORG1_PEER1_KEY="INSERT_ORG1_PEER1_ADDRESS";
ORG1_PEER2_KEY="INSERT_ORG1_PEER2_ADDRESS";
ORG1_CA_KEY="INSERT_ORG1_CA_ADDRESS";
ORDERER0_KEY="INSERT_ORDERER0_ADDRESS";
ORDERER1_KEY="INSERT_ORDERER1_ADDRESS";
HLF_NETWORK_NAME_KEY="INSERT_ORG1_HLF_NAME";
CHANNEL_NAME_KEY="INSERT_CHANNEL_NAME";

#CRYPTO_DIR=$DIR/../crypto-config

# verify the result of the end-to-end test
verifyResult() {
  if [ $1 -ne 0 ]; then
    echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo "========= ERROR !!! FAILED to execute End-2-End Scenario ==========="
    echo
    exit 1
  fi
}

# Copies Admin user certificates and keys in to $DIR/$WORKING_DIR, creates multi-network.json from the template multi-network-template.json
configNetwork(){
  CRYPTO_DIR=$1
  WORKING_DIR=$2
  HLF_NAME=$8
  ORG1=$CRYPTO_DIR/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
  
  echo 'Copying Certificates and required configurations. Please wait..'
  if [ -d "$DIR/$WORKING_DIR" ]
    then 
     	rm -Rf $WORKING_DIR; 
    fi
    if [ -d "multi-network.json" ]
    then 
        rm -f multi-network.json 
    fi
  
  # $1 -Orderer CA Certificate
  # $2 -Org1 CA Certificate
  # $3 -Peer0 Address
  # $4 -Peer1 Address
  # $5 -Peer2 Address
  # $6 -Orderer Address
  # $7 -Org 1 CA Address
  # $8 -HLF name
  # $9 -Channel Name

  mkdir -p $DIR/$WORKING_DIR;
  cp $CRYPTO_DIR/ordererOrganizations/example.com/orderers/orderer0.example.com/tls/ca.crt $DIR/$WORKING_DIR/orderer0-ca.crt
  cp $CRYPTO_DIR/ordererOrganizations/example.com/orderers/orderer1.example.com/tls/ca.crt $DIR/$WORKING_DIR/orderer1-ca.crt
  cp $CRYPTO_DIR/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt $DIR/$WORKING_DIR/org1-ca.crt
  cp $DIR/multi-network-template.json $DIR/multi-network.json
  sed -i -e "s|$KEY1|$(awk 'NF {sub(/\r/, ""); printf "%s\\\\n",$0;}' $DIR/$WORKING_DIR/orderer0-ca.crt)|g" $DIR/multi-network.json
  sed -i -e "s|$KEY3|$(awk 'NF {sub(/\r/, ""); printf "%s\\\\n",$0;}' $DIR/$WORKING_DIR/orderer1-ca.crt)|g" $DIR/multi-network.json
  sed -i -e "s|$KEY2|$(awk 'NF {sub(/\r/, ""); printf "%s\\\\n",$0;}' $DIR/$WORKING_DIR/org1-ca.crt)|g" $DIR/multi-network.json
  sed -i -e "s/$ORG1_PEER0_KEY/$3/g" $DIR/multi-network.json
  sed -i -e "s/$ORG1_PEER1_KEY/$4/g" $DIR/multi-network.json
  sed -i -e "s/$ORG1_PEER2_KEY/$5/g" $DIR/multi-network.json
  sed -i -e "s/$ORDERER0_KEY/$6/g" $DIR/multi-network.json
  sed -i -e "s/$ORG1_CA_KEY/$7/g" $DIR/multi-network.json
  sed -i -e "s/$HLF_NETWORK_NAME_KEY/$HLF_NAME/g" $DIR/multi-network.json
  sed -i -e "s/$CHANNEL_NAME_KEY/$9/g" $DIR/multi-network.json
  #sed -i -e "s/$ORDERER1_KEY/$10/g" $DIR/multi-network.json
  cp -p $ORG1/signcerts/A*.pem $DIR/$WORKING_DIR
  cp -p $ORG1/keystore/*_sk $DIR/$WORKING_DIR
  
  
  echo 'Deleting existing Peer Admin cards..'
  if composer card list -c PeerAdmin@$HLF_NAME > /dev/null; then
    composer card delete -c PeerAdmin@$HLF_NAME
  fi
  echo "Configuration completed successsfully . Output stored in $WORKING_DIR"

}


# Create PeerAdmin card and imports to wallet
createPeerAdmin(){
  CRYPTO_DIR=$1
  WORKING_DIR=$2
  HLF_NAME=$3
  
  echo "Creating Peer Admin card..."
  composer card create -p $DIR/multi-network.json -u PeerAdmin -c $DIR/$WORKING_DIR/Admin@org1.example.com-cert.pem -k $DIR/$WORKING_DIR/*_sk -r PeerAdmin -r ChannelAdmin -f $DIR/$WORKING_DIR/PeerAdmin@$HLF_NAME.card
  verifyResult $? "Failed to create Peer Admin card.."
  echo "Importing Peer Admin card to Wallet..."
  composer card import -f $DIR/$WORKING_DIR/PeerAdmin@$HLF_NAME.card --card PeerAdmin@$HLF_NAME
  verifyResult $? "Failed to import Peer Admin card.."

}

#installs ban file on all the peers 

installNetwork(){
  BNA_FILE=$1
  HLF_NAME=$2
  composer network install --card PeerAdmin@$HLF_NAME --archiveFile $BNA_FILE
  verifyResult $? "Failed to install bna .."
  echo "Installed BNA on all peers"
}


#instantiate bna on endorsing peers as specified in endorsement policy
startNetwork(){
  BNA_FILE=$1
  HLF_NAME=$2
  EPF=$3
  network_name="$(cut -d@ -f1 <<<"$BNA_FILE")"
  temp="$(cut -d@ -f2 <<<"$BNA_FILE")"
  version="$(cut -d. -f1-3 <<<"$temp")"
  
  echo "Starting Business network"
  if composer card list -c PeerAdmin@$HLF_NAME > /dev/null; then
    composer card delete -c admin@$network_name
  fi
  composer network start --networkName $network_name --networkVersion $version -o endorsementPolicyFile=$EPF -A admin -S adminpw -c PeerAdmin@$HLF_NAME
  verifyResult $? "Failed to start bna .."
  composer card import -f admin@$network_name.card
  verifyResult $? "Failed to import network card .."
  echo "Completed "
}


#pings deployed network and check if it is working properly
testNetwork(){
 BNA_FILE=$1
 network_name="$(cut -d@ -f1 <<<"$BNA_FILE")"
 temp="$(cut -d@ -f2 <<<"$BNA_FILE")"
 version="$(cut -d. -f1-3 <<<"$temp")"
 echo "Hold on. We are verifying your Network"
 composer network ping -c admin@$network_name
 verifyResult $? "Failed to ping bna .."
 echo "Business Network is installed and is working fine"
}

upgradeNetwork(){
  BNA_FILE=$1
  HLF_NAME=$2
  network_name="$(cut -d@ -f1 <<<"$BNA_FILE")"
  temp="$(cut -d@ -f2 <<<"$BNA_FILE")"
  version="$(cut -d. -f1-3 <<<"$temp")"
  
  echo "upgrading $network_name version to $version..."
  composer network install -a $BNA_FILE -c PeerAdmin@$HLF_NAME
  verifyResult $? "Failed to install bna update .."
  composer network upgrade -c PeerAdmin@$HLF_NAME -n $network_name -V $version
  verifyResult $? "Failed to upgrade bna .."
  echo "bna upgrade completed successfully"

}

#Add Network admin to existing Network. This function generates a card which needs to be imported on to the peer from where this network admin operates

addNetworkAdmin(){
  BNA_FILE=$1
  USERNAME=$2
  
  network_name="$(cut -d@ -f1 <<<"$BNA_FILE")"
  temp="$(cut -d@ -f2 <<<"$BNA_FILE")"
  version="$(cut -d. -f1-3 <<<"$temp")"
  #composer participant add -c admin@$network_name -d '{"$class":"resource:'$RESOURCE_NS'","name":"'$USERNAME'"}'
  composer participant add -c admin@$network_name -d '{"$class":"org.hyperledger.composer.system.NetworkAdmin","participantId":"'$USERNAME'"}'
  verifyResult $? "Failed to add participant .."
  echo "Issuing Identity.."
  composer identity issue -c admin@$network_name -f $USERNAME.card -u $USERNAME -a "resource:org.hyperledger.composer.system.NetworkAdmin#$USERNAME"
  verifyResult $? "Failed to issue identy .."
  echo "card created : $USERNAME.card use this to operate bna"
}







