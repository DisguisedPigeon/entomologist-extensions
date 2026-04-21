select 
    id,
    name,
    coalesce(array_remove(array_agg(lt.log), null), '{}') as logs
from tags as t
left join log2tag as lt on lt.tag = t.id
group by t.id;
