"""
Ingesta de indicadores económicos de Chile (dólar, UF, IPC) desde mindicador.cl
hacia BigQuery (capa raw).

Uso:
    python ingestion/indicadores.py                     # años 2019..año actual -> BigQuery
    python ingestion/indicadores.py --desde 2023        # desde un año específico
    python ingestion/indicadores.py --local             # solo guarda CSV en data/, sin BigQuery

La carga es idempotente: reemplaza la tabla completa en cada ejecución
(son pocos miles de filas), así puedes correrla todos los días sin duplicar datos.
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
import time
from datetime import date, datetime, timezone
from pathlib import Path

import pandas as pd
import requests
from dotenv import load_dotenv

API_BASE = "https://mindicador.cl/api"
INDICADORES = ["dolar", "uf", "ipc"]
TABLA_DESTINO = "indicadores_economicos"

# Días máximos entre el último dato y hoy antes de avisar.
# El IPC es mensual: el INE lo publica ~día 8 del mes siguiente y mindicador lo fecha el día 1.
MAX_DIAS_ATRASO = {"dolar": 7, "uf": 7, "ipc": 70}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)
log = logging.getLogger("ingesta_indicadores")


def obtener_serie(indicador: str, anio: int, reintentos: int = 3) -> list[dict]:
    """Descarga la serie de un indicador para un año, con reintentos simples."""
    url = f"{API_BASE}/{indicador}/{anio}"
    for intento in range(1, reintentos + 1):
        try:
            resp = requests.get(url, timeout=30)
            resp.raise_for_status()
            return resp.json().get("serie", [])
        except requests.RequestException as e:
            log.warning("Fallo %s (intento %d/%d): %s", url, intento, reintentos, e)
            time.sleep(2 * intento)
    raise RuntimeError(f"No se pudo descargar {url} tras {reintentos} intentos")


def extraer(desde: int, hasta: int) -> pd.DataFrame:
    filas = []
    for indicador in INDICADORES:
        for anio in range(desde, hasta + 1):
            serie = obtener_serie(indicador, anio)
            log.info("%s %d: %d registros", indicador, anio, len(serie))
            for punto in serie:
                filas.append(
                    {
                        "indicador": indicador,
                        "fecha": punto["fecha"],
                        "valor": punto["valor"],
                    }
                )
    return pd.DataFrame(filas)


def transformar(df: pd.DataFrame) -> pd.DataFrame:
    """Limpieza mínima: tipos, fecha local y deduplicación. El modelado real va en dbt."""
    if df.empty:
        raise ValueError("La API no devolvió datos")
    df = df.copy()
    # La API entrega timestamps UTC (ej. 2026-10-17T03:00:00.000Z = medianoche en Chile)
    df["fecha"] = (
        pd.to_datetime(df["fecha"], utc=True)
        .dt.tz_convert("America/Santiago")
        .dt.date
    )
    df["valor"] = pd.to_numeric(df["valor"], errors="coerce")
    df = df.dropna(subset=["valor"])
    df = df.drop_duplicates(subset=["indicador", "fecha"], keep="last")
    df["cargado_en"] = datetime.now(timezone.utc)
    return df.sort_values(["indicador", "fecha"]).reset_index(drop=True)


def revisar_atraso(df: pd.DataFrame) -> None:
    """Avisa si algún indicador dejó de actualizarse en la fuente (no detiene la carga)."""
    hoy = date.today()
    ultimas = df.groupby("indicador")["fecha"].max()
    for indicador, maximo in MAX_DIAS_ATRASO.items():
        if indicador not in ultimas:
            log.warning("%s: la API no devolvió ningún dato", indicador)
            continue
        dias = (hoy - ultimas[indicador]).days
        if dias > maximo:
            log.warning(
                "%s desactualizado: último dato %s (%d días, máximo %d)",
                indicador, ultimas[indicador], dias, maximo,
            )


def cargar_bigquery(df: pd.DataFrame) -> None:
    from google.cloud import bigquery

    proyecto = os.environ["GCP_PROJECT_ID"]
    dataset = os.getenv("BQ_RAW_DATASET", "raw")
    ubicacion = os.getenv("BQ_LOCATION", "US")

    cliente = bigquery.Client(project=proyecto, location=ubicacion)
    cliente.create_dataset(
        bigquery.Dataset(f"{proyecto}.{dataset}"), exists_ok=True
    )

    tabla_id = f"{proyecto}.{dataset}.{TABLA_DESTINO}"
    config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        schema=[
            bigquery.SchemaField("indicador", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("fecha", "DATE", mode="REQUIRED"),
            bigquery.SchemaField("valor", "FLOAT64", mode="REQUIRED"),
            bigquery.SchemaField("cargado_en", "TIMESTAMP", mode="REQUIRED"),
        ],
    )
    job = cliente.load_table_from_dataframe(df, tabla_id, job_config=config)
    job.result()
    log.info("Cargadas %d filas en %s", len(df), tabla_id)


def main() -> int:
    load_dotenv()
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    parser.add_argument("--desde", type=int, default=2019, help="Año inicial")
    parser.add_argument("--hasta", type=int, default=date.today().year, help="Año final")
    parser.add_argument("--local", action="store_true", help="Guardar CSV sin cargar a BigQuery")
    args = parser.parse_args()

    df = transformar(extraer(args.desde, args.hasta))
    log.info("Resumen:\n%s", df.groupby("indicador")["fecha"].agg(["min", "max", "count"]))
    revisar_atraso(df)

    if args.local:
        Path("data").mkdir(exist_ok=True)
        ruta = Path("data") / f"{TABLA_DESTINO}.csv"
        df.to_csv(ruta, index=False)
        log.info("Guardado en %s", ruta)
    else:
        cargar_bigquery(df)
    return 0


if __name__ == "__main__":
    sys.exit(main())
