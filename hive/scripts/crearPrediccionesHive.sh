#!/bin/bash
set -e

echo "Creando tabla externa de predicciones CPU..."
beeline -u jdbc:hive2://localhost:10000 -n hive -f /opt/scripts/crearPrediccionesHive.sql
echo "Tabla de predicciones lista."
