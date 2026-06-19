# Build the Flutter web app, then serve the static output with nginx.
#
# The backend's GraphQL endpoint is baked in at build time via API_BASE_URL
# (see lib/config.dart). Override with --build-arg if it ever changes.
FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG API_BASE_URL=https://server.omaritree.com

# Site name, used for the page title and PWA manifest (see web/index.html
# and web/manifest.json, which contain a __SITE_NAME__ placeholder) and for
# the in-app browser tab title (see lib/config.dart's siteName override).
ARG SITE_NAME="Family Tree"

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL} --dart-define=SITE_NAME="${SITE_NAME}"
RUN sed -i "s/__SITE_NAME__/${SITE_NAME}/g" build/web/index.html build/web/manifest.json
# Ensure the App Links / Universal Links verification files are in the served
# output. Some Flutter versions copy web/.well-known automatically and some
# skip dot-directories; this is idempotent either way.
RUN mkdir -p build/web/.well-known && cp web/.well-known/* build/web/.well-known/

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
