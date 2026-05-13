insert into logs (
    id, message, level, module, function, arity, file, line, last_occurrence, resolved, muted
) values ( $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11 )
