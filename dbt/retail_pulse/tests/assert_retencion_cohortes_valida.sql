-- El test falla si devuelve filas:
--   - combinación (cohorte, mes transcurrido) duplicada
--   - mes 0 con retención distinta de 100% (todos compraron en su mes de cohorte)
--   - tasa fuera del rango 0-1
with duplicados as (
    select mes_cohorte, meses_desde_primera_compra, 'duplicado' as problema
    from {{ ref('fct_retencion_cohortes') }}
    group by 1, 2
    having count(*) > 1
),

tasas_invalidas as (
    select mes_cohorte, meses_desde_primera_compra, 'tasa inválida' as problema
    from {{ ref('fct_retencion_cohortes') }}
    where (meses_desde_primera_compra = 0 and tasa_retencion != 1)
       or tasa_retencion not between 0 and 1
)

select * from duplicados
union all
select * from tasas_invalidas
