#!/bin/bash
set -e

echo "Descomprimiendo datos_plantas.zip..."

rm -rf /tmp/datos_plantas
unzip -o /datos_plantas.zip -d /tmp/datos_plantas

CSV_FILE=$(find /tmp/datos_plantas -name "generacion_energia.csv" | head -n 1)

echo "CSV encontrado: $CSV_FILE"

cp "$CSV_FILE" /var/lib/mysql-files/generacion_energia.csv
chmod 644 /var/lib/mysql-files/generacion_energia.csv

echo "Importando datos..."

mysql -uroot -p"$MYSQL_ROOT_PASSWORD" energiadb <<EOF
LOAD DATA INFILE '/var/lib/mysql-files/generacion_energia.csv'
INTO TABLE generacion_energia
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(fecha, consumo, generacion, hora_dia, idexcel);
EOF

echo "Importación completada."