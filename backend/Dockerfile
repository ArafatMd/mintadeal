# Build: docker build -t mintadeal-api backend
FROM maven:3.9-eclipse-temurin-25 AS build
WORKDIR /src
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src src
RUN mvn -q -B -DskipTests package && cp target/mintadeal-backend-*.jar /app.jar

FROM eclipse-temurin:25-jre
RUN useradd --system --uid 10001 mintadeal && mkdir -p /data/files && chown mintadeal /data/files
USER mintadeal
COPY --from=build /app.jar /app/app.jar
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=70 -XX:+ExitOnOutOfMemoryError" \
    FILES_DIR=/data/files
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
