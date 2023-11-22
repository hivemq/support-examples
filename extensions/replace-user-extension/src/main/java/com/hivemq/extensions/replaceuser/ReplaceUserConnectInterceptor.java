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

package com.hivemq.extensions.replaceuser;

import com.hivemq.extension.sdk.api.annotations.NotNull;
import com.hivemq.extension.sdk.api.interceptor.connect.ConnectInboundInterceptor;
import com.hivemq.extension.sdk.api.interceptor.connect.parameter.ConnectInboundInput;
import com.hivemq.extension.sdk.api.interceptor.connect.parameter.ConnectInboundOutput;
import com.hivemq.extension.sdk.api.packets.publish.ModifiableConnectPacket;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.charset.StandardCharsets;

public class ReplaceUserConnectInterceptor  implements ConnectInboundInterceptor {
    private static final @NotNull Logger log = LoggerFactory.getLogger(ReplaceUserConnectInterceptor.class);

    @Override
    public void onConnect(final @NotNull ConnectInboundInput input, final @NotNull ConnectInboundOutput output) {
        if (input.getConnectPacket().getUserName().isEmpty()) {
            final ModifiableConnectPacket connectPacket = output.getConnectPacket();
            connectPacket.setUserName("default");
            connectPacket.setPassword(StandardCharsets.UTF_8.encode("default"));

            log.debug("ConnectInboundInterceptor intercepted onConnect with empty UserName updated to default for Client ID: {}, Port: {}, Listener: {}, Type: {}.",
                    input.getClientInformation().getClientId(),
                    input.getConnectionInformation().getListener().get().getPort(),
                    input.getConnectionInformation().getListener().get().getName(),
                    input.getConnectionInformation().getListener().get().getListenerType()
            );
        }
    }
}
