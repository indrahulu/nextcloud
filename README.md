# Nextcloud Docker Image

Custom Nextcloud image dengan Apache, SSL self-signed, Supervisor, ffmpeg, ghostscript, dan SMB support. Repo untuk image ini: [https://github.com/indrahulu/nextcloud](https://github.com/indrahulu/nextcloud)

Image ini dibangun dari `nextcloud:<version>-apache` dan menambahkan:

- `supervisor` sebagai process manager
- `ffmpeg` dan `ghostscript` untuk preview/conversion
- PHP extensions: `bz2`, `smbclient`
- Self-signed SSL certificate (sudah di-generate di `/etc/apache2/ssl/`)
- Dukungan multi versi Nextcloud: `31.0`, `32.0`, `33.0`, `34.0`

## Image Tags

| Tag | Keterangan | Overwrite? |
|-----|-----------|:----------:|
| `31.0-apache` | Latest per versi Nextcloud | ✅ |
| `31.0-apache-v1.2.3` | Versioned, immutable | ❌ |
| `31.0-apache-nightly` | Nightly build | ✅ |

Contoh pull:

```bash
docker pull indrahulu/nextcloud:31.0-apache
docker pull indrahulu/nextcloud:31.0-apache-v1.0.0
docker pull indrahulu/nextcloud:31.0-apache-nightly
```

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

Smoke test memverifikasi:

- Image berhasil di-build
- Container start dan masih running
- PID 1 adalah supervisord
- Supervisord dan Apache berjalan
- HTTP port 80 dan HTTPS port 443 merespons
- PHP extensions (`bz2`, `smbclient`) ter-load
- SSL certificate dan private key ada

```bash
bash tests/smoke-test.sh 31.0-apache
bash tests/smoke-test.sh 32.0-apache
bash tests/smoke-test.sh 33.0-apache
bash tests/smoke-test.sh 34.0-apache
```

## CI/CD

### Workflow: `ci.yml` (Build, Test & Push)

Triggered oleh:

| Event | Kapan |
|---|---|
| `push` ke `master` | Setiap push (kecuali perubahan README) |
| `push` tag `v*` | Saat release versioned |
| `pull_request` ke `master` | Saat ada PR |
| `schedule` (`0 4 * * *`) | Nightly build jam 4 pagi UTC |
| `workflow_dispatch` | Manual trigger |

Pipeline menjalankan build + smoke test untuk semua versi Nextcloud secara parallel (matrix strategy).

**Tagging strategy:**

| Trigger | Tag yang di-push |
|---------|-----------------|
| `schedule` | `31.0-apache-nightly` (overwrite) |
| `tag v1.2.3` | `31.0-apache-v1.2.3` (immutable) + `31.0-apache` (latest overwrite) |
| `workflow_dispatch` | `31.0-apache` (latest overwrite) |

Setelah push versioned tag, job `cleanup` otomatis menghapus tag versi lama via Docker Hub API (keep 5 terbaru per Nextcloud version).

### Workflow: `dockerhub-description.yml`

Otomatis sync `README.md` ke halaman Docker Hub repository setiap kali README diubah.

### Secrets yang dibutuhkan

| Secret | Keterangan |
|--------|-----------|
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
