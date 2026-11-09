-- Pass -v dwa_schema=name, or use the current schema.
\if :{?dwa_schema}
set search_path to :"dwa_schema";
\else
select current_schema() as dwa_schema \gset
\endif

do $dwa$
begin
    if current_schema() is null then
        raise exception 'install schema does not exist (search_path=%)', current_setting('search_path');
    end if;
end
$dwa$;
