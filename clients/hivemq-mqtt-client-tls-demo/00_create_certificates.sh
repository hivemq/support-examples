#!/usr/bin/env bash
#
# The Script generates Server- and Client- SSL certificates
#

set -e

IFS=',' read -r -a hostnames <<< "${1:-"localhost,example1.com,example2.com"}"  # use the default valueS (if user skips the argument)
defaultPass=${2:-'changeme'}  # use the default value (if user skips the argument)
serverValidity=${3:-1}  # use the default value (if user skips the argument)
clientValidity=${4:-1}  # use the default value (if user skips the argument)
numClients=${5:-2}  # use the default value (if user skips the argument)
keystoreType=${6:-"PKCS12"} # use the default value (if user skips the argument)

declare -A keystoreMap=(  ["JKS"]="jks" ["PKCS12"]="p12" )
if [ "$keystoreType" != "JKS" ]; then keystoreType="PKCS12"; fi
ext=${keystoreMap[$keystoreType]}

brokerKeystoreAll="broker-all-keystore"
brokerKeystoreAllPass=$defaultPass
brokerTruststore="broker-all-truststore"
brokerTruststorePass=$defaultPass
clientKeystoreAll="client-all-keystore"
clientKeystoreAllPass=$defaultPass
clientTruststore="client-all-truststore"
clientTruststorePass=$defaultPass

time1=$(date '+%Y%m%dT%H%M%S')
outputDirectory="certs_${keystoreType}_${time1}"
mkdir -p "$outputDirectory"; pushd "$outputDirectory" > /dev/null

touch readme.txt
{
  echo "hostnames: ${hostnames[*]}"
  echo "defaultPass=${defaultPass}"
  echo "serverValidity=${serverValidity}"
  echo "clientValidity=${clientValidity}"
  echo "created=$(date +%Y-%m-%dT%H:%M:%S)"
  echo "keystoreType: ${keystoreType}"
} >> readme.txt

for hostname in "${hostnames[@]}"
do
  echo "#   DEBUG   Generating certificates for $hostname"
  brokerCert="broker-${hostname}"
  brokerKeystore="broker-${hostname}-keystore"
  brokerKeystorePass=$defaultPass

  #create a new broker $keystoreType keystore
  echo "#   DEBUG   Create a ${brokerKeystore}.${ext}"
  keytool -genkey \
    -keyalg RSA \
    -alias "$hostname" \
    -keystore "${brokerKeystore}.${ext}" \
    -storetype "${keystoreType}" \
    -storepass "${brokerKeystorePass}" \
    -keypass "${brokerKeystorePass}" \
    -validity "${serverValidity}" \
    -keysize 2048 \
    -dname "CN=$hostname"

  #add broker keystore to all-brokers keystore
  echo "#   DEBUG   Add ${brokerKeystore}.${ext} to ${brokerKeystoreAll}.${ext}"
  keytool -importkeystore \
    -alias "$hostname" -destalias "$hostname" \
    -srckeystore "${brokerKeystore}.${ext}" \
    -srcstoretype "${keystoreType}" \
    -srcstorepass "${brokerKeystorePass}" \
    -destkeystore "${brokerKeystoreAll}.${ext}" \
    -deststoretype "${keystoreType}" \
    -storepass "${brokerKeystoreAllPass}" \
    -noprompt

  #export broker's cert .pem from the keystore
  echo "#   DEBUG   Export ${brokerCert}.pem from the ${brokerKeystore}.${ext}"
  keytool -exportcert \
    -alias "$hostname" \
    -keystore "${brokerKeystore}.${ext}" \
    -rfc \
    -file "${brokerCert}.pem" \
    -storepass "$brokerKeystorePass" \
    -storetype "${keystoreType}"

  #convert broker .pem certificate to .crt
  echo "#   DEBUG   Convert ${brokerCert}.pem to ${brokerCert}.crt"
  openssl x509 -outform der \
    -in "${brokerCert}.pem" \
    -out "${brokerCert}.crt"

  # Loop through the keystore types and their extensions
  for keystoreType in "${!keystoreMap[@]}"; do
    ext="${keystoreMap[$keystoreType]}"
    echo "#   DEBUG   Import ${brokerCert}.crt to ${clientTruststore}.${ext}"
    printf "yes\n" | keytool -import \
      -file "${brokerCert}.crt" \
      -alias "$hostname" \
      -keystore "${clientTruststore}.${ext}" \
      -storepass "${clientTruststorePass}" \
      -storetype "${keystoreType}"
  done

