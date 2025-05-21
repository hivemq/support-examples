package com.hivemq.extensions.helloworld;

import com.hivemq.extension.sdk.api.auth.SimpleAuthenticator;
import com.hivemq.extension.sdk.api.auth.parameter.SimpleAuthInput;
import com.hivemq.extension.sdk.api.auth.parameter.SimpleAuthOutput;
import com.hivemq.extension.sdk.api.annotations.NotNull;
import com.hivemq.extension.sdk.api.client.parameter.ConnectionAttributeStore;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.ByteBuffer;
import java.util.Map;
import java.util.Optional;

public class HelloWorldAuthenticator implements SimpleAuthenticator {
    private static final @NotNull Logger log = LoggerFactory.getLogger(HelloWorldAuthenticator.class);
    @Override
    public void onConnect(final @NotNull SimpleAuthInput simpleAuthInput, final @NotNull SimpleAuthOutput simpleAuthOutput) {
        final String clientId = simpleAuthInput.getClientInformation().getClientId();
        log.info("onConnect – read-extension – clientId {}. Read-extension is getting its connection attributes...",
                clientId);
        final ConnectionAttributeStore connectionAttributeStore = simpleAuthInput
                .getConnectionInformation()
                .getConnectionAttributeStore();

        final Optional<Map<String, ByteBuffer>> optionalConnectionAttributes = connectionAttributeStore.getAll();

        if (optionalConnectionAttributes.isEmpty()) {
            return;
        }

        final Map<String, ByteBuffer> allConnectionAttributes = optionalConnectionAttributes.get();

        for (Map.Entry<String, ByteBuffer> entry : allConnectionAttributes.entrySet()) {
            final ByteBuffer rewind = entry.getValue().asReadOnlyBuffer().rewind();
            final byte[] array = new byte[rewind.remaining()];
            rewind.get(array);
            final String key = entry.getKey();
            final String value = new String(array);
            log.info("onConnect – read-extension – clientId {}, Key: {}, Value: {}", clientId, key, value);
        }

        simpleAuthOutput.nextExtensionOrDefault();
    }
}