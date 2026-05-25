#!/usr/bin/env Rscript

library(jsonlite)

webhdfs_url <- sub("/$", "", Sys.getenv(
  "WEBHDFS_URL",
  "http://Nodo-principal:9870/webhdfs/v1"
))
hdfs_user <- Sys.getenv("HDFS_USER", "root")
hdfs_input <- Sys.getenv("HDFS_INPUT_PATH", "/metricas/prometheus")
hdfs_output <- Sys.getenv("HDFS_OUTPUT_PATH", "/metricas/predicciones_cpu")
horizon_steps <- as.integer(Sys.getenv("PREDICTION_HORIZON_STEPS", "15"))
step_seconds <- as.integer(Sys.getenv("PREDICTION_STEP_SECONDS", "60"))
min_samples <- as.integer(Sys.getenv("PREDICTION_MIN_SAMPLES", "5"))

url_path <- function(path) {
  paste0(webhdfs_url, path)
}

curl_text <- function(args) {
  result <- system2("curl", args, stdout = TRUE, stderr = TRUE)
  status <- attr(result, "status")
  if (!is.null(status) && status != 0) {
    stop(paste(result, collapse = "\n"))
  }
  paste(result, collapse = "\n")
}

list_csv_files <- function(path) {
  response <- curl_text(c(
    "-fsS",
    shQuote(paste0(
      url_path(path),
      "?op=LISTSTATUS&user.name=",
      hdfs_user
    ))
  ))
  items <- fromJSON(response)$FileStatuses$FileStatus
  if (is.null(items) || nrow(items) == 0) {
    return(character())
  }
  names <- items$pathSuffix[
    items$type == "FILE" & grepl("\\.csv$", items$pathSuffix)
  ]
  file.path(path, names)
}

download_csv <- function(path) {
  destination <- tempfile(fileext = ".csv")
  url <- paste0(
    url_path(path),
    "?op=OPEN&user.name=",
    hdfs_user
  )
  result <- system2(
    "curl",
    c("-fsSL", "-o", shQuote(destination), shQuote(url)),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(result, "status")
  if (!is.null(status) && status != 0) {
    stop(paste(result, collapse = "\n"))
  }
  read.csv(
    destination,
    header = FALSE,
    col.names = c("instante", "contenedor", "metrica", "valor", "unidad"),
    stringsAsFactors = FALSE
  )
}

create_hdfs_dir <- function(path) {
  invisible(curl_text(c(
    "-fsS",
    "-X", "PUT",
    shQuote(paste0(
      url_path(path),
      "?op=MKDIRS&user.name=",
      hdfs_user
    ))
  )))
}

upload_csv <- function(local_path, hdfs_path) {
  invisible(curl_text(c(
    "-fsSL",
    "-X", "PUT",
    "--upload-file", shQuote(local_path),
    shQuote(paste0(
      url_path(hdfs_path),
      "?op=CREATE&overwrite=true&user.name=",
      hdfs_user
    ))
  )))
}

format_utc <- function(value) {
  format(value, "%Y-%m-%d %H:%M:%S", tz = "UTC", usetz = FALSE)
}

files <- list_csv_files(hdfs_input)
if (length(files) == 0) {
  stop("No hay CSV historicos de metricas en HDFS.")
}

data <- do.call(rbind, lapply(files, download_csv))
data$instante <- as.POSIXct(data$instante, tz = "UTC", format = "%Y-%m-%d %H:%M:%S")
data$valor <- as.numeric(data$valor)
cpu <- data[data$metrica == "cpu_usage" & !is.na(data$valor), ]
cpu <- cpu[order(cpu$contenedor, cpu$instante), ]

if (nrow(cpu) == 0) {
  stop("No hay muestras CPU para predecir.")
}

generated_at <- as.POSIXct(Sys.time(), tz = "UTC")
outputs <- list()
containers <- unique(cpu$contenedor)

for (container in containers) {
  training <- cpu[cpu$contenedor == container, ]
  training <- training[!duplicated(training$instante, fromLast = TRUE), ]
  if (nrow(training) < min_samples) {
    message("Omitido ", container, ": muestras insuficientes (", nrow(training), ").")
    next
  }

  origin <- min(training$instante)
  training$minutes <- as.numeric(difftime(training$instante, origin, units = "mins"))
  model <- lm(valor ~ minutes, data = training)
  slope <- unname(coef(model)[["minutes"]])
  last_time <- max(training$instante)
  forecast_origin <- max(last_time, generated_at)
  future_time <- forecast_origin + seq_len(horizon_steps) * step_seconds
  future_minutes <- as.numeric(difftime(future_time, origin, units = "mins"))
  predicted <- pmax(0, as.numeric(predict(model, newdata = data.frame(minutes = future_minutes))))

  outputs[[container]] <- data.frame(
    generado_en = rep(format_utc(generated_at), horizon_steps),
    instante_prediccion = format_utc(future_time),
    contenedor = rep(container, horizon_steps),
    metrica = rep("cpu_usage", horizon_steps),
    valor_predicho = round(predicted, 6),
    unidad = rep("percent", horizon_steps),
    modelo = rep("regresion_lineal_r", horizon_steps),
    pendiente_pct_min = rep(round(slope, 8), horizon_steps),
    stringsAsFactors = FALSE
  )
}

if (length(outputs) == 0) {
  stop("Ningun contenedor tiene muestras suficientes para crear predicciones.")
}

prediction <- do.call(rbind, outputs)
output_file <- tempfile(fileext = ".csv")
write.table(
  prediction,
  output_file,
  sep = ",",
  row.names = FALSE,
  col.names = FALSE,
  quote = FALSE,
  na = ""
)

create_hdfs_dir(hdfs_output)
filename <- paste0(
  "prediccion_cpu_",
  format(generated_at, "%Y%m%dT%H%M%SZ", tz = "UTC"),
  ".csv"
)
target <- file.path(hdfs_output, filename)
upload_csv(output_file, target)

cat("Predicciones generadas con R:", nrow(prediction), "filas\n")
cat("Historico utilizado:", nrow(cpu), "muestras CPU\n")
cat("Destino HDFS:", target, "\n")
cat("Modelo: regresion lineal temporal por contenedor\n")
