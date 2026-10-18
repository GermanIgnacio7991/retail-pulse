select
    id                         as order_item_id,
    order_id,
    user_id,
    product_id,
    lower(status)              as estado,
    date(created_at)           as fecha_orden,
    cast(sale_price as numeric) as precio_venta_usd
from {{ source('thelook', 'order_items') }}
where date(created_at) <= current_date()
