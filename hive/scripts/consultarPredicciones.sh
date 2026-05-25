#!/bin/bash
set -e

echo "Consultando predicciones CPU y tendencias futuras..."
beeline -u jdbc:hive2://localhost:10000 -n hive -f /opt/scripts/consultasPredicciones.sql
