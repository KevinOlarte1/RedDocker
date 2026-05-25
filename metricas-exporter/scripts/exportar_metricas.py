#!/usr/bin/env python3
"""Exporta metricas historicas de Prometheus a CSV en HDFS mediante WebHDFS."""

import argparse
import csv
import io
import json
import os
import sys
import time
from datetime import datetime, timezone
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode
from urllib.request import HTTPRedirectHandler, Request, build_opener, urlopen


PROMETHEUS_URL = os.getenv("PROMETHEUS_URL", "http://prometheus:9090").rstrip("/")
WEBHDFS_URL = os.getenv(
    "WEBHDFS_URL", "http://Nodo-principal:9870/webhdfs/v1"
).rstrip("/")
HDFS_BASE_PATH = os.getenv("HDFS_BASE_PATH", "/metricas/prometheus").rstrip("/")
WINDOW_SECONDS = int(os.getenv("EXPORT_WINDOW_SECONDS", "900"))
STEP_SECONDS = int(os.getenv("EXPORT_STEP_SECONDS", "60"))
INTERVAL_SECONDS = int(os.getenv("EXPORT_INTERVAL_SECONDS", "900"))
STARTUP_DELAY_SECONDS = int(os.getenv("EXPORT_STARTUP_DELAY_SECONDS", "10"))
RETRY_SECONDS = int(os.getenv("EXPORT_RETRY_SECONDS", "30"))
HDFS_USER = os.getenv("HDFS_USER", "root")
CONTAINERS = os.getenv(
    "EXPORT_CONTAINERS", "Nodo-principal|mysql-practica|hive|datos-1|datos-2"
)
SERVICE_LABEL = "container_label_com_docker_compose_service"

QUERIES = (
    (
        "memory_usage",
        "MiB",
        'sum by ({label}) (container_memory_usage_bytes{{{label}=~"{containers}"}})'
        " / 1048576",
    ),
    (
        "cpu_usage",
        "percent",
        'sum by ({label}) (rate(container_cpu_usage_seconds_total'
        '{{{label}=~"{containers}"}}[1m])) * 100',
    ),
)


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def utc_text(epoch_seconds):
    return datetime.fromtimestamp(epoch_seconds, timezone.utc).strftime(
        "%Y-%m-%d %H:%M:%S"
    )


def parse_time(value):
    value = value.replace("Z", "+00:00")
    parsed = datetime.fromisoformat(value)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return int(parsed.timestamp())


def last_completed_window(window_seconds):
    end = int(time.time()) // window_seconds * window_seconds
    return end - window_seconds, end


def get_json(url):
    with urlopen(url, timeout=20) as response:
        return json.loads(response.read().decode("utf-8"))


def query_prometheus(query, start, end, step):
    params = urlencode(
        {
            "query": query,
            "start": start,
            "end": end - 0.001,
            "step": step,
        }
    )
    payload = get_json(f"{PROMETHEUS_URL}/api/v1/query_range?{params}")
    if payload.get("status") != "success":
        raise RuntimeError(f"Prometheus devolvio un error: {payload}")
    return payload["data"]["result"]


def build_csv(start, end, step):
    rows = []
    for metric_name, unit, template in QUERIES:
        query = template.format(label=SERVICE_LABEL, containers=CONTAINERS)
        for series in query_prometheus(query, start, end, step):
            container = series.get("metric", {}).get(SERVICE_LABEL, "desconocido")
            for timestamp, value in series.get("values", []):
                rows.append((int(float(timestamp)), container, metric_name, value, unit))

    rows.sort(key=lambda row: (row[0], row[2], row[1]))
    content = io.StringIO(newline="")
    writer = csv.writer(content, lineterminator="\n")
    for timestamp, container, metric_name, value, unit in rows:
        writer.writerow((utc_text(timestamp), container, metric_name, value, unit))
    return rows, content.getvalue().encode("utf-8")


def webhdfs_url(path, operation, **params):
    query = {"op": operation, "user.name": HDFS_USER}
    query.update(params)
    return f"{WEBHDFS_URL}{quote(path, safe='/')}?{urlencode(query)}"


