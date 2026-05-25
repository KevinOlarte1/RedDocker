FROM r-base:4.4.3

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/* && \
    R -e "install.packages('jsonlite', repos='https://cloud.r-project.org')"

WORKDIR /opt/prediccion-r

COPY scripts/predecir_cpu.R /opt/prediccion-r/predecir_cpu.R

ENTRYPOINT ["Rscript", "/opt/prediccion-r/predecir_cpu.R"]
