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
