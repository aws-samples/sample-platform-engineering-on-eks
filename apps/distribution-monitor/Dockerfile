FROM public.ecr.aws/docker/library/gradle:9.3.0-jdk25-corretto AS builder

WORKDIR /app

# Copy build files
COPY build.gradle settings.gradle ./

# Download dependencies (cached layer)
RUN gradle dependencies --no-daemon || true

# Copy source code
COPY src src

# Build application
ARG GIT_HASH=unknown
RUN GIT_HASH=${GIT_HASH} gradle bootJar --no-daemon

FROM public.ecr.aws/amazoncorretto/amazoncorretto:25-headless

WORKDIR /app

# Copy built JAR from builder
COPY --from=builder /app/build/libs/app.jar app.jar

# Install shadow-utils for user management
RUN dnf install -y shadow-utils && \
    dnf clean all && \
    groupadd -r appgroup && \
    useradd -r -g appgroup -s /sbin/nologin appuser && \
    chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
