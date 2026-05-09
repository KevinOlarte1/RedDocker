# 🐳 RedDocker — Arquitectura Big Data Distribuida con Docker

> Práctica universitaria de Big Data: pipeline ETL completo sobre un clúster Hadoop distribuido, orquestado con Docker Compose.

---

## 📋 Índice

1. [Introducción](#-introducción)
2. [Arquitectura del sistema](#-arquitectura-del-sistema)
3. [Tecnologías y versiones](#-tecnologías-y-versiones)
4. [Estructura del proyecto](#-estructura-del-proyecto)
5. [Puesta en marcha](#-puesta-en-marcha)
6. [Configuración inicial paso a paso](#-configuración-inicial-paso-a-paso)
   - [Paso 1 — Preparar MySQL](#paso-1--preparar-mysql)
   - [Paso 2 — Importar MySQL → HDFS con Sqoop](#paso-2--importar-mysql--hdfs-con-sqoop)
   - [Paso 3 — Importar HDFS → Hive](#paso-3--importar-hdfs--hive)
7. [Replicación HDFS](#-replicación-hdfs)
8. [Monitorización con Prometheus y Grafana](#-monitorización-con-prometheus-y-grafana)
9. [Consultas Hive](#-consultas-hive)
10. [Conclusión](#-conclusión)

---

## 📖 Introducción

**RedDocker** es una práctica de Big Data cuyo objetivo es simular un entorno distribuido de procesamiento de datos energéticos, reproduciendo en local una arquitectura de producción real mediante contenedores Docker.

### Objetivo

El proyecto implementa un pipeline **ETL** (Extract, Transform, Load) completo sobre datos de generación energética de plantas eléctricas. Todo el ecosistema corre sobre una red Docker aislada (`red-docker`), eliminando la necesidad de instalar software de Big Data en la máquina anfitriona.

### Flujo ETL

```
┌─────────┐    Sqoop    ┌──────┐    Hive     ┌──────┐
│  MySQL  │ ──────────► │ HDFS │ ──────────► │ Hive │
│  (raw)  │   import    │      │   external  │      │
└─────────┘             └──────┘    table    └──────┘
```

| Etapa | Herramienta | Descripción |
|-------|-------------|-------------|
| **Extract** | MySQL 8 | Almacena los datos energéticos en tablas relacionales |
| **Transfer** | Sqoop 1.4.7 | Importa los datos desde MySQL hacia HDFS en formato de texto |
| **Load** | Hive 4.0.0 | Crea una tabla externa sobre los datos HDFS para consultarlos con HiveQL |

### ¿Por qué Docker?

Docker Compose permite levantar todos los servicios (Hadoop, Hive, MySQL, Sqoop, Prometheus, Grafana) con un único comando, garantizando reproducibilidad, aislamiento de red y configuración declarativa del clúster.

---

## 🏗️ Arquitectura del sistema

El clúster está compuesto por **10 contenedores** distribuidos en una red bridge personalizada (`red-docker`):

### Diagrama de arquitectura

```
                        ┌─────────────────────────────────────────────────┐
                        │                  red-docker                     │
                        │                                                 │
  ┌──────────────┐      │   ┌─────────────────┐    ┌──────────────────┐  │
  │    Cliente   │      │   │  Nodo-principal  │    │   mysql-practica │  │
  │  (navegador) │──────┼──►│  NameNode        │    │   MySQL 8.0      │  │
  └──────────────┘      │   │  ResourceManager │◄───│   puerto 3306    │  │
                        │   │  Sqoop 1.4.7     │    └──────────────────┘  │
                        │   │  puerto 9870     │                          │
                        │   │  puerto 8088     │                          │
                        │   └────────┬─────────┘                         │
                        │            │ HDFS replication=2                 │
                        │     ┌──────┴──────┐                            │
                        │     ▼             ▼                            │
                        │  ┌───────┐   ┌───────┐                        │
                        │  │datos-1│   │datos-2│                        │
                        │  │DataN. │   │DataN. │                        │
                        │  └───────┘   └───────┘                        │
                        │                                                 │
                        │   ┌──────┐  ┌──────────┐  ┌─────────┐        │
                        │   │ hive │  │prometheus│  │ grafana │        │
                        │   │10000 │  │  :9090   │  │  :3000  │        │
                        │   └──────┘  └──────────┘  └─────────┘        │
                        └─────────────────────────────────────────────────┘
```

### Descripción de contenedores

| Contenedor | Imagen base | Rol | Puertos expuestos |
|---|---|---|---|
| `Nodo-principal` | `bde2020/hadoop-namenode:2.0.0-hadoop3.2.1-java8` + Sqoop | **NameNode** + **ResourceManager** + **Sqoop** | `50070`, `8088`, `9000` |
| `datos-1` | `bde2020/hadoop-datanode:2.0.0-hadoop3.2.1-java8` | **DataNode #1** — almacena bloques HDFS | — |
| `datos-2` | `bde2020/hadoop-datanode:2.0.0-hadoop3.2.1-java8` | **DataNode #2** — almacena bloques HDFS | — |
| `mysql-practica` | `mysql:8.0` + Python 3 | **Base de datos relacional** con datos energéticos | `3306` |
| `hive` | `apache/hive:4.0.0` | **HiveServer2** — consultas HiveQL sobre HDFS | `10000`, `10002` |
| `prometheus` | `prom/prometheus` | **Recolección de métricas** del clúster | `9090` |
| `grafana` | `grafana/grafana` | **Visualización de métricas** en dashboards | `3000` |
| `node-exporter` | `prom/node-exporter` | **Métricas del sistema** (CPU, RAM, disco) | `9100` |
| `cadvisor` | `gcr.io/cadvisor/cadvisor` | **Métricas de contenedores** Docker | `8089` |

### Detalle de los Dockerfiles personalizados

**`hadoop-sqoop/Dockerfile`** — Extiende la imagen oficial de Hadoop NameNode añadiendo:
- Sqoop 1.4.7 descargado desde el archivo oficial de Apache
- Librería `commons-lang-2.6.jar` y `mysql-connector-java-8.0.28.jar` para compatibilidad
- Variables de entorno `SQOOP_HOME` y `HADOOP_CLASSPATH` configuradas permanentemente
- Scripts `start-hadoop.sh` e `importarMYSQL.sh` embebidos en la imagen

**`mysql/Dockerfile`** — Extiende MySQL 8.0 añadiendo:
- Python 3 + `mysql-connector-python` para el generador de datos aleatorios
- Script SQL de inicialización (`init-db.sql`) ejecutado automáticamente al arrancar
- Scripts de carga (`02-load-data.sh`) y generación de datos (`generar_dades.py`)

**`hive/Dockerfile`** — Extiende la imagen oficial de Apache Hive 4.0.0 añadiendo:
- Scripts de migración (`migrarEjecutor.sh`, `migrarHDFS.sql`) copiados a `/opt/scripts/` y `/`

---

## 🛠️ Tecnologías y versiones

| Tecnología | Versión | Función en el proyecto |
|---|---|---|
| **Apache Hadoop** | 3.2.1 | Sistema de ficheros distribuido (HDFS) y gestión de recursos (YARN) |
| **Apache Hive** | 4.0.0 | Motor SQL sobre HDFS — consultas analíticas |
| **Apache Sqoop** | 1.4.7 | Importación de datos relacionales a HDFS |
| **MySQL** | 8.0 | Base de datos origen con datos energéticos |
| **Prometheus** | latest | Recolección y almacenamiento de métricas |
| **Grafana** | latest | Visualización de métricas en tiempo real |
| **Docker** | ≥ 24.x | Motor de contenedores |
| **Docker Compose** | ≥ 2.x | Orquestación declarativa del clúster |
| **Python** | 3.x | Generación de datos de prueba aleatorios |
| **Java** | 8 | Runtime para Hadoop, Hive y Sqoop |

---

## 📁 Estructura del proyecto

```
RedDocker/
├── docker-compose.yml              # Orquestación de todos los servicios
│
├── hadoop-sqoop/                   # Nodo principal del clúster
│   ├── Dockerfile                  # NameNode + Sqoop personalizado
│   └── scripts/
│       ├── start-hadoop.sh         # Script de arranque de Hadoop
│       └── importarMYSQL.sh        # Pipeline Sqoop: MySQL → HDFS
│
├── hive/                           # Servicio HiveServer2
│   ├── Dockerfile                  # Imagen Hive personalizada
│   ├── lib/
│   │   └── mysql-connector-java-8.0.28.jar
│   └── scripts/
│       ├── migrarEjecutor.sh       # Orquestador de la migración HDFS → Hive
│       └── migrarHDFS.sql          # DDL y consultas HiveQL
│
├── mysql/                          # Base de datos relacional origen
│   ├── Dockerfile                  # MySQL 8 + Python 3
│   ├── datos_plantas.zip           # Dataset energético comprimido
│   └── scripts/
│       ├── init-db.sql             # Esquema inicial de la base de datos
│       ├── 02-load-data.sh         # Script de carga de datos
│       └── generar_dades.py        # Generador de registros aleatorios
│
├── prometheus/
│   └── prometheus.yml              # Configuración de scraping de métricas
│
└── README.md
```

---

## 🚀 Puesta en marcha

### Prerrequisitos

Asegúrate de tener instalados:

```bash
docker --version        # Docker ≥ 24.x
docker compose version  # Docker Compose ≥ 2.x
```

### Clonar el repositorio

```bash
git clone https://github.com/<usuario>/RedDocker.git
cd RedDocker
```

### Levantar el clúster

```bash
docker compose up -d
```

Este comando construye las imágenes personalizadas (si no existen) y levanta los **10 contenedores** en background. La primera vez puede tardar varios minutos debido a la descarga de Sqoop y sus dependencias.

### Verificar que todos los contenedores están activos

```bash
docker compose ps
```

Todos los servicios deben aparecer con estado `running`. Puedes acceder a las interfaces web en:

| Interfaz | URL |
|---|---|
| Hadoop NameNode UI | http://localhost:50070 |
| YARN ResourceManager | http://localhost:8088 |
| Grafana | http://localhost:3000 |
| Prometheus | http://localhost:9090 |
| HiveServer2 | `localhost:10000` (JDBC) |
| Mysql | `localhost:3306` (JDBC) |

---

## ⚙️ Configuración inicial paso a paso

> ⚠️ **Importante:** Los tres pasos siguientes deben ejecutarse **en orden** y solo la primera vez que se levanta el clúster, o después de eliminar los volúmenes con `docker compose down -v`. El unico que se debe ejecutar cada vez que se lanza es el /migrarEjecutor.sh de hive

---

### Paso 1 — Preparar MySQL

Este paso inicializa la base de datos `energiadb` con su esquema y carga los datos de generación energética.

**1.1 — Acceder al contenedor MySQL:**

```bash
docker exec -it mysql-practica bash
```

> ℹ️ El esquema de la base de datos (`init-db.sql`) se ejecuta automáticamente en el primer arranque del contenedor. No es necesario ejecutarlo manualmente.

**1.2 — Cargar los datos iniciales:**

```bash
bash /02-load-data.sh
```

Este script lee el dataset de plantas eléctricas (`datos_plantas.zip`) e inserta los registros en la tabla `generacion_energia`.

**1.3 — (Opcional) Generar registros aleatorios adicionales:**

```bash
python3 /generar_dades.py
```

Este script Python genera **100 registros adicionales** con valores aleatorios de producción energética, útiles para probar el pipeline con mayor volumen de datos.

**1.4 — Verificar los datos insertados:**

```sql
mysql -u alumne -palumne1234 energiadb
SELECT COUNT(*) FROM generacion_energia;
EXIT;
```

**1.5 — Salir del contenedor:**

```bash
exit
```

---

### Paso 2 — Importar MySQL → HDFS con Sqoop

Este paso transfiere los datos desde MySQL hacia el sistema de ficheros distribuido HDFS, utilizando Sqoop como conector.

**2.1 — Acceder al contenedor Nodo-principal:**

```bash
docker exec -it Nodo-principal bash
```

**2.2 — Ejecutar el script de importación:**

```bash
bash /importarMYSQL.sh
```

El script `importarMYSQL.sh` realiza automáticamente las siguientes operaciones:

| Paso interno | Acción |
|---|---|
| 🗑️ **Limpieza** | Elimina datos previos en la ruta HDFS destino si existen |
| ☕ **Generación Java** | Sqoop genera clases Java para mapear la tabla MySQL |
| 📥 **Importación** | Transfiere todos los registros a HDFS en formato CSV |
| ✅ **Verificación** | Comprueba bloques replicados y estado del sistema de ficheros |

Los datos quedan almacenados en HDFS en la ruta:

```
/sqoop/energiadb/generacion_energia/
```

**2.3 — Verificar la importación:**

```bash
hdfs dfs -ls /sqoop/energiadb/generacion_energia/
hdfs dfs -cat /sqoop/energiadb/generacion_energia/part-m-00000 | head -20
```

**2.4 — Salir del contenedor:**

```bash
exit
```

---

### Paso 3 — Importar HDFS → Hive

Este paso conecta Hive con los datos almacenados en HDFS, creando una tabla externa que permite lanzar consultas HiveQL directamente sobre los ficheros.

**3.1 — Acceder al contenedor Hive:**

```bash
docker exec -it hive bash
```

**3.2 — Ejecutar el script de migración:**

```bash
bash /migrarEjecutor.sh
```

El script `migrarEjecutor.sh` orquesta las siguientes operaciones (definidas en `migrarHDFS.sql`):

| Operación | Descripción |
|---|---|
| 🗄️ **Crear base de datos** | `CREATE DATABASE IF NOT EXISTS energiadb` en el metastore de Hive |
| 📋 **Crear tabla externa** | `CREATE EXTERNAL TABLE` apuntando a la ruta HDFS de Sqoop |
| 🔗 **Vincular con HDFS** | La tabla externa no mueve datos; lee directamente desde `/sqoop/energiadb/generacion_energia/` |
| 🔍 **Consultas de prueba** | Ejecuta `SELECT COUNT(*)` y `SELECT * LIMIT 10` para validar la integración |

> ℹ️ **Tabla EXTERNAL vs MANAGED:** Se usa una tabla `EXTERNAL` para que Hive no gestione el ciclo de vida de los datos. Si se eliminara la tabla en Hive, los ficheros en HDFS permanecerían intactos.

**3.3 — Salir del contenedor:**

```bash
exit
```

---

## 📊 Replicación HDFS

El clúster está configurado con un **factor de replicación de 2** (`dfs.replication=2`), lo que significa que cada bloque de datos importado por Sqoop se almacena en dos DataNodes simultáneamente (`datos-1` y `datos-2`). Esto garantiza tolerancia a fallos: si un DataNode cae, los datos siguen accesibles desde el otro.

### Verificar el estado del clúster

Desde dentro del contenedor `Nodo-principal`:

```bash
docker exec -it Nodo-principal bash
```

**Informe general del clúster:**

```bash
hdfs dfsadmin -report
```

La salida muestra el estado de cada DataNode, el espacio disponible, bloques configurados y bloques corruptos.

**Inspección de bloques de un path concreto:**

```bash
hdfs fsck /sqoop/energiadb/generacion_energia -files -blocks -locations
```

La salida debe mostrar algo similar a:

```
/sqoop/energiadb/generacion_energia/part-m-00000:
  Under replicated blocks: 0
  Blocks with corrupt replicas: 0
  Missing blocks: 0

Status: HEALTHY
 Total size: XXXXX B
 Total dirs: 1
 Total files: 1
 Total blocks (validated): 1 (avg. block size XXXXX B)
 Minimally replicated blocks: 1 (100.0 %)
 Over-replicated blocks: 0 (0.0 %)
 Under-replicated blocks: 0 (0.0 %)
 Mis-replicated blocks: 0 (0.0 %)
 Default replication factor: 2
 Average block replication: 2.0
```

---

## 📈 Monitorización con Prometheus y Grafana

El clúster incluye una capa de observabilidad completa para monitorizar el rendimiento en tiempo real.

### Componentes de monitorización

| Servicio | Función | URL |
|---|---|---|
| **Prometheus** | Recolecta métricas de todos los exporters | http://localhost:9090 |
| **Grafana** | Visualiza métricas en dashboards interactivos | http://localhost:3000 |
| **Node Exporter** | Métricas del sistema host (CPU, RAM, disco, red) | http://localhost:9100/metrics |
| **cAdvisor** | Métricas individuales de cada contenedor Docker | http://localhost:8089 |

### Acceder a Grafana

1. Abrir http://localhost:3000 en el navegador
2. Credenciales por defecto: `admin` / `admin`
3. Configurar Prometheus como datasource: `http://prometheus:9090`
4. Importar dashboards para Hadoop, Docker o Node Exporter desde [grafana.com/dashboards](https://grafana.com/grafana/dashboards/)

---

## 🔍 Consultas Hive

Una vez completada la migración, se pueden lanzar consultas HiveQL desde dentro del contenedor `hive`:

```bash
docker exec -it hive bash
beeline -u jdbc:hive2://localhost:10000
```

### Consultas de ejemplo

**Ver los primeros 10 registros:**

```sql
SELECT * FROM energiadb.generacion_energia_mysql LIMIT 10;
```

**Contar el total de registros importados:**

```sql
SELECT COUNT(*) FROM energiadb.generacion_energia_mysql;
```

**Producción total por planta:**

```sql
SELECT id_planta, SUM(produccion_kwh) AS total_produccion
FROM energiadb.generacion_energia_mysql
GROUP BY id_planta
ORDER BY total_produccion DESC;
```

**Filtrar por rango de fechas:**

```sql
SELECT *
FROM energiadb.generacion_energia_mysql
WHERE fecha BETWEEN '2024-01-01' AND '2024-12-31'
ORDER BY fecha;
```

**Producción media por tipo de energía:**

```sql
SELECT tipo_energia, AVG(produccion_kwh) AS media_produccion
FROM energiadb.generacion_energia_mysql
GROUP BY tipo_energia;
```

---

## 🧹 Comandos útiles

### Parar el clúster

```bash
docker compose down
```

### Parar y eliminar volúmenes (reset completo)

```bash
docker compose down -v
```

> ⚠️ Esto eliminará todos los datos persistentes (MySQL, HDFS NameNode, Prometheus, Grafana). Será necesario repetir los 3 pasos de configuración inicial.

### Ver logs de un servicio

```bash
docker compose logs -f Nodo-principal
docker compose logs -f hive
docker compose logs -f mysql-practica
```

### Reconstruir imágenes tras modificar un Dockerfile

```bash
docker compose build --no-cache
docker compose up -d
```

---

## 🎓 Conclusión

RedDocker demuestra cómo construir un entorno de Big Data distribuido completamente funcional usando exclusivamente contenedores Docker. A lo largo de la práctica se trabajan los siguientes conceptos clave:

| Concepto | Lo que se aprende |
|---|---|
| **HDFS** | Sistema de ficheros distribuido: bloques, NameNode, DataNodes |
| **Replicación** | Tolerancia a fallos con factor de replicación 2 |
| **Sqoop** | Importación masiva desde bases de datos relacionales a HDFS |
| **Hive** | Consultas analíticas SQL sobre datos no estructurados en HDFS |
| **Pipeline ETL** | Diseño y ejecución de un flujo Extract → Transfer → Load real |
| **Docker distribuido** | Orquestación de múltiples servicios con Docker Compose y redes bridge |
| **Monitorización** | Observabilidad del clúster con Prometheus + Grafana |
| **Procesamiento Big Data** | Separación entre almacenamiento (HDFS), procesamiento (YARN) y consulta (Hive) |

Esta arquitectura replica en miniatura los patrones que se usan en clústeres Hadoop en producción, proporcionando una base sólida para comprender el ecosistema Hadoop y los principios del procesamiento distribuido de grandes volúmenes de datos.

---

<div align="center">

**RedDocker** · Práctica Big Data · Docker + Hadoop + Hive + Sqoop

</div>
