#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

function dkcl(){
        CONTAINER_IDS=$(docker ps -aq)
	echo
        if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" = " " ]; then
                echo "========== No containers available for deletion =========="
        else
                docker rm -f $CONTAINER_IDS
        fi
	echo
}

function dkrm(){
        DOCKER_IMAGE_IDS=$(docker images | grep "dev\|none\|test-vp\|peer[0-9]-" | awk '{print $3}')
	echo
        if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" = " " ]; then
		echo "========== No images available for deletion ==========="
        else
                docker rmi -f $DOCKER_IMAGE_IDS
        fi
	echo
}

function stopNetwork() {
	echo

  #teardown the network and clean the containers and intermediate images
	dkcl
	dkrm

	#Cleanup the stores
	rm -rf ./fabric-client-kv-org*

	
	echo
}

function startNodesA() {
	# orderer
	docker run -d --restart=always -it --network="my-net" \
	--name orderer.example.com \
	-p 7050:7050
	-e ORDERER_GENERAL_LOGLEVEL=debug \
      	-e ORDERER_GENERAL_LISTENADDRESS=0.0.0.0 \
      	-e ORDERER_GENERAL_GENESISMETHOD=file \
      	-e ORDERER_GENERAL_GENESISFILE=/etc/hyperledger/configtx/genesis.block \
      	-e ORDERER_GENERAL_LOCALMSPID=OrdererMSP \
      	-e ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/crypto/orderer/msp \
      	-e ORDERER_GENERAL_TLS_ENABLED=true \
      	-e ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/crypto/orderer/tls/server.key \
      	-e ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/crypto/orderer/tls/server.crt \
      	-e ORDERER_GENERAL_TLS_ROOTCAS=[/etc/hyperledger/crypto/orderer/tls/ca.crt, /etc/hyperledger/crypto/peerOrg1/tls/ca.crt, /etc/hyperledger/crypto/peerOrg2/tls/ca.crt] \
	-v ./channel:/etc/hyperledger/configtx \
        -v ./channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/:/etc/hyperledger/crypto/orderer \
        -v ./channel/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/:/etc/hyperledger/crypto/peerOrg1 \
        -v ./channel/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/:/etc/hyperledger/crypto/peerOrg2 \
	-w /opt/gopath/src/github.com/hyperledger/fabric/orderers hyperledger/fabric-orderer orderer

	# ca.org1
	docker run -d --restart=always -it --network="my-net" \
	--name ca_peerOrg1 \
	-p 7054:7054 \
	-e FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server \
      	-e FABRIC_CA_SERVER_CA_NAME=ca-org1 \
      	-e FABRIC_CA_SERVER_CA_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.org1.example.com-cert.pem \
      	-e FABRIC_CA_SERVER_CA_KEYFILE=/etc/hyperledger/fabric-ca-server-config/0e729224e8b3f31784c8a93c5b8ef6f4c1c91d9e6e577c45c33163609fe40011_sk \
      	-e FABRIC_CA_SERVER_TLS_ENABLED=true \
      	-e FABRIC_CA_SERVER_TLS_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.org1.example.com-cert.pem \
      	-e FABRIC_CA_SERVER_TLS_KEYFILE=/etc/hyperledger/fabric-ca-server-config/0e729224e8b3f31784c8a93c5b8ef6f4c1c91d9e6e577c45c33163609fe40011_sk \
	-v ./channel/crypto-config/peerOrganizations/org1.example.com/ca/:/etc/hyperledger/fabric-ca-server-config hyperledger/fabric-ca sh -c 'fabric-ca-server start -b admin:adminpw -d'

	# peer0.org1
	docker run -d --restart=always -it --network="my-net" \
	--name peer0.org1.example.com \
	-p 7051:7051 -p 7053:7053 \
	-e CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock \
      	-e CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=artifacts_default \
      	-e CORE_LOGGING_LEVEL=DEBUG \
      	-e CORE_PEER_GOSSIP_USELEADERELECTION=true \
      	-e CORE_PEER_GOSSIP_ORGLEADER=false \
      	-e CORE_PEER_GOSSIP_SKIPHANDSHAKE=true \
      	-e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/crypto/peer/msp \
      	-e CORE_PEER_TLS_ENABLED=true \
      	-e CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/crypto/peer/tls/server.key \
      	-e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/crypto/peer/tls/server.crt \
      	-e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/crypto/peer/tls/ca.crt \
	-e CORE_PEER_ID=peer0.org1.example.com \
      	-e CORE_PEER_LOCALMSPID=Org1MSP \
      	-e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 \
	-v /var/run/:/host/var/run/ \
	-v ./channel/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/:/etc/hyperledger/crypto/peer
	-w /opt/gopath/src/github.com/hyperledger/fabric/peer hyperledger/fabric-peer peer node start

	# peer1.org1
	docker run -d --restart=always -it --network="my-net" \
	--name peer1.org1.example.com \
	-p 7056:7051 -p 7058:7053 \
	-e CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock \
      	-e CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=artifacts_default \
      	-e CORE_LOGGING_LEVEL=DEBUG \
      	-e CORE_PEER_GOSSIP_USELEADERELECTION=true \
      	-e CORE_PEER_GOSSIP_ORGLEADER=false \
      	-e CORE_PEER_GOSSIP_SKIPHANDSHAKE=true \
      	-e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/crypto/peer/msp \
      	-e CORE_PEER_TLS_ENABLED=true \
      	-e CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/crypto/peer/tls/server.key \
      	-e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/crypto/peer/tls/server.crt \
      	-e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/crypto/peer/tls/ca.crt \
	-e CORE_PEER_ID=peer1.org1.example.com \
      	-e CORE_PEER_LOCALMSPID=Org1MSP \
      	-e CORE_PEER_ADDRESS=peer1.org1.example.com:7051 \
	-v /var/run/:/host/var/run/ \
	-v ./channel/crypto-config/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/:/etc/hyperledger/crypto/peer
	-w /opt/gopath/src/github.com/hyperledger/fabric/peer hyperledger/fabric-peer peer node start

}

