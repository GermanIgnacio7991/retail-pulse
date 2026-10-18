select
    id                            as product_id,
    name                          as nombre,
    brand                         as marca,
    category                      as categoria,
    department                    as departamento,
    cast(cost as numeric)         as costo_usd,
    cast(retail_price as numeric) as precio_lista_usd
from {{ source('thelook', 'products') }}
