# Retail Pulse — contexto para Claude

## Quién soy y para qué es este proyecto
Soy Germán Cortés, estudiante de Ingeniería en Informática (Duoc UC, egreso 2026) y Data Analyst.
Este es mi **proyecto de portafolio** para conseguir práctica en un banco, retail o empresa grande en Chile.
Prioridades: que sea profesional, que el README lo entienda un reclutador y que yo **entienda todo** lo que hay
(me lo pueden preguntar en una entrevista). Explícame brevemente cada cambio que hagas y por qué.

Responde en español. Nombres de columnas y modelos en español (snake_case), como ya está en el código.
Escribe también en español las descripciones de los comandos que ejecutes, los mensajes de commit y los comentarios en el código.

## Qué es
Pipeline de BI automatizado de punta a punta para un e-commerce:
- **Ingesta** (`ingestion/indicadores.py`): dólar, UF e IPC desde la API de mindicador.cl → BigQuery `raw.indicadores_economicos` (WRITE_TRUNCATE, idempotente).
- **Fuente de ventas**: dataset público `bigquery-public-data.thelook_ecommerce` (órdenes, ítems, usuarios, productos). Está en región **US**.
- **Transformación** con dbt (`dbt/retail_pulse/`): `staging` (vistas) → `marts` (tablas). Datasets limpios gracias a la macro `generate_schema_name`.
- **Calidad**: tests genéricos en `_staging.yml` / `_marts.yml` + tests singulares en `tests/`.
- **Orquestación**: `.github/workflows/pipeline.yml`, diario 07:17 hora Chile. Corre en GitHub con la cuenta de servicio `pipeline-retail-pulse` (roles BigQuery Data Editor + Job User).

## Mi entorno
- Windows + PowerShell en la terminal de VS Code. Entorno virtual en `.venv` (`.venv\Scripts\activate`).
- Google Cloud en modo **BigQuery Sandbox** (sin facturación). Restricciones:
  - Sin DML (`INSERT/UPDATE/DELETE/MERGE`) → no usar modelos incrementales con merge; preferir `table`/`view`.
  - Las tablas expiran a los 60 días (no importa: el pipeline las recrea).
- El ID del proyecto GCP está en `.env` (`GCP_PROJECT_ID`). **Nunca** subir `.env` ni JSON de credenciales.
- Autenticación local con `gcloud auth application-default login` (ADC); `profiles.yml` usa `method: oauth`.

## Comandos
```powershell
# Cargar variables de .env en la sesión de PowerShell (necesario antes de dbt)
Get-Content .env | Where-Object {$_ -notmatch '^#' -and $_} | ForEach-Object { $k,$v = $_ -split '=',2; Set-Item "env:$k" $v }

python ingestion/indicadores.py            # carga a BigQuery
python ingestion/indicadores.py --local    # solo CSV en data/

cd dbt\retail_pulse
dbt build --profiles-dir .                 # modelos + tests
```

## Estado actual (18-oct-2026)
- [x] Semana 1 — Ingesta: 4.895 filas cargadas (dólar 2019→hoy, UF, IPC).
- [x] Semana 2 — dbt: `dbt build` → PASS=26, WARN=0, ERROR=0. `marts.fct_ventas_diarias` ≈ 47k filas (día × categoría).
- [ ] Semana 3 — Segmentación RFM (`dim_clientes_rfm`), cohortes de retención, dashboard (Looker Studio o Power BI).
  - [x] RFM: `marts.dim_clientes_rfm` ≈ 66k clientes + seed `segmentos_rfm` (grilla R×F). `dbt build` → PASS=40. F = n° de compras (no quintiles: 69% compra 1 vez, máx 4).
  - [x] Cohortes: `marts.fct_retencion_cohortes` ≈ 4,5k filas (94 cohortes mensuales × meses transcurridos, grilla con ceros). `dbt build` → PASS=45. Retención mes 1: 3% (cohortes 2019) → 8,2% (2026); dataset sintético, no afirmar causas.
  - [x] Dashboard Looker Studio (21-oct-2026): 3 páginas (Ventas, Clientes, Retención), público: https://datastudio.google.com/reporting/a7c23750-48b2-46d8-88f2-b01e4d611d46. Tasas como campos calculados SUM/SUM (`retencion_ponderada`, `tasa_devolucion_real`, `ticket_promedio_real`, `margen_pct`, `pct_recurrentes`); filtro fijo "Sin mes en curso" en Retención.
  - [ ] Dashboard Power BI (mismo diseño de 3 páginas).
  - [ ] Capturas de las 3 páginas en `docs/img/` para el README.
- [ ] Semana 4 — Detección de anomalías por categoría + alertas (email/Slack) + reporte semanal en lenguaje natural con un LLM.
- [ ] Semana 5 — Completar sección "Hallazgos" del README con números reales, video demo, post en LinkedIn.

## Pendientes conocidos (buenos primeros trabajos)
1. ~~**Deprecaciones de dbt**~~ ✅ (18-oct-2026): `loaded_at_field`/`freshness` bajo `config:` en `_sources.yml` y argumentos de `relationships`/`accepted_values` bajo `arguments:` en `_staging.yml`. `dbt parse` sin advertencias.
2. ~~**Versiones de dbt**~~ ✅ (18-oct-2026): fijadas en `requirements.txt` → `dbt-core==1.12.6`, `dbt-bigquery==1.12.1` (antes se coló la beta `1.13.0-b1`). Reinstalado, desinstalado el plugin sobrante `dbt-state` (pedía login a dbt State) y `dbt build` OK.
3. ~~**IPC 2026 vino vacío**~~ ✅ (18-oct-2026): mindicador.cl dejó de actualizar el IPC después de dic-2025 (UTM, IMACEC y dólar sí están al día) → es la fuente, no el código. Se mantiene el IPC y `revisar_atraso()` en `indicadores.py` avisa con WARNING si un indicador supera `MAX_DIAS_ATRASO`. Si algún mart necesita IPC, evaluar la API del Banco Central (BDE).
4. ~~Secretos de GitHub~~ ✅ (18-oct-2026): `GCP_SA_KEY` y `GCP_PROJECT_ID` configurados; primera corrida manual en verde (1m 32s). Actions subidas a versiones con Node 24. Ojo: desde el 19-oct-2026 `ubuntu-latest` = Ubuntu 26; si falla una corrida, revisar eso primero.

## Convenciones de trabajo
- Commits pequeños con mensajes claros en español (ej. "Agrega segmentación RFM"). Rama `main`.
- Antes de dar algo por terminado: correr `dbt build` y confirmar 0 errores.
- Mantener README y `docs/SETUP.md` al día cuando cambie algo relevante.
- Datos personales: los modelos no exponen nombre, email ni dirección de clientes.
