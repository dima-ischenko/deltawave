-- True while a batch is open in dwa_batch_tmp. Do not commit before dwa_finish_batch.
create or replace function dwa_next_batch()
returns boolean
language plpgsql
set search_path = pg_temp, :"dwa_schema", public as $$
declare
l_target   text;
l_ready    boolean;
l_batch_no numeric;
l_keys     bigint;
l_next     numeric;
begin
  select target_table, batches_ready, batch_no
  into l_target, l_ready, l_batch_no
  from dwa_session_tmp
  where id = 1;

  if l_target is null then
    raise exception 'DWA-20001 Call dwa_initialize first';
  end if;
  if not l_ready then
    raise exception 'DWA-20016 Call dwa_prepare_batches first';
  end if;

  if l_batch_no is not null and exists (select 1 from dwa_batch_tmp) then
    raise exception 'DWA-20014 batch % is open; call dwa_finish_batch', l_batch_no;
  end if;
  if l_batch_no is not null then
    raise exception 'DWA-20019 batch % lost its keys; call dwa_initialize', l_batch_no;
  end if;

  select min(batch_no)
  into l_next
  from dwa_keys_tmp
  where batch_no is not null
   and batch_done = 0;

  if l_next is null then
    if _dwa_unassigned() > 0 then
      raise exception 'DWA-20011 batch numbers are missing; call dwa_prepare_batches';
    end if;

    update dwa_session_tmp
    set batch_no = null
    where id = 1;
    delete from dwa_batch_tmp;
    perform _dwa_write_log('dwa_next_batch', 0, 'nothing left to apply');
    return false;
  end if;

  delete from dwa_batch_tmp;
  insert into dwa_batch_tmp (pk_1, pk_2, pk_3)
  select distinct pk_1, pk_2, pk_3
  from dwa_keys_tmp
  where batch_no = l_next
   and batch_done = 0;
  get diagnostics l_keys = row_count;

  if l_keys = 0 then
    raise exception 'DWA-20011 batch % has no keys', l_next;
  end if;

  update dwa_session_tmp set batch_no = l_next where id = 1;
  perform _dwa_write_log(
    'dwa_next_batch',
    l_keys,
    format('batch %s opened', l_next)
  );
  return true;
end;
$$;
