USE metricas_hive;

-- Media de memoria por contenedor.
SELECT contenedor, ROUND(AVG(valor), 3) AS memoria_media_mib
FROM metricas_contenedores
WHERE metrica = 'memory_usage'
GROUP BY contenedor
ORDER BY memoria_media_mib DESC;

-- Maximo de CPU por contenedor.
SELECT contenedor, ROUND(MAX(valor), 3) AS cpu_max_percent
FROM metricas_contenedores
WHERE metrica = 'cpu_usage'
GROUP BY contenedor
ORDER BY cpu_max_percent DESC;

-- Evolucion temporal de memoria.
SELECT instante, contenedor, ROUND(valor, 3) AS memoria_mib
FROM metricas_contenedores
WHERE metrica = 'memory_usage'
ORDER BY instante, contenedor;

-- Comparacion antes/despues de una carga. Pasar MOMENTO_CARGA al script ejecutor.
SELECT
  CASE
    WHEN instante < CAST('${hiveconf:momento_carga}' AS TIMESTAMP) THEN 'antes'
    ELSE 'despues'
  END AS periodo,
  contenedor,
  metrica,
  ROUND(AVG(valor), 3) AS valor_medio,
  ROUND(MAX(valor), 3) AS valor_maximo
FROM metricas_contenedores
GROUP BY
  CASE
    WHEN instante < CAST('${hiveconf:momento_carga}' AS TIMESTAMP) THEN 'antes'
    ELSE 'despues'
  END,
  contenedor,
  metrica
ORDER BY metrica, contenedor, periodo;
