FROM google/dart:2
WORKDIR /build/
ADD pubspec.yaml /build
RUN dart pub get
FROM scratch
