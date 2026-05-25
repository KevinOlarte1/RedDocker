#!/bin/bash
set -e

MOMENTO_CARGA="${MOMENTO_CARGA:-2026-05-24 00:00:00}"

echo "Consultando metricas historicas; momento de comparacion: ${MOMENTO_CARGA}"
beeline -u jdbc:hive2://localhost:10000 -n hive \
  --hiveconf momento_carga="${MOMENTO_CARGA}" \
  -f /opt/scripts/consultasMetricasHistoricas.sql
