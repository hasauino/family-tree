# Build the Flutter web app, then serve the static output with nginx.
#
# The backend's GraphQL endpoint is baked in at build time via API_BASE_URL
# (see lib/config.dart). Override with --build-arg if it ever changes.
FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG API_BASE_URL=https://server.omaritree.com

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
