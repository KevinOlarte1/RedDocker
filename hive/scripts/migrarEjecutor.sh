#!/bin/bash

echo "Ejecutando consulta Hive mirarHDFS.sql..."

beeline -u jdbc:hive2://localhost:10000 -n hive -f /opt/scripts/migrarHDFS.sql

echo "Consulta finalizada."
