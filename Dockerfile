FROM drydock-prod.workiva.net/workiva/dart2_base_image:1
WORKDIR /build/
ADD pubspec.yaml /build
RUN pub get
FROM scratch
