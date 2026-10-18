-- Excluimos nombre, email y dirección: no se necesitan para el análisis (minimización de datos personales)
select
    id                         as user_id,
    age                        as edad,
    gender                     as genero,
    country                    as pais,
    city                       as ciudad,
    traffic_source             as canal_adquisicion,
    date(created_at)           as fecha_registro
from {{ source('thelook', 'users') }}
