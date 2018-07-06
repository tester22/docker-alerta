FROM python:3
ENV PYTHONUNBUFFERED 1

LABEL maintainer="Anton Delitsch <anton@trugen.net>"

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.url="http://alerta.io" \
      org.label-schema.vcs-url="https://github.com/tester22/docker-alerta" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0.0-rc.1"

VOLUME /var/local
VOLUME /opt/

# MongoDB defaults… these should not need changing.
ENV MONGODB_DATA=/mongodata/mongo
ENV MONGODB_USER=mongodb
ENV MONGODB_GROUP=mongodb

RUN apt-get update && apt-get install -y \
    git \
    libffi-dev \
    libpq-dev \
    mongodb-clients \
    nginx \
    postgresql-client \
    postgresql-client-common \
    python3-dev \
    supervisor \
    wget \
    mongodb \
    cron

RUN pip install --no-cache-dir virtualenv && \
    virtualenv --python=python3 /venv && \
    /venv/bin/pip install uwsgi alerta letsencrypt git+https://github.com/tester22/alerta.git
    #alerta-server==$VERSION
ENV PATH $PATH:/venv/bin

ADD https://github.com/tester22/angular-alerta-webui/archive/master.tar.gz /tmp/web.tar.gz
RUN tar zxvf /tmp/web.tar.gz -C /tmp && \
    mv /tmp/angular-alerta-webui-master/app /web && \
    mv /web/config.js /web/config.js.orig

COPY wsgi.py /app/wsgi.py
COPY uwsgi.ini /app/uwsgi.ini
COPY nginx.conf /app/nginx.conf

RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stdout /var/log/nginx/error.log
RUN chgrp -R 0 /app /venv /web && \
    chmod -R g=u /app /venv /web && \
    useradd -u 1001 -g 0 alerta && \
    usermod -u 1002 -g 0 mongodb

USER 1001

ENV ALERTA_SVR_CONF_FILE /app/alertad.conf
ENV ALERTA_CONF_FILE /app/alerta.conf
ENV ALERTA_WEB_CONF_FILE /web/config.js

ENV BASE_URL /api
ENV PROVIDER basic
ENV INSTALL_PLUGINS ""
ENV INSTALL_INTEGRATIONS ""

EXPOSE 8080

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

COPY supervisord.conf /app/supervisord.conf
CMD ["supervisord", "-c", "/opt/supervisord.conf"]
