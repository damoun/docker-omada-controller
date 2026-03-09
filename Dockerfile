FROM maven:3.9-eclipse-temurin-17@sha256:a0603aab698040d9c94259f379ec0487da1678560748d6c7508483034033c53d as build

COPY pom.xml .

RUN mvn dependency:copy-dependencies
RUN mvn dependency:tree

FROM eclipse-temurin:17-jre-jammy@sha256:1dd80d55af5f5ddb9cbd0b119f5a396058aa34909ee6abea601ac8cd5b09487a

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
