FROM debian:bookworm-slim@sha256:f06537653ac770703bc45b4b113475bd402f451e85223f0f2837acbf89ab020a AS download

ARG LIB_URL
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /lib-jars && \
    curl -fsSL "${LIB_URL}" | tar -xz -C /lib-jars

FROM eclipse-temurin:17-jre-jammy@sha256:59188078929e9b65a62fa325bbbbf76f5491d99d1500f1beebce86f1cec05a84

RUN mkdir -p /opt/tplink/EAPController/logs
RUN mkdir -p /opt/tplink/EAPController/data/keystore
RUN mkdir /opt/tplink/EAPController/data/pdf
RUN mkdir /opt/tplink/EAPController/data/autobackup
RUN ln -s /dev/stdout /opt/tplink/EAPController/logs/server.log

COPY --from=download /lib-jars /opt/tplink/EAPController/lib
COPY entrypoint.sh /opt/tplink/EAPController/
COPY properties /opt/tplink/EAPController/properties
COPY data /opt/tplink/EAPController/data

WORKDIR /opt/tplink/EAPController/data

EXPOSE 29811/tcp 29812/tcp 29813/tcp 29814/tcp 8088/tcp 8043/tcp 8843/tcp 29810/udp 27001/udp 29816/tcp 27001/udp

ENV OMADA_MANAGE_HTTP_PORT=8088
ENV OMADA_MANAGE_HTTPS_PORT=8043
ENV OMADA_PORTAL_HTTP_PORT=8088
ENV OMADA_PORTAL_HTTPS_PORT=8843
ENV OMADA_PORT_DISCOVERY=29810
ENV OMADA_PORT_ADOPT_V1=29812
ENV OMADA_PORT_UPGRADE_V1=29813
ENV OMADA_PORT_MANAGER_V1=29811
ENV OMADA_PORT_MANAGER_V2=29814
ENV OMADA_PORT_RTTY=29816
ENV OMADA_PORT_APP_DISCOVERY=27001

# nosemgrep: dockerfile.security.missing-user.missing-user
CMD [ "/opt/tplink/EAPController/entrypoint.sh" ]
