package com.hivemq.client.mqtt.examples.print;

import javax.net.ssl.TrustManager;
import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509TrustManager;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.security.*;
import java.security.cert.*;
import java.security.cert.Certificate;
import java.text.SimpleDateFormat;
import java.util.Collections;
import java.util.Enumeration;

public class TlsPrinter {

    public static void printIssuers(TrustManagerFactory tmf){
        int tmCount=0;
        for (TrustManager tm : tmf.getTrustManagers()) {
            tmCount++;
            System.out.println("TrustManager: " + tmCount);
            if (tm instanceof X509TrustManager) {
                X509TrustManager x509TrustManager = (X509TrustManager) tm;
                X509Certificate[] acceptedIssuers = x509TrustManager.getAcceptedIssuers();
                for (X509Certificate certificate : acceptedIssuers) {
                    System.out.println("Accepted Issuer: " + certificate.getSubjectX500Principal().getName());
                }
            } else {
                System.out.println("TrustManager Class: " + tm.getClass().getName());
            }
        }
    }

    public static void printKey (final java.security.Key key) {
        if (key == null ){
            System.out.println("Key is null");
        } else {
            System.out.println("Key:");
            System.out.println("    Key Algorithm: " + key.getAlgorithm());
            //System.out.println("PublicKey: " + key.getEncoded());
            System.out.println("    Key Format: " + key.getFormat());
        }
    }

    public static void printCertValidity(final java.security.cert.Certificate cert){
        if (cert == null){
            System.out.println("Certificate is null");
        } else {
            if (cert instanceof X509Certificate) {
                X509Certificate x509Cert = (X509Certificate) cert;
                try {
                    x509Cert.checkValidity();
                    System.out.println("    Certificate is valid until " + x509Cert.getNotAfter());
                } catch (CertificateExpiredException e) {
                    System.out.println("    Certificate has expired on " + x509Cert.getNotAfter());
                } catch (CertificateNotYetValidException e) {
                    System.out.println("    Certificate is not yet valid before" + x509Cert.getNotBefore());
                }
            } else {
                System.out.println("Certificate is not X509Certificate.");
            }
        }
    }

    public static void printCert (final java.security.cert.Certificate cert) {
        if (cert == null ){
            System.out.println("Certificate is null");
        } else {
            System.out.println("Certificate:");
            System.out.println("    Type: " + cert.getType());
            SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
            if (cert instanceof X509Certificate) {
                X509Certificate x509Cert = (X509Certificate) cert;

                System.out.println("    Subject: " + x509Cert.getSubjectDN());
                System.out.println("    Issuer: " + x509Cert.getIssuerDN());
                System.out.println("    Valid From: " + sdf.format(x509Cert.getNotBefore()));
                System.out.println("    Valid To: " + sdf.format(x509Cert.getNotAfter()));
                System.out.println("    Serial Number: " + x509Cert.getSerialNumber());
                System.out.println("    Signature Algorithm: " + x509Cert.getSigAlgName());
                System.out.println("    Version: " + x509Cert.getVersion());
            } else {
                System.out.println("Certificate is not an instance of X509Certificate");
            }
        }
    }

    public static void printCertChain(final java.security.cert.Certificate[] certChain){
        if (certChain == null) {
            System.out.println("Cert chain is null");
        } else {
            System.out.println("Cert chain has " + certChain.length + " entries");
            int certCount = 0;
            for (Certificate cert : certChain) {
                certCount++;
                System.out.println("Cert chain certificate: " + certCount);
                printCert(cert);
                printCertValidity(cert);
            }
        }
    }

    public static void printKeyStore(File keyStoreFile, String keyStorePassword, final String keyStoreType) {
        try (FileInputStream fis = new FileInputStream(keyStoreFile)) {
            KeyStore keyStore = KeyStore.getInstance(keyStoreType);
            keyStore.load(fis, keyStorePassword.toCharArray());

            int aliasCount = 0;
            String[] aliases = Collections.list(keyStore.aliases()).stream().toArray(String[]::new);
            System.out.println("Keystore " + keyStoreFile.getName() + " contains " + aliases.length + " aliases.");

            for (String alias: aliases) {
                aliasCount++;

                System.out.println("Alias " + aliasCount + ": " + alias);
                System.out.println("Alias cert chain:");
                final Certificate[] certChain = keyStore.getCertificateChain(alias);
                printCertChain(certChain);

                System.out.println("Alias cert:");
                final Certificate cert = keyStore.getCertificate(alias);
                printCert(cert);

                try {
                    final Key key = keyStore.getKey(alias, keyStorePassword.toCharArray());
                    printKey(key);
                } catch (NoSuchAlgorithmException | UnrecoverableKeyException e) {
                    throw new RuntimeException(e);
                }
            }
        } catch (IOException | CertificateException | NoSuchAlgorithmException | KeyStoreException e) {
            throw new RuntimeException(e);
        }
    }

    public static void printCertificateExpiry(File keyStoreFile, String keyStorePassword, final String keyStoreType) {
        try (FileInputStream fis = new FileInputStream(keyStoreFile)) {
            KeyStore keyStore = KeyStore.getInstance(keyStoreType);
            keyStore.load(fis, keyStorePassword.toCharArray());

            Enumeration<String> aliases = keyStore.aliases();
            while (aliases.hasMoreElements()) {
                String alias = aliases.nextElement();
                try {
                    Certificate cert = keyStore.getCertificate(alias);
                    if (cert instanceof X509Certificate) {
                        X509Certificate x509Cert = (X509Certificate) cert; //https://docs.oracle.com/en/java/javase/11/docs/api/java.base/java/security/cert/X509Certificate.html
                        try {
                            x509Cert.checkValidity();
                            System.out.println("Certificate '" + alias + "' in keyStore " + keyStoreFile.getName() + " is valid until " + x509Cert.getNotAfter());
                        } catch (CertificateExpiredException e) {
                            System.out.println("Certificate '" + alias + "' in keyStore " + keyStoreFile.getName() + " has expired on " + x509Cert.getNotAfter());
                        }
                    }
                } catch (KeyStoreException e) {
                    System.err.println("Error checking certificate with alias '" + alias + "' in keyStore " + keyStoreFile.getName() + ": " + e.getMessage());
                    //throw new Exception("Error checking certificate", e);
                }
            }
        } catch (KeyStoreException | IOException | NoSuchAlgorithmException | CertificateException e) {
            System.err.println("Error checking certificates in keyStore " + keyStoreFile.getAbsolutePath() + ": " + e.getMessage());
            //throw new Exception("Error checking certificate", e);
        }
    }

}
