FROM mysql:8.0

ENV MYSQL_ROOT_PASSWORD=root1234

RUN microdnf install -y python3 python3-pip unzip && \
    microdnf clean all && \
    pip3 install mysql-connector-python

COPY scripts/init-db.sql /docker-entrypoint-initdb.d/
COPY datos_plantas.zip /datos_plantas.zip
COPY scripts/02-load-data.sh /02-load-data.sh
COPY scripts/generar_dades.py /generar_dades.py

RUN chmod +x /02-load-data.sh
RUN chmod +x /generar_dades.py