CREATE DATABASE IF NOT EXISTS energiadb;

USE energiadb;

CREATE TABLE IF NOT EXISTS generacion_energia (
    id INT AUTO_INCREMENT PRIMARY KEY,
    fecha DATETIME,
    consumo DECIMAL(10,3),
    generacion DECIMAL(10,3),
    hora_dia INT,
    idexcel INT
);