FROM mysql:8.0

ENV MYSQL_ROOT_PASSWORD=root1234

RUN microdnf install -y unzip && microdnf clean all

COPY scripts/init-db.sql /docker-entrypoint-initdb.d/
COPY datos_plantas.zip /datos_plantas.zip
COPY scripts/02-load-data.sh /02-load-data.sh

RUN chmod +x /02-load-data.sh