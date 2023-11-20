
package com.hivemq.extensions.defaultpermission;

import com.hivemq.extension.sdk.api.annotations.NotNull;
import com.hivemq.extension.sdk.api.interceptor.connect.parameter.ConnectInboundInput;
import com.hivemq.extension.sdk.api.interceptor.connect.parameter.ConnectInboundOutput;
import com.hivemq.extension.sdk.api.packets.publish.ModifiableConnectPacket;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.*;


class DefaultPermissionInterceptorTest {

    private @NotNull DefaultPermissionConnectInterceptor interceptor;
    private @NotNull ConnectInboundInput inboundInput;
    private @NotNull ConnectInboundOutput inboundOutput;
    private @NotNull ModifiableConnectPacket packet;

    @BeforeEach
    void setUp() {
        interceptor = new DefaultPermissionConnectInterceptor();
        inboundInput = mock(ConnectInboundInput.class);
        inboundOutput = mock(ConnectInboundOutput.class);
        packet = mock(ModifiableConnectPacket.class);
        when(inboundOutput.getConnectPacket()).thenReturn(packet);
    }

    @Test
    void topicDefaultPermission_userNameModified() {
        when(packet.getUserName().isEmpty()).thenReturn(true);
        interceptor.onConnect(inboundInput, inboundOutput);
        final ArgumentCaptor<String> captor = ArgumentCaptor.forClass(String.class);
        verify(packet).setUserName(captor.capture());
        assertEquals("default", captor.getValue());
    }

    @Test
    void topicNotDefaultPermission_userNameNotModified() {
        when(packet.getUserName().isEmpty()).thenReturn(true);
        interceptor.onConnect(inboundInput, inboundOutput);
        verify(packet, times(0)).setUserName(any());
    }
}