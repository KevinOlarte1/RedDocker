#!/bin/bash
set -e

echo "Limpiando destino anterior..."
hdfs dfs -rm -r -f /sqoop/energiadb/generacion_energia || true

echo "Generando clase Java con Sqoop..."
rm -rf /tmp/sqoop-generacion
mkdir -p /tmp/sqoop-generacion

sqoop codegen \
--connect jdbc:mysql://mysql-practica:3306/energiadb \
--username root \
--password root1234 \
--table generacion_energia \
--class-name GeneracionEnergia \
--bindir /tmp/sqoop-generacion

echo "Importando datos MySQL -> HDFS con Sqoop..."

sqoop import \
-D mapreduce.job.classloader=true \
-libjars /tmp/sqoop-generacion/GeneracionEnergia.jar \
--connect jdbc:mysql://mysql-practica:3306/energiadb \
--username root \
--password root1234 \
--table generacion_energia \
--target-dir /sqoop/energiadb/generacion_energia \
--num-mappers 2 \
--split-by id \
--fields-terminated-by "," \
--class-name GeneracionEnergia \
--jar-file /tmp/sqoop-generacion/GeneracionEnergia.jar

echo "Importación finalizada."
hdfs dfs -ls /sqoop/energiadb/generacion_energia
hdfs dfs -cat /sqoop/energiadb/generacion_energia/part-m-* | head