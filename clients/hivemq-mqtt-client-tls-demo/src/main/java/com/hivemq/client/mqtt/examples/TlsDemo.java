package com.hivemq.client.mqtt.examples;

import com.hivemq.client.mqtt.datatypes.MqttQos;
import com.hivemq.client.mqtt.mqtt5.Mqtt5BlockingClient;
import com.hivemq.client.mqtt.mqtt5.Mqtt5Client;
import com.hivemq.client.mqtt.mqtt5.Mqtt5ClientBuilder;

import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLException;
import javax.net.ssl.TrustManagerFactory;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.security.*;
import java.security.cert.CertificateException;
import java.util.concurrent.TimeUnit;

import static com.hivemq.client.mqtt.MqttGlobalPublishFilter.ALL;
import static com.hivemq.client.mqtt.examples.print.TlsPrinter.printKeyStore;
import static java.nio.charset.StandardCharsets.UTF_8;


public class TlsDemo {
    private static final String KEYSTORE_PATH = System.getenv("KEYSTORE_PATH");
    private static final String KEYSTORE_PASS = System.getenv("KEYSTORE_PASS");
    private static final String KEYSTORE_ALIAS = System.getenv("KEYSTORE_ALIAS");
    private static final String KEYSTORE_TYPE = System.getenv("KEYSTORE_TYPE");
    private static final String PRIVATE_KEY_PASS = System.getenv("PRIVATE_KEY_PASS");
    private static final String TRUSTSTORE_PATH = System.getenv("TRUSTSTORE_PATH");
    private static final String TRUSTSTORE_PASS = System.getenv("TRUSTSTORE_PASS");
    private static final String TRUSTSTORE_ALIAS = System.getenv("TRUSTSTORE_ALIAS");
    private static final String TRUSTSTORE_TYPE = System.getenv("TRUSTSTORE_TYPE");
    private static final String hostname = System.getenv("MQTT_SERVER");
    private static final int port = Integer.parseInt(System.getenv("MQTT_PORT"));
    private static final MqttQos qos = MqttQos.fromCode(Integer.parseInt(System.getenv("MQTT_QOS")));
    private static final String clientId = System.getenv("CLIENT_ID");
    private static final String PUBLISH_TOPIC = System.getenv("PUBLISH_TOPIC");
    private static final String SUBSCRIBE_TOPIC = System.getenv("SUBSCRIBE_TOPIC").isEmpty() ? "#" : System.getenv("SUBSCRIBE_TOPIC");
    private static final boolean verifyHostname = Boolean.parseBoolean(System.getenv("VERIFY_HOSTNAME"));

