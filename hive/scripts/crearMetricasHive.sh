#!/bin/bash
set -e

echo "Creando tabla externa de metricas Prometheus..."
beeline -u jdbc:hive2://localhost:10000 -n hive -f /opt/scripts/crearMetricasHive.sql
echo "Tabla de metricas lista."
