package com.hivemq.extensions.replaceuser;

import com.hivemq.extension.sdk.api.ExtensionMain;
import com.hivemq.extension.sdk.api.annotations.NotNull;
import com.hivemq.extension.sdk.api.parameter.*;
import com.hivemq.extension.sdk.api.services.Services;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ReplaceUserMain implements ExtensionMain {
    private static final @NotNull Logger log = LoggerFactory.getLogger(ReplaceUserMain.class);

    @Override
    public void extensionStart(
            final @NotNull ExtensionStartInput extensionStartInput,
            final @NotNull ExtensionStartOutput extensionStartOutput) {

        try {
            Services.interceptorRegistry().setConnectInboundInterceptorProvider(input -> {
                log.debug("Creating ConnectInboundInterceptor for Client ID: {}, Port: {}, Listener: {}, Type: {}",
                        input.getClientInformation().getClientId(),
                        input.getConnectionInformation().getListener().get().getPort(),
                        input.getConnectionInformation().getListener().get().getName(),
                        input.getConnectionInformation().getListener().get().getListenerType()
                );
                return new ReplaceUserConnectInterceptor();
            });

            final ExtensionInformation extensionInformation = extensionStartInput.getExtensionInformation();
            log.info("Started " + extensionInformation.getName() + ":" + extensionInformation.getVersion());

        } catch (final Exception e) {
            log.error("Exception thrown at extension start: ", e);
        }
    }

    @Override
    public void extensionStop(
            final @NotNull ExtensionStopInput extensionStopInput,
            final @NotNull ExtensionStopOutput extensionStopOutput) {

        final ExtensionInformation extensionInformation = extensionStopInput.getExtensionInformation();
        log.info("Stopped " + extensionInformation.getName() + ":" + extensionInformation.getVersion());
    }

}