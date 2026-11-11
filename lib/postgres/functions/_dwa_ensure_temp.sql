create or replace function _dwa_ensure_temp()
returns void
language plpgsql
set search_path = pg_temp, :"dwa_schema", public as $$
declare
l_by_id  text := '';
l_by_pk  text := '';
begin
  -- Greenplum: PK must include the distribution key; keys are distributed by pk_1.
  if position('greenplum' in lower(version())) > 0 then
    l_by_id := ' distributed by (id)';
    l_by_pk := ' distributed by (pk_1)';
  end if;

  -- Drop stale session tables from older installs.
  if to_regclass('dwa_session_tmp') is not null
   and (
     exists (
       select 1
       from pg_attribute
       where attrelid = to_regclass('dwa_session_tmp')
         and attname = 'data_segment'
         and not attisdropped
     )
     or not exists (
       select 1
       from pg_attribute
       where attrelid = to_regclass('dwa_session_tmp')
         and attname = 'target_owner'
         and not attisdropped
     )
   ) then
    drop table dwa_session_tmp;
  end if;

  if to_regclass('dwa_session_tmp') is null then
    execute format($sql$
      create temp table dwa_session_tmp (
        id              int primary key,
        target_owner    text,
        target_table    text,
        data_slice      text,
        lookback_hours  numeric,
        batch_no        numeric,
        batch_size      numeric,
        batches_ready   boolean,
        debug           boolean not null default false,
        log_table       boolean not null default false,
        constraint ck_dwa_session_tmp_id check (id = 1)
      ) on commit preserve rows%s
    $sql$, l_by_id);
  end if;

  if to_regclass('dwa_session_tmp') is not null
   and not exists (
     select 1
     from pg_attribute
     where attrelid = to_regclass('dwa_session_tmp')
      and attname = 'debug'
      and not attisdropped
   ) then
    alter table dwa_session_tmp add column debug boolean not null default false;
    alter table dwa_session_tmp add column log_table boolean not null default false;
  end if;

  -- Drop stale dwa_keys_tmp from older installs.
  if to_regclass('dwa_keys_tmp') is not null
   and (
     exists (
       select 1
       from pg_attribute
       where attrelid = to_regclass('dwa_keys_tmp')
         and attname = 'target_table'
         and not attisdropped
     )
     or not exists (
       select 1
       from pg_attribute
       where attrelid = to_regclass('dwa_keys_tmp')
         and attname = 'source_owner'
         and not attisdropped
     )
   ) then
    drop table dwa_keys_tmp;
  end if;

  if to_regclass('dwa_keys_tmp') is null then
    execute format($sql$
      create temp table dwa_keys_tmp (
        source_owner    text        not null,
        source_table    text        not null,
        pk_1            text        not null,
        pk_2            text,
        pk_3            text,
        watermark       timestamp   not null,
        batch_no        numeric,
        batch_done      smallint    not null default 0,
        constraint ck_dwa_keys_tmp_done check (batch_done in (0, 1))
      ) on commit preserve rows%s
    $sql$, l_by_pk);
  end if;

  if to_regclass('dwa_batch_tmp') is null then
    execute format($sql$
      create temp table dwa_batch_tmp (
        pk_1            text        not null,
        pk_2            text,
        pk_3            text
      ) on commit delete rows%s
    $sql$, l_by_pk);
  end if;

  -- GP6 / PG 9.4: no CREATE INDEX IF NOT EXISTS.
  drop index if exists idx_dwa_keys_tmp_batch;
  create index idx_dwa_keys_tmp_batch
    on dwa_keys_tmp (batch_no, batch_done);
end;
$$;
