FROM apache/hive:4.0.0

USER root

# Crear carpeta scripts dentro del contenedor
RUN mkdir -p /opt/scripts

# Copiar scripts
COPY scripts/migrarHDFS.sql /opt/scripts/migrarHDFS.sql
COPY scripts/migrarEjecutor.sh /migrarEjecutor.sh

# Dar permisos
RUN chmod +x /migrarEjecutor.sh