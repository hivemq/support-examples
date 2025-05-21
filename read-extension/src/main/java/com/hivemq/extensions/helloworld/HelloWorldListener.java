/*
 * Copyright 2018-present HiveMQ GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.hivemq.extensions.helloworld;

import com.hivemq.extension.sdk.api.annotations.NotNull;
import com.hivemq.extension.sdk.api.client.parameter.ConnectionAttributeStore;
import com.hivemq.extension.sdk.api.events.client.ClientLifecycleEventListener;
import com.hivemq.extension.sdk.api.events.client.parameters.AuthenticationSuccessfulInput;
import com.hivemq.extension.sdk.api.events.client.parameters.ConnectionStartInput;
import com.hivemq.extension.sdk.api.events.client.parameters.DisconnectEventInput;
import com.hivemq.extension.sdk.api.packets.general.MqttVersion;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.ByteBuffer;
import java.util.Map;
import java.util.Optional;


public class HelloWorldListener implements ClientLifecycleEventListener {

    private static final @NotNull Logger log = LoggerFactory.getLogger(HelloWorldListener.class);

    @Override
    public void onMqttConnectionStart(final @NotNull ConnectionStartInput connectionStartInput) {
        final String clientId = connectionStartInput.getClientInformation().getClientId();
        log.info("onMqttConnectionStart – clientId {}. Read-extension is getting its connection attributes...",
                clientId);

        final ConnectionAttributeStore connectionAttributeStore = connectionStartInput
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
            log.info("onMqttConnectionStart – clientId {}, Key: {}, Value: {}", clientId, key, value);
        }
    }

    @Override
    public void onAuthenticationSuccessful(final @NotNull AuthenticationSuccessfulInput authenticationSuccessfulInput) {

    }

    @Override
    public void onDisconnect(final @NotNull DisconnectEventInput disconnectEventInput) {
        log.info("onDisconnect  – read-extension    – Client disconnected with id: {} ", disconnectEventInput.getClientInformation().getClientId());
    }
}