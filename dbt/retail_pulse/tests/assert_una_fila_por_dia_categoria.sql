-- El test falla si devuelve filas: no debe haber duplicados de (fecha, categoria)
select fecha, categoria, count(*) as n
from {{ ref('fct_ventas_diarias') }}
group by 1, 2
having count(*) > 1
