CREATE DATABASE IF NOT EXISTS metricas_hive;
USE metricas_hive;

CREATE EXTERNAL TABLE IF NOT EXISTS predicciones_cpu (
  generado_en TIMESTAMP,
  instante_prediccion TIMESTAMP,
  contenedor STRING,
  metrica STRING,
  valor_predicho DOUBLE,
  unidad STRING,
  modelo STRING,
  pendiente_pct_min DOUBLE
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 'hdfs://Nodo-principal:9000/metricas/predicciones_cpu/';

SELECT COUNT(*) AS total_predicciones FROM predicciones_cpu;
SELECT * FROM predicciones_cpu LIMIT 10;
