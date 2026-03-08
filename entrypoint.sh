#!/bin/sh

OMADA_HOME=/opt/tplink/EAPController
PROPS_DIR=/tmp/properties

mkdir -p "${PROPS_DIR}"
cp "${OMADA_HOME}/properties/omada.properties" "${PROPS_DIR}/omada.properties"

echo "eap.mongod.uri=${MONGO_URL}" >> "${PROPS_DIR}/omada.properties"
echo "manage.http.port=${OMADA_MANAGE_HTTP_PORT}" >> "${PROPS_DIR}/omada.properties"
echo "manage.https.port=${OMADA_MANAGE_HTTPS_PORT}" >> "${PROPS_DIR}/omada.properties"
echo "portal.http.port=${OMADA_PORTAL_HTTP_PORT}" >> "${PROPS_DIR}/omada.properties"
echo "portal.https.port=${OMADA_PORTAL_HTTPS_PORT}" >> "${PROPS_DIR}/omada.properties"
echo "port.discovery=${OMADA_PORT_DISCOVERY}" >> "${PROPS_DIR}/omada.properties"
echo "port.adopt.v1=${OMADA_PORT_ADOPT_V1}" >> "${PROPS_DIR}/omada.properties"
echo "port.upgrade.v1=${OMADA_PORT_UPGRADE_V1}" >> "${PROPS_DIR}/omada.properties"
echo "port.manager.v1=${OMADA_PORT_MANAGER_V1}" >> "${PROPS_DIR}/omada.properties"
echo "port.manager.v2=${OMADA_PORT_MANAGER_V2}" >> "${PROPS_DIR}/omada.properties"
echo "port.rtty=${OMADA_PORT_RTTY}" >> "${PROPS_DIR}/omada.properties"
echo "port.app.discovery=${OMADA_PORT_APP_DISCOVERY}" >> "${PROPS_DIR}/omada.properties"

java \
    -server \
    -Xms128m -Xmx1024m \
    -XX:MaxHeapFreeRatio=60 \
    -XX:MinHeapFreeRatio=30 \
    -XX:+HeapDumpOnOutOfMemoryError \
    -Djava.awt.headless=true \
    -XX:HeapDumpPath=/opt/tplink/EAPController/logs/java_heapdump.hprof \
    -cp "/usr/share/java/commons-daemon.jar:${OMADA_HOME}/dependency/*:${OMADA_HOME}/lib/*:${PROPS_DIR}" \
    com.tplink.smb.omada.starter.OmadaLinuxMain
