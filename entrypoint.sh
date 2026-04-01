#!/bin/sh

OMADA_HOME=/opt/tplink/EAPController/

printf "\n" >> "${OMADA_HOME}/properties/omada.properties"
echo "eap.mongod.uri=${MONGO_URL}" >> "${OMADA_HOME}/properties/omada.properties"

java \
    -server \
    -Xms128m -Xmx1024m \
    -XX:MaxHeapFreeRatio=60 \
    -XX:MinHeapFreeRatio=30 \
    -XX:+HeapDumpOnOutOfMemoryError \
    -Djava.awt.headless=true \
    -XX:HeapDumpPath=/opt/tplink/EAPController/logs/java_heapdump.hprof \
    -Deap.mongod.uri="${MONGO_URL}" \
    -Dspring.data.mongodb.uri="${MONGO_URL}" \
    -Dmanage.http.port="${OMADA_MANAGE_HTTP_PORT}" \
    -Dmanage.https.port="${OMADA_MANAGE_HTTPS_PORT}" \
    -Dportal.http.port="${OMADA_PORTAL_HTTP_PORT}" \
    -Dportal.https.port="${OMADA_PORTAL_HTTPS_PORT}" \
    -Dport.discovery="${OMADA_PORT_DISCOVERY}" \
    -Dport.adopt.v1="${OMADA_PORT_ADOPT_V1}" \
    -Dport.upgrade.v1="${OMADA_PORT_UPGRADE_V1}" \
    -Dport.manager.v1="${OMADA_PORT_MANAGER_V1}" \
    -Dport.manager.v2="${OMADA_PORT_MANAGER_V2}" \
    -Dport.rtty="${OMADA_PORT_RTTY}" \
    -Dport.app.discovery="${OMADA_PORT_APP_DISCOVERY}" \
    -Dmanagement.prometheus.metrics.export.enabled=false \
    -cp "/usr/share/java/commons-daemon.jar:${OMADA_HOME}/dependency/*:${OMADA_HOME}/lib/*:${OMADA_HOME}/properties" \
    com.tplink.smb.omada.starter.OmadaLinuxMain
