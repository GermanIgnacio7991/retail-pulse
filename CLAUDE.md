# Retail Pulse — contexto para Claude

## Quién soy y para qué es este proyecto
Soy Germán Cortés, estudiante de Ingeniería en Informática (Duoc UC, egreso 2026) y Data Analyst.
Este es mi **proyecto de portafolio** para conseguir práctica en un banco, retail o empresa grande en Chile.
Prioridades: que sea profesional, que el README lo entienda un reclutador y que yo **entienda todo** lo que hay
(me lo pueden preguntar en una entrevista). Explícame brevemente cada cambio que hagas y por qué.

Responde en español. Nombres de columnas y modelos en español (snake_case), como ya está en el código.

## Qué es
Pipeline de BI automatizado de punta a punta para un e-commerce:
- **Ingesta** (`ingestion/indicadores.py`): dólar, UF e IPC desde la API de mindicador.cl → BigQuery `raw.indicadores_economicos` (WRITE_TRUNCATE, idempotente).
- **Fuente de ventas**: dataset público `bigquery-public-data.thelook_ecommerce` (órdenes, ítems, usuarios, productos). Está en región **US**.
- **Transformación** con dbt (`dbt/retail_pulse/`): `staging` (vistas) → `marts` (tablas). Datasets limpios gracias a la macro `generate_schema_name`.
- **Calidad**: tests genéricos en `_staging.yml` / `_marts.yml` + tests singulares en `tests/`.
- **Orquestación**: `.github/workflows/pipeline.yml`, diario 07:17 hora Chile (todavía sin secretos configurados en GitHub).

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
- [ ] Semana 4 — Detección de anomalías por categoría + alertas (email/Slack) + reporte semanal en lenguaje natural con un LLM.
- [ ] Semana 5 — Completar sección "Hallazgos" del README con números reales, video demo, post en LinkedIn.

## Pendientes conocidos (buenos primeros trabajos)
1. **Deprecaciones de dbt**: mover `freshness` dentro de `config:` en `_sources.yml`, y anidar los argumentos de los tests `relationships`/`accepted_values` bajo `arguments:` en los YAML.
2. **dbt quedó en versión beta** (`dbt=1.13.0-b1`). Fijar versiones estables en `requirements.txt` (dbt-core y dbt-bigquery) y verificar que todo sigue pasando.
3. **IPC 2026 vino vacío** desde mindicador.cl (`/api/ipc/2026` → 0 registros). Investigar; el IPC aún no se usa en los marts.
4. Configurar los secretos `GCP_SA_KEY` y `GCP_PROJECT_ID` en GitHub para que corra el workflow (ver `docs/SETUP.md` §4).

## Convenciones de trabajo
- Commits pequeños con mensajes claros en español (ej. "Agrega segmentación RFM"). Rama `main`.
- Antes de dar algo por terminado: correr `dbt build` y confirmar 0 errores.
- Mantener README y `docs/SETUP.md` al día cuando cambie algo relevante.
- Datos personales: los modelos no exponen nombre, email ni dirección de clientes.
