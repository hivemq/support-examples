plugins {
    id ("com.github.johnrengelman.shadow") version "7.1.2"
    id("java")
}

group = "org.example"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

dependencies {
    implementation ("com.hivemq:hivemq-mqtt-client:1.3.3")
    testImplementation(platform("org.junit:junit-bom:5.10.0"))
    testImplementation("org.junit.jupiter:junit-jupiter")
}

/*
tasks.test {
    useJUnitPlatform()
}
*/

tasks {
    test {
        useJUnitPlatform()
    }

    shadowJar {
        mergeServiceFiles()
        manifest {
            attributes(
                "Main-Class" to "com.hivemq.client.mqtt.examples.TlsDemo"
            )
        }
    }
}

tasks.build {
    dependsOn(tasks.shadowJar)
}