FROM almalinux:9

RUN curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64 -s && \
      chmod 755 /opa

ENV PATH=${PATH}:/

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} opa && useradd -m -u ${UID} -g opa opa
