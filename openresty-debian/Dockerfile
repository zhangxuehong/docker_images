FROM debian:bullseye-slim

LABEL maintainer="jiang9217@foxmail.com"

ENV OPENRESTY_VERSION 1.19.9.1
ENV OPENRESTY_DOWNLOAD_URL https://openresty.org/download/openresty-1.19.9.1.tar.gz
ENV NGINX_MODULE_VTS_DOWNLOAD_URL https://codeload.github.com/vozlt/nginx-module-vts/tar.gz/v0.1.18

RUN set -eux; \
	addgroup --system --gid 101 nginx; \
    	adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos "nginx user" --shell /bin/false --uid 101 nginx; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	# misc
	apt-get install -y --no-install-recommends \
		make \
		gcc \
		iproute2 \
		git \
		curl \
		dpkg-dev \
		ca-certificates \
	; \
	# openresty
	apt-get install -y --no-install-recommends \
		zlib1g-dev \
		openssl \
		libssl-dev \
		libpcre3-dev \
		gettext-base \
		gnupg2 \
		lsb-base \
		lsb-release \
		software-properties-common \
		acl \
		gzip \
		libbsd0 \
		libc6 \
		libc6-dev \
		libexpat1 \
		libfontconfig1 \
		libfreetype6 \
		libgcc1 \
		libgcrypt20 \
		libgd3 \
		libgeoip1 \
		libgpg-error0 \
		libjbig0 \
		libjpeg62-turbo \
		liblzma5 \
		libpcre3 \
		libpng16-16 \
		libssl1.1 \
		libstdc++6 \
		libtiff5 \
		libuuid1 \
		libwebp6 \
		libx11-6 \
		libxau6 \
		libxcb1 \
		libxdmcp6 \
		libxml2 \
		libxpm4 \
		libxslt1.1 \
		libzstd1 \
		perl \
		procps \
		tar \
		zlib1g \
	; \
	rm -rf /var/lib/apt/lists/*; \
# install openresty
        tempDir="$(mktemp -d)"; \
        cd $tempDir; \
        mkdir nginx-module-vts; \
        cd nginx-module-vts; \
        curl -o nginx-module-vts.tar.gz "$NGINX_MODULE_VTS_DOWNLOAD_URL"; \
        tar zxf nginx-module-vts.tar.gz --strip-components=1; \
        rm -f nginx-module-vtS.tar.gz; \
        cd ../; \
        mkdir openresty; \
        cd openresty; \
        curl -o openresty.tar.gz "$OPENRESTY_DOWNLOAD_URL"; \
        tar zxf openresty.tar.gz --strip-components=1; \
        rm -f openresty.tar.gz; \
        ./configure --add-module=../nginx-module-vts; \
        make; \
        make install; \
        cd /tmp; \
        rm -rf $tempDir; \
        ln -s /usr/local/openresty/nginx/sbin/nginx /usr/bin/; \
        cd /usr/local/openresty; \
        git clone https://github.com/knyar/nginx-lua-prometheus.git; \
        ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log; \
        ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log; \
        mkdir /docker-entrypoint.d; \
	mkdir /usr/local/openresty/lua-script; \
        chown -R nginx.nginx /usr/local/openresty; \

	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
        find /usr/local -type f -executable -exec ldd '{}' ';' \
                | awk '/=>/ { print $(NF-1) }' \
                | sort -u \
                | xargs -r dpkg-query --search \
                | cut -d: -f1 \
                | sort -u \
                | xargs -r apt-mark manual \
	;\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

ENV PATH=$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin

COPY docker-entrypoint.sh /
COPY 10-listen-on-ipv6-by-default.sh /docker-entrypoint.d
COPY 20-envsubst-on-templates.sh /docker-entrypoint.d
COPY 30-tune-worker-processes.sh /docker-entrypoint.d

WORKDIR /usr/local/openresty

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 80 443 8080 8443

STOPSIGNAL SIGQUIT

CMD ["openresty", "-g", "daemon off;"]
