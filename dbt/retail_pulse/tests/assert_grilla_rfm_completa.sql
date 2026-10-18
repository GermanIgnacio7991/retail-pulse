-- La grilla debe cubrir las 25 combinaciones de R y F exactamente una vez;
-- si falta o se repite alguna, habría clientes sin segmento o duplicados.
with esperado as (
    select r, f
    from unnest(generate_array(1, 5)) as r
    cross join unnest(generate_array(1, 5)) as f
)

select e.r, e.f, count(s.segmento) as n
from esperado e
left join {{ ref('segmentos_rfm') }} s
    on s.r_score = e.r and s.f_score = e.f
group by 1, 2
having count(s.segmento) != 1
