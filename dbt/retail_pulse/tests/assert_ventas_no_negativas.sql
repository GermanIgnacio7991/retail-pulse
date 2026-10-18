select *
from {{ ref('fct_ventas_diarias') }}
where venta_neta_usd < 0
