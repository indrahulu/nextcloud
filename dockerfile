ARG NEXTCLOUD_VERSION=REQUIRED
FROM nextcloud:${NEXTCLOUD_VERSION}

# ── Timezone (Asia/Jakarta, GMT+07) ───────────────────────────────────
ENV TZ=Asia/Jakarta
RUN set -ex; \
    \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone

# ── Base packages ──────────────────────────────────────────────────────
RUN set -ex; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ffmpeg \
        ghostscript \
        libmagickcore-7.q16-10-extra \
        supervisor \
        nano \
        tzdata \
    ; \
    rm -rf /var/lib/apt/lists/*

# ── Build dependencies (untuk compile PHP extensions) ─────────────────
RUN set -ex; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libbz2-dev \
        libkrb5-dev \
        libsmbclient-dev \
    ; \
    rm -rf /var/lib/apt/lists/*

# ── PHP extensions ────────────────────────────────────────────────────
RUN set -ex; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    \
    docker-php-ext-install bz2; \
    pecl install smbclient; \
    docker-php-ext-enable smbclient; \
    \
    # reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
        | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' \
        | sort -u \
        | xargs -r dpkg-query --search \
        | cut -d: -f1 \
        | sort -u \
        | xargs -rt apt-mark manual; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    ; \
    rm -rf /var/lib/apt/lists/*

# ── Supervisor ────────────────────────────────────────────────────────
RUN mkdir -p \
    /var/log/supervisord \
    /var/run/supervisord \
    ;

COPY supervisor/supervisord.conf /

# ── Apache + SSL ──────────────────────────────────────────────────────
RUN mkdir -p \
    /etc/apache2/ssl \
    ; \
    a2enmod -fq ssl setenvif mime socache_shmcb

COPY apache/000-default.conf /etc/apache2/sites-available/

RUN openssl req -x509 -nodes -days 3650 \
        -subj "/CN=localhost" \
        -newkey rsa:2048 \
        -keyout /etc/apache2/ssl/privkey.pem \
        -out /etc/apache2/ssl/cert.pem \
    && cp /etc/apache2/ssl/cert.pem /etc/apache2/ssl/fullchain.pem \
    && chown www-data:www-data /etc/apache2/ssl/*.pem

ENV NEXTCLOUD_UPDATE=1

CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]