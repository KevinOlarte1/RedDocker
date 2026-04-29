FROM bde2020/hadoop-namenode:2.0.0-hadoop3.2.1-java8

USER root

# 1. Usar el comando ADD nativo de Docker para descargar Sqoop (sin usar wget)
ADD http://archive.apache.org/dist/sqoop/1.4.7/sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz /tmp/sqoop.tar.gz

# 2. Descomprimir la carpeta y colocarla en su sitio
RUN tar -xvf /tmp/sqoop.tar.gz -C /usr/local/ && \
    mv /usr/local/sqoop-1.4.7.bin__hadoop-2.6.0 /usr/local/sqoop && \
    rm /tmp/sqoop.tar.gz

# 3. Usar ADD para descargar e inyectar las librerías directamente en su carpeta final
ADD https://repo1.maven.org/maven2/commons-lang/commons-lang/2.6/commons-lang-2.6.jar /usr/local/sqoop/lib/commons-lang-2.6.jar
ADD https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar /usr/local/sqoop/lib/mysql-connector-java-8.0.28.jar

# 4. Configurar las variables de entorno para siempre
ENV PATH=$PATH:/usr/local/sqoop/bin
ENV HADOOP_CLASSPATH="/usr/local/sqoop/lib/*"

COPY start-hadoop.sh /start-hadoop.sh
RUN chmod +x /start-hadoop.sh

CMD ["/start-hadoop.sh"]
