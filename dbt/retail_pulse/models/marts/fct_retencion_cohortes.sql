-- Retención por cohorte mensual: una fila por (mes_cohorte, meses_desde_primera_compra).
-- Cohorte = mes de la primera compra válida, tomada de dim_clientes_rfm para usar una sola definición.

with clientes as (
    select
        user_id,
        date_trunc(fecha_primera_compra, month) as mes_cohorte
    from {{ ref('dim_clientes_rfm') }}
),

actividad as (
    select
        user_id,
        date_trunc(fecha_orden, month)           as mes_actividad,
        sum(precio_venta_usd)                    as venta_neta_usd
    from {{ ref('stg_order_items') }}
    where estado not in ('cancelled', 'returned')
    group by 1, 2
),

tamano_cohorte as (
    select mes_cohorte, count(*) as clientes_cohorte
    from clientes
    group by 1
),

-- Grilla completa (cohorte × mes transcurrido hasta hoy) para que los meses sin compras queden en 0
grilla as (
    select
        t.mes_cohorte,
        t.clientes_cohorte,
        meses                                    as meses_desde_primera_compra,
        date_add(t.mes_cohorte, interval meses month) as mes_actividad
    from tamano_cohorte t
    cross join unnest(generate_array(
        0, date_diff(date_trunc(current_date(), month), t.mes_cohorte, month)
    )) as meses
),

activos as (
    select
        c.mes_cohorte,
        a.mes_actividad,
        count(*)                                 as clientes_activos,
        sum(a.venta_neta_usd)                    as venta_neta_usd
    from clientes c
    join actividad a using (user_id)
    group by 1, 2
)

select
    g.mes_cohorte,
    g.meses_desde_primera_compra,
    g.mes_actividad,
    g.clientes_cohorte,
    coalesce(a.clientes_activos, 0)                                as clientes_activos,
    round(safe_divide(coalesce(a.clientes_activos, 0), g.clientes_cohorte), 4) as tasa_retencion,
    round(coalesce(a.venta_neta_usd, 0), 2)                        as venta_neta_usd,
    g.mes_actividad = date_trunc(current_date(), month)            as es_mes_en_curso
from grilla g
left join activos a using (mes_cohorte, mes_actividad)
