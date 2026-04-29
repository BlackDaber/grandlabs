package com.grandlabs.buggy.configuration.actuator;

import org.springframework.boot.actuate.info.Info;
import org.springframework.boot.actuate.info.InfoContributor;
import org.springframework.stereotype.Component;

@Component
public class ApplicationInfoContributor implements InfoContributor {

    /**
     * Contributes application metadata to the Actuator `/info` endpoint.
     *
     * Adds the following details to the provided builder: `version` = "0.0.1",
     * `description` = "Buggy Service Spring Boot Application", and `environment` = "dev".
     *
     * @param builder the Actuator Info.Builder to populate with application details
     */
    @Override
    public void contribute(Info.Builder builder) {
        builder.withDetail("version", "0.0.1")
                .withDetail("description", "Buggy Service Spring Boot Application")
                .withDetail("environment", "dev");
    }
}
