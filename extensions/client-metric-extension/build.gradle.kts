plugins {
    alias(libs.plugins.hivemq.extension)
    alias(libs.plugins.defaults)
    alias(libs.plugins.license)
}

group = "com.hivemq.extensions"
description = "HiveMQ 4 Hello Client Metric Extension - adds com.hivemq.client1.message-queue-size metric."

hivemqExtension {
    name = "Hello Client Metric Extension"
    author = "Dasha Samkova"
    priority = 1000
    startPriority = 1000
    mainClass = "$group.helloclientmetric.HelloClientMetricMain"
    sdkVersion = "$version"

    resources {
        from("LICENSE")
    }
}

dependencies {
    implementation("com.google.code.gson:gson:${property("gson.version")}")
    implementation("com.squareup.okhttp3:okhttp:${property("okhttp.version")}")
}

@Suppress("UnstableApiUsage")
testing {
    suites {
        withType<JvmTestSuite> {
            useJUnitJupiter(libs.versions.junit.jupiter)
        }
        "test"(JvmTestSuite::class) {
            dependencies {
                implementation(libs.mockito)
            }
        }
        "integrationTest"(JvmTestSuite::class) {
            dependencies {
                compileOnly(libs.jetbrains.annotations)
                implementation(libs.hivemq.mqttClient)
                implementation(libs.testcontainers.junitJupiter)
                implementation(libs.testcontainers.hivemq)
                implementation("com.squareup.okhttp3:okhttp:${property("okhttp.version")}")
                runtimeOnly(libs.logback.classic)
            }
        }
    }
}

license {
    header = rootDir.resolve("HEADER")
    mapping("java", "SLASHSTAR_STYLE")
}

/* ******************** debugging ******************** */

tasks.prepareHivemqHome {
    hivemqHomeDirectory = file("/Users/ds/hivemq/hivemq-4.46.0")
}

tasks.runHivemqWithExtension {
    debugOptions {
        enabled = false
    }
}
