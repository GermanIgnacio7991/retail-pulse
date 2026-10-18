-- Pivotea a una fila por fecha. El dólar y la UF son diarios; el IPC es mensual.
select
    fecha,
    max(if(indicador = 'dolar', valor, null)) as dolar_clp,
    max(if(indicador = 'uf',    valor, null)) as uf_clp,
    max(if(indicador = 'ipc',   valor, null)) as ipc_mensual_pct
from {{ source('raw', 'indicadores_economicos') }}
group by fecha
