FROM google/dart:1.24.3

WORKDIR /build/
COPY . /build
RUN pub get
ARG BUILD_ARTIFACTS_AUDIT=/build/pubspec.lock
FROM scratch