function startNodesB() {

	# ca.org2
	docker run -d --restart=always -it --network="my-net" \
	--name ca_peerOrg2 \
	-p 8054:7054 \
	-e FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server \
      	-e FABRIC_CA_SERVER_CA_NAME=ca-org2 \
      	-e FABRIC_CA_SERVER_CA_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.org2.example.com-cert.pem \
      	-e FABRIC_CA_SERVER_CA_KEYFILE=/etc/hyperledger/fabric-ca-server-config/a7d47efa46a6ba07730c850fed2c1375df27360d7227f48cdc2f80e505678005_sk \
      	-e FABRIC_CA_SERVER_TLS_ENABLED=true \
      	-e FABRIC_CA_SERVER_TLS_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.org2.example.com-cert.pem \
      	-e FABRIC_CA_SERVER_TLS_KEYFILE=/etc/hyperledger/fabric-ca-server-config/a7d47efa46a6ba07730c850fed2c1375df27360d7227f48cdc2f80e505678005_sk \
	-v ./channel/crypto-config/peerOrganizations/org2.example.com/ca/:/etc/hyperledger/fabric-ca-server-config hyperledger/fabric-ca sh -c 'fabric-ca-server start -b admin:adminpw -d'

	# peer0.org2
	docker run -d --restart=always -it --network="my-net" \
	--name peer0.org2.example.com \
	-p 8051:7051 -p 8053:7053 \
	-e CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock \
      	-e CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=artifacts_default \
      	-e CORE_LOGGING_LEVEL=DEBUG \
      	-e CORE_PEER_GOSSIP_USELEADERELECTION=true \
      	-e CORE_PEER_GOSSIP_ORGLEADER=false \
      	-e CORE_PEER_GOSSIP_SKIPHANDSHAKE=true \
      	-e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/crypto/peer/msp \
      	-e CORE_PEER_TLS_ENABLED=true \
      	-e CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/crypto/peer/tls/server.key \
      	-e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/crypto/peer/tls/server.crt \
      	-e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/crypto/peer/tls/ca.crt \
	-e CORE_PEER_ID=peer0.org2.example.com \
      	-e CORE_PEER_LOCALMSPID=Org2MSP \
      	-e CORE_PEER_ADDRESS=peer0.org2.example.com:7051 \
	-v /var/run/:/host/var/run/ \
	-v ./channel/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/:/etc/hyperledger/crypto/peer
	-w /opt/gopath/src/github.com/hyperledger/fabric/peer hyperledger/fabric-peer peer node start

	# peer1.org2
	docker run -d --restart=always -it --network="my-net" \
	--name peer1.org2.example.com \
	-p 8056:7051 -p 8058:7053 \
	-e CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock \
      	-e CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=artifacts_default \
      	-e CORE_LOGGING_LEVEL=DEBUG \
      	-e CORE_PEER_GOSSIP_USELEADERELECTION=true \
      	-e CORE_PEER_GOSSIP_ORGLEADER=false \
      	-e CORE_PEER_GOSSIP_SKIPHANDSHAKE=true \
      	-e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/crypto/peer/msp \
      	-e CORE_PEER_TLS_ENABLED=true \
      	-e CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/crypto/peer/tls/server.key \
      	-e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/crypto/peer/tls/server.crt \
      	-e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/crypto/peer/tls/ca.crt \
	-e CORE_PEER_ID=peer1.org2.example.com \
      	-e CORE_PEER_LOCALMSPID=Org2MSP \
      	-e CORE_PEER_ADDRESS=peer1.org2.example.com:7051 \
	-v /var/run/:/host/var/run/ \
	-v ./channel/crypto-config/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/:/etc/hyperledger/crypto/peer
	-w /opt/gopath/src/github.com/hyperledger/fabric/peer hyperledger/fabric-peer peer node start

}

function initDockerSwarm() {
	docker swarm init
	sleep 1s
	docker swarm join-token manager
	sleep 1s
	docker network create --attachable --driver overlay my-net 
}

function installNodeModules() {
	echo
	if [ -d node_modules ]; then
		echo "============== node modules installed already ============="
	else
		echo "============== Installing node modules ============="
		npm install
	fi
	echo
}


stopNetwork

installNodeModules

PORT=4000 node app
