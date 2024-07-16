#!/usr/bin/env bash

export KEYSTORE_PATH="path/to/client-all-keystore.p12"
export KEYSTORE_PASS="changeme"
export KEYSTORE_ALIAS="client1"
export KEYSTORE_TYPE="PKCS12"
export PRIVATE_KEY_PASS="changeme"
export TRUSTSTORE_PATH="path/to/client-all-truststore.p12"
export TRUSTSTORE_PASS="changeme"
export TRUSTSTORE_ALIAS="localhost"
export TRUSTSTORE_TYPE="PKCS12"
export MQTT_SERVER="localhost"
export MQTT_PORT=8883
export MQTT_QOS=1
export PUBLISH_TOPIC="Test"
export SUBSCRIBE_TOPIC=""
export VERIFY_HOSTNAME="true"
export CLIENT_ID="TLS_JAVA_CLIENT"

if [ ! -f $KEYSTORE_PATH ]; then exit 64; fi
if [ ! -f $TRUSTSTORE_PATH ]; then exit 65; fi

echo "mqtt subscribe -t $SUBSCRIBE_TOPIC -q $MQTT_QOS -i $CLIENT_ID -h $MQTT_SERVER -p $MQTT_PORT \
  --ks $KEYSTORE_PATH --kspw $KEYSTORE_PASS --kspkpw $PRIVATE_KEY_PASS --ts $TRUSTSTORE_PATH --tspw $TRUSTSTORE_PASS"