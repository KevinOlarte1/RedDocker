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
COPY scripts/crearPrediccionesHive.sql /opt/scripts/crearPrediccionesHive.sql
COPY scripts/consultasPredicciones.sql /opt/scripts/consultasPredicciones.sql
COPY scripts/crearPrediccionesHive.sh /crearPrediccionesHive.sh
COPY scripts/consultarPredicciones.sh /consultarPredicciones.sh

# Normalizar scripts creados desde Windows antes de ejecutarlos en Linux.
RUN sed -i 's/\r$//' \
      /migrarEjecutor.sh \
      /crearMetricasHive.sh \
      /consultarMetricasHistoricas.sh \
      /crearPrediccionesHive.sh \
      /consultarPredicciones.sh && \
    chmod +x \
      /migrarEjecutor.sh \
      /crearMetricasHive.sh \
      /consultarMetricasHistoricas.sh \
      /crearPrediccionesHive.sh \
      /consultarPredicciones.sh
