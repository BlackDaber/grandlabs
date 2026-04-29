rootProject.name = "buggy-service"

dependencyResolutionManagement {
    versionCatalogs {
        create("libs") {
            library("logback", "net.logstash.logback:logstash-logback-encoder:9.0")
            library("lombok", "org.projectlombok:lombok:1.18.46")

            library("spring-cloud-vault-starter", "org.springframework.cloud:spring-cloud-starter-vault-config:5.0.1")
            library("springdoc-openapi-starter", "org.springdoc:springdoc-openapi-starter-webmvc-ui:3.0.3")
        }
    }
}

pluginManagement {
    repositories {
        mavenCentral()
        gradlePluginPortal()
    }

    plugins {
        id("org.springframework.boot") version "4.0.6"
        id("io.spring.dependency-management") version "1.1.7"
    }
}
