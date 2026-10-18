-- Segmentación RFM: una fila por cliente con al menos una compra válida.
-- Compra válida = ítem no cancelado ni devuelto (misma regla que fct_ventas_diarias).

with compras as (
    select
        user_id,
        min(fecha_orden)             as fecha_primera_compra,
        max(fecha_orden)             as fecha_ultima_compra,
        count(distinct order_id)     as frecuencia,
        sum(precio_venta_usd)        as monto_usd
    from {{ ref('stg_order_items') }}
    where estado not in ('cancelled', 'returned')
    group by 1
),

puntajes as (
    select
        *,
        date_diff(current_date(), fecha_ultima_compra, day) as recencia_dias,
        -- Percentiles 1-5: los empates reciben el mismo puntaje. Menos días = mejor, por eso desc.
        least(5, 1 + cast(floor(5 * percent_rank() over (
            order by date_diff(current_date(), fecha_ultima_compra, day) desc
        )) as int64))                                                     as r_score,
        -- El 69% compra una sola vez: con quintiles, clientes idénticos caerían en puntajes distintos.
        least(frecuencia, 5)                                              as f_score,
        least(5, 1 + cast(floor(5 * percent_rank() over (
            order by monto_usd
        )) as int64))                                                     as m_score
    from compras
)

select
    p.user_id,
    u.pais,
    u.canal_adquisicion,
    u.fecha_registro,
    p.fecha_primera_compra,
    p.fecha_ultima_compra,
    p.recencia_dias,
    p.frecuencia,
    round(p.monto_usd, 2)       as monto_usd,
    p.r_score,
    p.f_score,
    p.m_score,
    s.segmento,
    s.accion_sugerida,
    current_date()              as fecha_calculo
from puntajes p
left join {{ ref('stg_users') }} u using (user_id)
left join {{ ref('segmentos_rfm') }} s using (r_score, f_score)
