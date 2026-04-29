FROM eclipse-temurin:25-jre

WORKDIR /app
COPY build/libs/*.jar app.jar

ARG ROLE_ID
ARG SECRET_ID

ENV ROLE_ID=${ROLE_ID} SECRET_ID=${SECRET_ID}

ENTRYPOINT ["java", "-jar", "app.jar"]
