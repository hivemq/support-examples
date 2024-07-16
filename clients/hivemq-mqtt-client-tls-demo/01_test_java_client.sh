#!/usr/bin/env bash

export KEYSTORE_PATH="path/to/client-all-keystore.jks"
export KEYSTORE_PASS="changeme"
export KEYSTORE_ALIAS="client2"
export KEYSTORE_TYPE="JKS"
export PRIVATE_KEY_PASS="changeme"
export TRUSTSTORE_PATH="path/to/client-all-truststore.jks"
export TRUSTSTORE_PASS="changeme"
export TRUSTSTORE_ALIAS="example1.com"
export TRUSTSTORE_TYPE="JKS"
export MQTT_SERVER="example1.com"
export MQTT_PORT=8883
export MQTT_QOS=1
export PUBLISH_TOPIC="Test"
export SUBSCRIBE_TOPIC=""
export VERIFY_HOSTNAME="true"
export CLIENT_ID="TLS_JAVA_CLIENT"

if [ ! -f "$KEYSTORE_PATH" ]; then exit 64; fi
if [ ! -f "$TRUSTSTORE_PATH" ]; then exit 65; fi
if [ ! -f ./build/libs/hivemq-mqtt-client-tls-demo-1.0-SNAPSHOT-all.jar ]; then exit 66; fi

java -jar ./build/libs/hivemq-mqtt-client-tls-demo-1.0-SNAPSHOT-all.jar
