CREATE DATABASE IF NOT EXISTS metricas_hive;
USE metricas_hive;

CREATE EXTERNAL TABLE IF NOT EXISTS metricas_contenedores (
  instante TIMESTAMP,
  contenedor STRING,
  metrica STRING,
  valor DOUBLE,
  unidad STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 'hdfs://Nodo-principal:9000/metricas/prometheus/';

SELECT COUNT(*) AS total_metricas FROM metricas_contenedores;
SELECT * FROM metricas_contenedores LIMIT 10;