    public static void main(final String[] args) throws InterruptedException, SSLException {

        System.out.println("KEYSTORE_PATH: " + KEYSTORE_PATH);
        System.out.println("KEYSTORE_PASS: " + KEYSTORE_PASS);
        System.out.println("KEYSTORE_ALIAS: " + KEYSTORE_ALIAS);
        System.out.println("KEYSTORE_TYPE: " + KEYSTORE_TYPE);
        System.out.println("PRIVATE_KEY_PASS: " + PRIVATE_KEY_PASS);
        System.out.println("TRUSTSTORE_PATH: " + TRUSTSTORE_PATH);
        System.out.println("TRUSTSTORE_PASS: " + TRUSTSTORE_PASS);
        System.out.println("TRUSTSTORE_ALIAS: " + TRUSTSTORE_ALIAS);
        System.out.println("TRUSTSTORE_TYPE: " + TRUSTSTORE_TYPE);
        System.out.println("MQTT_SERVER: " + hostname);
        System.out.println("MQTT_PORT: " + port);
        System.out.println("MQTT_QOS: " + qos.getCode());
        System.out.println("CLIENT_ID: " + clientId);
        System.out.println("PUBLISH_TOPIC: " + PUBLISH_TOPIC);
        System.out.println("SUBSCRIBE_TOPIC: " + SUBSCRIBE_TOPIC);
        System.out.println("VERIFY_HOSTNAME: " + verifyHostname);

        printKeyStore(new File(KEYSTORE_PATH), KEYSTORE_PASS, KEYSTORE_TYPE);
        printKeyStore(new File(TRUSTSTORE_PATH), TRUSTSTORE_PASS, TRUSTSTORE_TYPE);

        final Mqtt5BlockingClient client;

        Mqtt5ClientBuilder clientBuilder = Mqtt5Client.builder()
                .identifier(clientId)
                .serverHost(hostname)
                .serverPort(port)
                ;
        if ((KEYSTORE_ALIAS == null )|| KEYSTORE_ALIAS.isEmpty()) {
            System.out.println("Loading whole keyStore: " + KEYSTORE_PATH);
            clientBuilder.sslConfig()
                    .keyManagerFactory(keyManagerFromKeystore(new File(KEYSTORE_PATH), KEYSTORE_PASS, PRIVATE_KEY_PASS))
                    .applySslConfig();
        } else {
            System.out.println("Loading only alias: "+KEYSTORE_ALIAS+", keyStore: " + KEYSTORE_PATH);
            clientBuilder.sslConfig()
                    .keyManagerFactory(keyManagerFromKeystore(new File(KEYSTORE_PATH), KEYSTORE_PASS, PRIVATE_KEY_PASS, KEYSTORE_ALIAS))
                    .applySslConfig();
        }

        if ((TRUSTSTORE_ALIAS == null)||TRUSTSTORE_ALIAS.isEmpty()) {
            System.out.println("Loading whole truststore: " + TRUSTSTORE_PATH);
            clientBuilder.sslConfig()
                    .trustManagerFactory(trustManagerFromKeystore(new File(TRUSTSTORE_PATH), TRUSTSTORE_PASS))
                    .applySslConfig();
        } else {
            System.out.println("Loading only alias: "+TRUSTSTORE_ALIAS+", keyStore: " + TRUSTSTORE_PATH);
            clientBuilder.sslConfig()
                    .trustManagerFactory(trustManagerFromKeystore(new File(TRUSTSTORE_PATH), TRUSTSTORE_PASS, TRUSTSTORE_ALIAS))
                    .applySslConfig();
        }
        if (!verifyHostname) {
            System.out.println("Building the client to bypass hostname verification!");

            clientBuilder.sslConfig().hostnameVerifier((hostname, session) -> {
                System.out.println("Trusting without hostname verification to: " + hostname);
                return true;
            }).applySslConfig();
        } else {
            System.out.println("Building the client to perform hostname verification as usual.");
        }

        client = clientBuilder.buildBlocking();

        client.toAsync().publishes(ALL, publish -> {
            System.out.println("Received message: " +
                    publish.getTopic() + " -> " +
                    UTF_8.decode(publish.getPayload().get()));

            // disconnect the client after a message was received
            // client.disconnect();
        });

        System.out.println("connecting client...");
        client.connect();
        client.subscribeWith()
                .topicFilter(SUBSCRIBE_TOPIC)
                .qos(qos)
                .send();

        if (!PUBLISH_TOPIC.isEmpty()) {
            client.publishWith()
                    .topic(PUBLISH_TOPIC)
                    .payload(UTF_8.encode("Hello"))
                    .qos(qos)
                    .send();
        }

        System.out.println("wait a bit");
        for (int i = 0; i < 5; i++) {
            TimeUnit.MILLISECONDS.sleep(50);
            System.out.println(".");
        }
        client.disconnect();
    }

    public static TrustManagerFactory trustManagerFromKeystore(
            final File trustStoreFile, final String trustStorePassword) throws SSLException {

        try (final FileInputStream fileInputStream = new FileInputStream(trustStoreFile)) {
            final KeyStore keyStore = KeyStore.getInstance(KEYSTORE_TYPE);
            keyStore.load(fileInputStream, trustStorePassword.toCharArray());

            final TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
            tmf.init(keyStore);

            return tmf;

        } catch (final KeyStoreException | IOException e) {
            throw new SSLException(
                    "Not able to open or read trust store '" + trustStoreFile.getAbsolutePath() + "'", e);
        } catch (final NoSuchAlgorithmException | CertificateException e) {
            throw new SSLException(
                    "Not able to read certificate from trust store '" + trustStoreFile.getAbsolutePath() + "'", e);
        }
    }

