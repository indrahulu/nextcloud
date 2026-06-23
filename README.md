# Nextcloud Docker Image

Custom Nextcloud image dengan Apache, SSL self-signed, Supervisor, ffmpeg, ghostscript, dan SMB support.

## Build

`NEXTCLOUD_VERSION` wajib di-specify secara eksplisit:

```bash
docker build --build-arg NEXTCLOUD_VERSION=31.0-apache -t indrahulu/nextcloud:31.0-apache .
docker build --build-arg NEXTCLOUD_VERSION=32.0-apache -t indrahulu/nextcloud:32.0-apache .
docker build --build-arg NEXTCLOUD_VERSION=33.0-apache -t indrahulu/nextcloud:33.0-apache .
docker build --build-arg NEXTCLOUD_VERSION=34.0-apache -t indrahulu/nextcloud:34.0-apache .
```

## Run

```bash
docker run -d -p 80:80 -p 443:443 indrahulu/nextcloud:31.0-apache
```

## Smoke Test

```bash
bash tests/smoke-test.sh 31.0-apache
```