done

# Loop to generate client certificates
for i in $(seq 1 "$numClients"); do
  clientCert="client$i-cert"
  clientKey="client$i-key"
  clientKeyPass=$defaultPass
  clientKeystore="client$i-keystore"
  clientKeystorePass=$defaultPass

  #generate .pem based client certificate
  echo "#   DEBUG   Generate ${clientCert}.pem and ${clientKey}.pem"
  openssl req -x509 \
    -newkey rsa:2048 \
    -keyout "${clientKey}.pem" \
    -out "${clientCert}.pem" \
    -days "${clientValidity}" \
    -passout pass:"${clientKeyPass}" \
    -subj "/CN=client$i"

  #convert to .crt
  echo "#   DEBUG   Convert ${clientCert}.pem to ${clientCert}.crt"
  openssl x509 -outform der \
    -in "${clientCert}.pem" \
    -out "${clientCert}.crt"

  # Loop through the keystore types and their extensions
  for keystoreType in "${!keystoreMap[@]}"; do
    ext="${keystoreMap[$keystoreType]}"
    #add client-cert into the broker's truststore
    echo "#   DEBUG   Import ${clientCert}.crt to ${brokerTruststore}.${ext}"
    printf "yes\n" | keytool -import \
      -file "${clientCert}.crt" \
      -alias "client$i" \
      -keystore "${brokerTruststore}.${ext}" \
      -storetype "${keystoreType}" \
      -storepass "${brokerTruststorePass}"
  done

  #create client P12 keystore
  echo "#   DEBUG   Create ${clientKeystore}.p12 with ${clientCert}.pem, ${clientKey}.pem and ${clientCert}.pem"
  openssl pkcs12 \
    -export \
    -in "${clientCert}.pem" \
    -inkey "${clientKey}.pem" \
    -certfile "${clientCert}.pem" \
    -out "${clientKeystore}.p12" \
    -passin pass:"${clientKeyPass}" \
    -passout pass:"${clientKeystorePass}"

  if [[ "$keystoreType" != "PKCS12" ]]; then
    #convert client P12 keystore to $keystoreType keystore
    echo "#   DEBUG   Convert ${clientKeystore}.p12 to ${clientKeystore}.${ext}"
    keytool -importkeystore \
      -alias 1 -destalias "client$i" \
      -srckeystore "${clientKeystore}.p12" \
      -srcstoretype PKCS12 \
      -srcstorepass "${clientKeystorePass}" \
      -destkeystore "${clientKeystore}.${ext}" \
      -deststoretype "${keystoreType}" \
      -storepass "${clientKeystorePass}"
  fi

  # Loop through the keystore types and their extensions
  for keystoreType in "${!keystoreMap[@]}"; do
    ext="${keystoreMap[$keystoreType]}"
    #add client P12 keystore to $keystoreType keystore
    echo "#   DEBUG   Add ${clientKeystore}.p12 to ${clientKeystoreAll}.${ext}"
    keytool -importkeystore \
      -alias 1 -destalias "client$i" \
      -srckeystore "${clientKeystore}.p12" \
      -srcstoretype PKCS12 \
      -srcstorepass "${clientKeystorePass}" \
      -destkeystore "${clientKeystoreAll}.${ext}" \
      -deststoretype "${keystoreType}" \
      -storepass "${clientKeystoreAllPass}" \
      -noprompt
  done

done

popd > /dev/null
echo "#   DEBUG   Certificates saved to: $(pwd)/$outputDirectory"
echo "#   DEBUG   The End."
