FROM composer:2

RUN apk add --no-cache jq && \
    composer global config allow-plugins.ion-bazan/composer-diff true && \
    composer global require ion-bazan/composer-diff

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