    public static TrustManagerFactory trustManagerFromKeystore(
            final File trustStoreFile, final String trustStorePassword,
            final String alias) throws SSLException {

        try (final FileInputStream fileInputStream = new FileInputStream(trustStoreFile)) {
            final KeyStore originalKeyStore = KeyStore.getInstance(TRUSTSTORE_TYPE);
            originalKeyStore.load(fileInputStream, trustStorePassword.toCharArray());

            final KeyStore filteredKeyStore = KeyStore.getInstance(TRUSTSTORE_TYPE);
            filteredKeyStore.load(null, null); // Initialize an empty KeyStore

            if (originalKeyStore.containsAlias(alias)) {
                final java.security.cert.Certificate cert = originalKeyStore.getCertificate(alias);
                filteredKeyStore.setCertificateEntry(alias,cert);
            } else {
                throw new SSLException("Alias " + alias + " not found in the keyStore");
            }

            final TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
            tmf.init(filteredKeyStore);

            return tmf;

        } catch (final KeyStoreException | IOException e) {
            throw new SSLException(
                    "Not able to open or read trust store '" + trustStoreFile.getAbsolutePath() + "'", e);
        } catch (final NoSuchAlgorithmException | CertificateException e) {
            throw new SSLException(
                    "Not able to read certificate from trust store '" + trustStoreFile.getAbsolutePath() + "'", e);
        }
    }

    public static KeyManagerFactory keyManagerFromKeystore(
            final File keyStoreFile,
            final String keyStorePassword,
            final String privateKeyPassword,
            final String alias) throws SSLException {

        try (final FileInputStream fileInputStream = new FileInputStream(keyStoreFile)) {
            // Load the original keyStore
            final KeyStore originalKeyStore = KeyStore.getInstance(KEYSTORE_TYPE);
            originalKeyStore.load(fileInputStream, keyStorePassword.toCharArray());

            // Create a new keyStore
            final KeyStore filteredKeyStore = KeyStore.getInstance(KEYSTORE_TYPE);
            filteredKeyStore.load(null, null);

            // Copy only the specific alias entry to the new keyStore
            if (originalKeyStore.containsAlias(alias)) {
                final Key key = originalKeyStore.getKey(alias, privateKeyPassword.toCharArray());
                final java.security.cert.Certificate[] certChain = originalKeyStore.getCertificateChain(alias);
                filteredKeyStore.setKeyEntry(alias, key, privateKeyPassword.toCharArray(), certChain);
            } else {
                throw new SSLException("Alias " + alias + " not found in the keyStore");
            }

            // Initialize the KeyManagerFactory with the new keyStore
            final KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
            kmf.init(filteredKeyStore, privateKeyPassword.toCharArray());
            return kmf;

        } catch (KeyStoreException | NoSuchAlgorithmException | CertificateException | UnrecoverableKeyException | IOException e) {
            throw new SSLException("Error processing the keyStore", e);
        }
    }

    public static KeyManagerFactory keyManagerFromKeystore(
            final File keyStoreFile,
            final String keyStorePassword,
            final String privateKeyPassword) throws SSLException {

        try (final FileInputStream fileInputStream = new FileInputStream(keyStoreFile)) {
            final KeyStore keyStore = KeyStore.getInstance(KEYSTORE_TYPE);
            keyStore.load(fileInputStream, keyStorePassword.toCharArray());

            final KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
            kmf.init(keyStore, privateKeyPassword.toCharArray());
            return kmf;

        } catch (final UnrecoverableKeyException e) {
            throw new SSLException(
                    "Not able to recover key from key store '" + keyStoreFile.getAbsolutePath() + "', please check your private key password and your key store password",
                    e);
        } catch (final KeyStoreException | IOException e) {
            throw new SSLException("Not able to open or read key store '" + keyStoreFile.getAbsolutePath() + "'", e);

        } catch (final NoSuchAlgorithmException | CertificateException e) {
            throw new SSLException(
                    "Not able to read certificate from key store '" + keyStoreFile.getAbsolutePath() + "'", e);
        }
    }
}
