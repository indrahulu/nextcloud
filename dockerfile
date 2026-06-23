FROM nextcloud:31.0-apache

RUN set -ex; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ffmpeg \
        ghostscript \
        # 2025-09-13 update dari https://help.nextcloud.com/t/problem-with-building-full-docker-image-from-example-nextcloud-31-0-8-apache/230628/7
        # libmagickcore-6.q16-6-extra \
        libmagickcore-7.q16-10-extra \
        supervisor \
        nano \
    ; \
    rm -rf /var/lib/apt/lists/*

RUN set -ex; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libbz2-dev \
        # error. belum ketemu bisa ambil dari mana. ngaruh ke imap...
        # libc-client-dev \
        libkrb5-dev \
        libsmbclient-dev \
    ;

RUN set -ex; \
    \
    # error...
    # docker-php-ext-configure imap --with-kerberos --with-imap-ssl; \
    docker-php-ext-install \
        bz2 \
        # error...
        # imap \
    ; \
    pecl install smbclient; \
    docker-php-ext-enable smbclient; \
    \
    # reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
    # apt-mark auto '.*' > /dev/null; \
    # apt-mark manual $savedAptMark; \
    # ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
    #     | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' \
    #     | sort -u \
    #     | xargs -r dpkg-query --search \
    #     | cut -d: -f1 \
    #     | sort -u \
    #     | xargs -rt apt-mark manual; \
    # \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    ; \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p \
    /var/log/supervisord \
    /var/run/supervisord \
    ;

COPY supervisor/supervisord.conf /

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