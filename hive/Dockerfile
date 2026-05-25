FROM apache/hive:4.0.0

USER root

# Crear carpeta scripts dentro del contenedor
RUN mkdir -p /opt/scripts

# Copiar scripts
COPY scripts/migrarHDFS.sql /opt/scripts/migrarHDFS.sql
COPY scripts/migrarEjecutor.sh /migrarEjecutor.sh
COPY scripts/crearMetricasHive.sql /opt/scripts/crearMetricasHive.sql
COPY scripts/consultasMetricasHistoricas.sql /opt/scripts/consultasMetricasHistoricas.sql
COPY scripts/crearMetricasHive.sh /crearMetricasHive.sh
COPY scripts/consultarMetricasHistoricas.sh /consultarMetricasHistoricas.sh

# Dar permisos
RUN chmod +x /migrarEjecutor.sh
RUN chmod +x /crearMetricasHive.sh /consultarMetricasHistoricas.sh
