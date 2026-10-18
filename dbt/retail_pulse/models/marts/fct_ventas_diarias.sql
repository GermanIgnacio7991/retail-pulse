-- Ventas diarias por categoría, en USD y CLP.
-- El dólar no se publica fines de semana ni feriados: se usa el último valor disponible.

with items as (
    select
        i.fecha_orden,
        coalesce(p.categoria, 'Sin categoría') as categoria,
        i.order_id,
        i.user_id,
        i.precio_venta_usd,
        p.costo_usd,
        i.estado
    from {{ ref('stg_order_items') }} i
    left join {{ ref('stg_products') }} p using (product_id)
),

calendario as (
    select fecha
    from unnest(generate_date_array(
        (select min(fecha_orden) from items),
        current_date()
    )) as fecha
),

dolar as (
    select
        c.fecha,
        last_value(ind.dolar_clp ignore nulls) over (
            order by c.fecha
            rows between unbounded preceding and current row
        ) as dolar_clp
    from calendario c
    left join {{ ref('stg_indicadores') }} ind using (fecha)
),

agregado as (
    select
        fecha_orden                                                as fecha,
        categoria,
        count(distinct order_id)                                   as ordenes,
        count(distinct user_id)                                    as clientes,
        count(*)                                                   as unidades,
        sum(if(estado not in ('cancelled', 'returned'), precio_venta_usd, 0))              as venta_neta_usd,
        sum(if(estado not in ('cancelled', 'returned'), precio_venta_usd - costo_usd, 0))  as margen_usd,
        countif(estado = 'returned')                               as unidades_devueltas
    from items
    group by 1, 2
)

select
    a.*,
    safe_divide(a.venta_neta_usd, a.ordenes)          as ticket_promedio_usd,
    safe_divide(a.unidades_devueltas, a.unidades)     as tasa_devolucion,
    d.dolar_clp,
    round(a.venta_neta_usd * d.dolar_clp, 0)          as venta_neta_clp
from agregado a
left join dolar d on d.fecha = a.fecha
