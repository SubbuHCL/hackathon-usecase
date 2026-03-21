# Build stage
FROM maven:3.9.0-eclipse-temurin-17 AS build
WORKDIR /workspace
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean package -DskipTests

# Run stage
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /workspace/target/order-service-*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]



# FROM maven:3.9.0-eclipse-temurin-17 as build
# WORKDIR /workspace
# COPY pom.xml .
# COPY src ./src
# RUN mvn -B -DskipTests package

# FROM eclipse-temurin:17-jre
# WORKDIR /app
# COPY --from=build /workspace/target/*.jar app.jar
# EXPOSE 8080
# CMD ["java","-jar","/app/app.jar"]
