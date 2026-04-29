package com.grandlabs.buggy.configuration.actuator;

import org.springframework.boot.actuate.info.Info;
import org.springframework.boot.actuate.info.InfoContributor;
import org.springframework.stereotype.Component;

@Component
public class ApplicationInfoContributor implements InfoContributor {

    @Override
    public void contribute(Info.Builder builder) {
        builder.withDetail("version", "0.0.1")
                .withDetail("description", "Buggy Service Spring Boot Application")
                .withDetail("environment", "dev");
    }
}
