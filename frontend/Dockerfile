# Frontend Dockerfile for Flutter (Hosting via Web)
FROM debian:latest AS build-env

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils libglu1-mesa ca-certificates --no-install-recommends

# Download Flutter SDK
RUN curl -o flutter_linux_3.22.0.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.22.0-stable.tar.xz \
    && mkdir -p /opt/flutter \
    && tar xf flutter_linux_3.22.0.tar.xz -C /opt/flutter --strip-components=1 \
    && rm flutter_linux_3.22.0.tar.xz

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Fix git ownership issues and initialize flutter
RUN git config --global --add safe.directory '*' \
    && flutter config --enable-web \
    && flutter precache

WORKDIR /app

# Copy the entire source
COPY . .

# Run build
RUN flutter pub upgrade
RUN flutter build web --release || (flutter analyze && exit 1)

# Final Stage: Use lightweight nginx to serve the build
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
