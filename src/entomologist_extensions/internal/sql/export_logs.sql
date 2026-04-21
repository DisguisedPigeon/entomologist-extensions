select 
    l.id,
    l.message,
    l.level,
    l.module,
    l.function,
    l.arity,
    l.file,
    l.line,
    l.last_occurrence,
    l.resolved,
    l.muted,
    coalesce(array_remove(array_agg(lt.tag), null), '{}') as tags,
    coalesce(array_remove(array_agg(o.id), null), '{}') as occurrences
from logs as l
left join log2tag as lt on l.id = lt.log
left join occurrences as o on l.id = o.log
group by l.id;
