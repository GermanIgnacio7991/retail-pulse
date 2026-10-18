select
    order_id,
    user_id,
    lower(status)              as estado,
    created_at                 as creado_en,
    date(created_at)           as fecha_orden,
    shipped_at                 as enviado_en,
    delivered_at               as entregado_en,
    returned_at                as devuelto_en,
    num_of_item                as cantidad_items
from {{ source('thelook', 'orders') }}
-- el dataset sintético a veces trae fechas futuras
where date(created_at) <= current_date()
