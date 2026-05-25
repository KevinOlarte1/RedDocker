USE metricas_hive;

WITH ultima_ejecucion AS (
  SELECT MAX(generado_en) AS generado_en
  FROM predicciones_cpu
)
SELECT
  p.contenedor,
  ROUND(MIN(p.valor_predicho), 3) AS cpu_min_predicha,
  ROUND(AVG(p.valor_predicho), 3) AS cpu_media_predicha,
  ROUND(MAX(p.valor_predicho), 3) AS cpu_max_predicha
FROM predicciones_cpu p
JOIN ultima_ejecucion u ON p.generado_en = u.generado_en
GROUP BY p.contenedor
ORDER BY cpu_max_predicha DESC;

WITH ultima_ejecucion AS (
  SELECT MAX(generado_en) AS generado_en
  FROM predicciones_cpu
)
SELECT
  p.contenedor,
  ROUND(MAX(p.pendiente_pct_min), 5) AS variacion_cpu_por_minuto,
  CASE
    WHEN MAX(p.pendiente_pct_min) > 0.01 THEN 'tendencia_ascendente'
    WHEN MAX(p.pendiente_pct_min) < -0.01 THEN 'tendencia_descendente'
    ELSE 'tendencia_estable'
  END AS tendencia_futura
FROM predicciones_cpu p
JOIN ultima_ejecucion u ON p.generado_en = u.generado_en
GROUP BY p.contenedor
ORDER BY variacion_cpu_por_minuto DESC;

WITH ultima_ejecucion AS (
  SELECT MAX(generado_en) AS generado_en
  FROM predicciones_cpu
)
SELECT p.instante_prediccion, p.contenedor, ROUND(p.valor_predicho, 3) AS cpu_predicha_percent
FROM predicciones_cpu p
JOIN ultima_ejecucion u ON p.generado_en = u.generado_en
ORDER BY p.instante_prediccion, p.contenedor;