def ensure_hdfs_directory(path):
    request = Request(webhdfs_url(path, "MKDIRS"), method="PUT")
    with urlopen(request, timeout=20) as response:
        result = json.loads(response.read().decode("utf-8"))
    if not result.get("boolean"):
        raise RuntimeError(f"No se pudo crear el directorio HDFS {path}")


def hdfs_file_exists(path):
    try:
        with urlopen(webhdfs_url(path, "GETFILESTATUS"), timeout=20):
            return True
    except HTTPError as error:
        if error.code == 404:
            return False
        raise


def write_hdfs_file(path, data):
    initial = Request(webhdfs_url(path, "CREATE", overwrite="false"), method="PUT")
    opener = build_opener(NoRedirect)
    try:
        response = opener.open(initial, timeout=20)
        location = response.headers.get("Location")
        response.close()
    except HTTPError as error:
        if error.code not in (307, 308):
            raise
        location = error.headers.get("Location")

    if not location:
        raise RuntimeError("WebHDFS no devolvio ubicacion de escritura para el fichero")

    request = Request(
        location,
        data=data,
        method="PUT",
        headers={"Content-Type": "text/csv; charset=utf-8"},
    )
    with urlopen(request, timeout=30) as response:
        if response.status not in (200, 201):
            raise RuntimeError(f"Error escribiendo HDFS: HTTP {response.status}")


def export_window(start, end, step):
    filename = (
        f"metricas_{datetime.fromtimestamp(start, timezone.utc):%Y%m%dT%H%M%SZ}_"
        f"{datetime.fromtimestamp(end, timezone.utc):%Y%m%dT%H%M%SZ}.csv"
    )
    hdfs_path = f"{HDFS_BASE_PATH}/{filename}"
    ensure_hdfs_directory(HDFS_BASE_PATH)
    if hdfs_file_exists(hdfs_path):
        print(f"Ventana ya exportada: {hdfs_path}", flush=True)
        return True

    rows, csv_bytes = build_csv(start, end, step)
    if not rows:
        print(
            f"Sin muestras para {utc_text(start)} - {utc_text(end)}; se reintentara.",
            flush=True,
        )
        return False
    write_hdfs_file(hdfs_path, csv_bytes)
    print(
        f"Exportadas {len(rows)} filas ({utc_text(start)} - {utc_text(end)}) a {hdfs_path}",
        flush=True,
    )
    return True


def run_once(args):
    if args.start or args.end:
        if not args.start or not args.end:
            raise ValueError("Debe indicar --start y --end conjuntamente")
        start, end = parse_time(args.start), parse_time(args.end)
    else:
        start, end = last_completed_window(args.window_seconds)
    if end <= start:
        raise ValueError("El final del intervalo debe ser posterior al inicio")
    return export_window(start, end, args.step_seconds)


def run_loop(args):
    if STARTUP_DELAY_SECONDS:
        print(
            f"Esperando {STARTUP_DELAY_SECONDS}s antes de iniciar la exportacion.",
            flush=True,
        )
        time.sleep(STARTUP_DELAY_SECONDS)
    while True:
        try:
            succeeded = run_once(args)
        except (HTTPError, URLError, RuntimeError, ValueError) as error:
            print(f"Exportacion fallida: {error}", file=sys.stderr, flush=True)
            succeeded = False
        time.sleep(args.interval_seconds if succeeded else RETRY_SECONDS)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true", help="Exporta una unica ventana")
    parser.add_argument("--start", help="Inicio ISO UTC, por ejemplo 2026-05-24T10:00:00Z")
    parser.add_argument("--end", help="Fin ISO UTC, por ejemplo 2026-05-24T10:15:00Z")
    parser.add_argument("--window-seconds", type=int, default=WINDOW_SECONDS)
    parser.add_argument("--step-seconds", type=int, default=STEP_SECONDS)
    parser.add_argument("--interval-seconds", type=int, default=INTERVAL_SECONDS)
    args = parser.parse_args()
    try:
        if args.once:
            return 0 if run_once(args) else 1
        run_loop(args)
    except (HTTPError, URLError, RuntimeError, ValueError) as error:
        print(f"Exportacion fallida: {error}", file=sys.stderr, flush=True)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
