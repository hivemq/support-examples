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

public class HelloWorldListener implements ClientLifecycleEventListener {

    private static final @NotNull Logger log = LoggerFactory.getLogger(HelloWorldListener.class);

    @Override
    public void onMqttConnectionStart(final @NotNull ConnectionStartInput connectionStartInput) {
        log.info("onMqttConnectionStart – clientId {}. Write-extension is setting its connection attributes \"my data\":\"my value\" ...",
                connectionStartInput.getClientInformation().getClientId());
        // access the Connection Attribute Store via the connection information from the ConnectionStartInput interface
        final ConnectionAttributeStore connectionAttributeStore = connectionStartInput.getConnectionInformation().getConnectionAttributeStore();
        // use the putAsString convenience method
        connectionAttributeStore.putAsString("my data", "my value");
    }

    @Override
    public void onAuthenticationSuccessful(final @NotNull AuthenticationSuccessfulInput authenticationSuccessfulInput) {

    }

    @Override
    public void onDisconnect(final @NotNull DisconnectEventInput disconnectEventInput) {
        log.info("onDisconnect  – write-extension  – Client disconnected with id: {} ", disconnectEventInput.getClientInformation().getClientId());
    }
}