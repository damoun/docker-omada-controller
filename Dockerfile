FROM maven:alpine@sha256:16691dc7e18e5311ee7ae38b40dcf98ee1cfe4a487fdd0e57bfef76a0415034a as build

COPY pom.xml .

RUN mvn dependency:copy-dependencies
RUN mvn dependency:tree

FROM openjdk:22-jdk-slim-bullseye@sha256:32dcd71705a0e74b3b83d93294afb70c6eb57cf694ccb8dd558724d744bc098d

RUN groupadd -r -g 1000 omada && useradd -r -u 1000 -g omada -s /sbin/nologin omada && \
    mkdir -p /opt/tplink/EAPController/logs \
             /opt/tplink/EAPController/data/keystore \
             /opt/tplink/EAPController/data/pdf \
             /opt/tplink/EAPController/data/autobackup && \
    ln -s /dev/stdout /opt/tplink/EAPController/logs/server.log && \
    rm -rf /var/lib/apt/lists/*

COPY lib /opt/tplink/EAPController/lib
COPY --from=build target/dependency /opt/tplink/EAPController/lib
COPY entrypoint.sh /opt/tplink/EAPController/
COPY properties /opt/tplink/EAPController/properties
COPY data /opt/tplink/EAPController/data

RUN chown -R omada:omada /opt/tplink/EAPController

WORKDIR /opt/tplink/EAPController/data

EXPOSE 29811/tcp 29812/tcp 29813/tcp 29814/tcp 8088/tcp 8043/tcp 8843/tcp 29810/udp 27001/udp 29816/tcp 27001/udp

ENV OMADA_MANAGE_HTTP_PORT 8088
ENV OMADA_MANAGE_HTTPS_PORT 8043
ENV OMADA_PORTAL_HTTP_PORT 8088
ENV OMADA_PORTAL_HTTPS_PORT 8843
ENV OMADA_PORT_DISCOVERY 29810
ENV OMADA_PORT_ADOPT_V1 29812
ENV OMADA_PORT_UPGRADE_V1 29813
ENV OMADA_PORT_MANAGER_V1 29811
ENV OMADA_PORT_MANAGER_V2 29814
ENV OMADA_PORT_RTTY 29816
ENV OMADA_PORT_APP_DISCOVERY 27001

USER omada

CMD [ "/opt/tplink/EAPController/entrypoint.sh" ]
