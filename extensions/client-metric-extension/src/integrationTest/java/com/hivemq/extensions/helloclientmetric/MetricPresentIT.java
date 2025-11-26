package com.hivemq.extensions.helloclientmetric;

import com.hivemq.client.mqtt.mqtt5.Mqtt5BlockingClient;
import com.hivemq.client.mqtt.mqtt5.Mqtt5Client;
import java.io.IOException;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;
import org.jetbrains.annotations.NotNull;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;
import org.testcontainers.hivemq.HiveMQContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.utility.DockerImageName;
import org.testcontainers.utility.MountableFile;
import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assertions.assertEquals;

public class MetricPresentIT {
	@Container
	final @NotNull HiveMQContainer extension = new HiveMQContainer(DockerImageName.parse("hivemq/hivemq-ce").withTag("latest"))
			.withExtension(MountableFile.forClasspathResource("hivemq-hello-world-extension"))
			.waitForExtension("Hello Client Metric Extension")
			.withExtension(MountableFile.forClasspathResource("hivemq-prometheus-extension"))
			.waitForExtension("Prometheus Monitoring Extension")
			.withExposedPorts(1883, 9399, 9000);;

	@Test
	@Timeout(value = 5, unit = TimeUnit.MINUTES)
	void test_metric_present() throws InterruptedException, IOException {
		final Mqtt5BlockingClient client = Mqtt5Client.builder()
				.identifier("client1")
				.serverPort(extension.getMqttPort())
				.buildBlocking();
		client.connect();

		final Map<String, Float> metrics = getMetrics(extension.getHost(), extension.getMappedPort(9399));
		assertEquals(0.0f, metrics.get("com_hivemq_client1_message_queue_size"));
	}

	private @NotNull Map<String, Float> getMetrics(final @NotNull String serverHost, final int serverPort)
			throws IOException {

		final OkHttpClient client = new OkHttpClient();
		final Request request1 =
				new Request.Builder().url("http://" + serverHost + ":" + serverPort + "/metrics").build();

		final String string;
		try (final Response response1 = client.newCall(request1).execute()) {
			final ResponseBody body = response1.body();
			assertNotNull(body);
			string = body.string();
		}

		return parseMetrics(string);
	}

	private @NotNull Map<String, Float> parseMetrics(
			final @NotNull String metricsDump) {

		return metricsDump.lines()
				.filter(s -> !s.startsWith("#"))
				.map(s -> s.split(" "))
				.map(splits -> Map.entry(splits[0], Float.parseFloat(splits[1])))
				.collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue, Float::max));
	}
}
