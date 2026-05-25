FROM python:3.12-slim

WORKDIR /opt/metricas-exporter

COPY scripts/exportar_metricas.py /opt/metricas-exporter/exportar_metricas.py

ENTRYPOINT ["python", "/opt/metricas-exporter/exportar_metricas.py"]
