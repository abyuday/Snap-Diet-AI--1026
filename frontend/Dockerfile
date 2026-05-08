# Frontend Dockerfile for Flutter (Hosting via Web)
FROM debian:latest AS build-env

# Install dependencies
RUN apt-get update && apt-get install -y \
    git unzip xz-utils libglu1-mesa ca-certificates --no-install-recommends

# Copy local Flutter SDK archive (avoids flaky network download)
COPY flutter_linux_3.22.0.tar.xz /tmp/flutter_linux_3.22.0.tar.xz
RUN mkdir -p /opt/flutter \
    && tar xf /tmp/flutter_linux_3.22.0.tar.xz -C /opt/flutter --strip-components=1 \
    && rm /tmp/flutter_linux_3.22.0.tar.xz

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Fix git ownership issues and initialize flutter
RUN git config --global --add safe.directory '*' \
    && flutter config --enable-web \
    && flutter precache --web

WORKDIR /app

# Copy the entire source
COPY . .

# Run build
RUN flutter pub upgrade
RUN flutter build web --release --base-href / --web-renderer html --verbose

# Final Stage: Use lightweight nginx to serve the build
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
