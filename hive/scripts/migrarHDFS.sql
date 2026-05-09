CREATE DATABASE IF NOT EXISTS energiadb_hive;
USE energiadb_hive;

CREATE EXTERNAL TABLE IF NOT EXISTS generacion_energia_mysql (
  consumo DECIMAL(10,3),
  fecha TIMESTAMP,
  generacion DECIMAL(10,3),
  hora_dia INT,
  id INT,
  idexcel INT
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 'hdfs://Nodo-principal:9000/sqoop/energiadb/generacion_energia';

SHOW TABLES;

SELECT * FROM generacion_energia_mysql LIMIT 10;

SELECT COUNT(*) AS total_registres
FROM generacion_energia_mysql;