# Guía de configuración (≈ 30 minutos)

## 1. Proyecto en Google Cloud

1. Entra a https://console.cloud.google.com y crea un proyecto (ej. `retail-pulse-german`).
2. Activa la API de BigQuery.
3. BigQuery tiene una capa gratuita de 1 TB de consultas al mes y 10 GB de almacenamiento.
   Este proyecto usa muy poco, pero **configura una alerta de presupuesto** (Facturación → Presupuestos)
   de, por ejemplo, USD 5 para dormir tranquilo.
4. Instala la CLI de Google Cloud y autentícate:

```bash
gcloud auth login
gcloud config set project TU_PROYECTO
gcloud auth application-default login
```

## 2. Entorno local

```bash
git clone https://github.com/TU_USUARIO/retail-pulse.git
cd retail-pulse
python -m venv .venv          # usa Python 3.11 o 3.12 (dbt aún no soporta bien 3.13)
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env               # edita GCP_PROJECT_ID
```

## 3. Primera ejecución

```bash
# Prueba sin BigQuery (genera data/indicadores_economicos.csv)
python ingestion/indicadores.py --local

# Carga real
python ingestion/indicadores.py
```

Luego, con las variables de `.env` exportadas en la terminal:

```bash
# Linux/Mac
export $(grep -v '^#' .env | xargs)
# Windows PowerShell
# Get-Content .env | Where-Object {$_ -notmatch '^#' -and $_} | ForEach-Object { $k,$v = $_ -split '=',2; Set-Item "env:$k" $v }

cd dbt/retail_pulse
dbt debug --profiles-dir .         # verifica la conexión
dbt build --profiles-dir .         # crea modelos y corre tests
```

Revisa en BigQuery los datasets `staging` y `marts`. Prueba:

```sql
select fecha, sum(venta_neta_clp) as venta_clp
from `TU_PROYECTO.marts.fct_ventas_diarias`
group by fecha
order by fecha desc
limit 30;
```

## 4. Automatización con GitHub Actions

1. En GCP: IAM → Cuentas de servicio → crear `pipeline-retail-pulse` con los roles
   **BigQuery Data Editor** y **BigQuery Job User**.
2. Crea una clave JSON para esa cuenta y descárgala (no la subas al repo).
3. En GitHub: Settings → Secrets and variables → Actions → New repository secret:
   - `GCP_SA_KEY`: contenido completo del JSON
   - `GCP_PROJECT_ID`: id de tu proyecto
4. Pestaña Actions → "Pipeline diario" → **Run workflow** para probarlo.

## Problemas comunes

| Error | Solución |
|---|---|
| `Not found: Dataset ... was not found in location` | Tus datasets deben estar en `US`, igual que `thelook_ecommerce` |
| `Env var required but not provided: 'GCP_PROJECT_ID'` | Exporta las variables de `.env` antes de correr dbt |
| `403 Access Denied` en Actions | Revisa los roles de la cuenta de servicio |
