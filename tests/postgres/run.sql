-- Rebuild into schema lib and run the checks.

\set ON_ERROR_STOP on
\set dwa_schema lib
drop schema if exists dwa_test cascade;
drop schema if exists lib cascade;
create schema lib;
\i lib/postgres/deploy.sql
set search_path to lib, public;

\i tests/postgres/helpers/tables.sql
\i tests/postgres/helpers/helpers.sql

delete from dwa_watermark
where target_table in ('inc_test_tgt', 'other_tgt');

\i tests/postgres/cases/static_without_batches.sql
\i tests/postgres/cases/lookback_window.sql
\i tests/postgres/cases/capture_placeholders.sql
\i tests/postgres/cases/static_batches.sql
\i tests/postgres/cases/same_result.sql
\i tests/postgres/cases/rerun_after_failed_batch.sql
\i tests/postgres/cases/batch_guards.sql
\i tests/postgres/cases/debug_and_log.sql
\i tests/postgres/cases/one_pk_one_batch.sql
\i tests/postgres/cases/rollback_without_commit.sql
\i tests/postgres/cases/volume.sql
\i tests/postgres/cases/rolling_and_soft_delete.sql

do $$ begin raise notice 'dwa_test: passed'; end; $$;

\i tests/postgres/helpers/metrics_tables.sql
\i tests/postgres/helpers/run_metrics.sql
\i tests/postgres/cases/metrics_same_result.sql
\i tests/postgres/cases/metrics_silent_dml.sql

delete from dwa_watermark
where target_table = 'customer_metrics';

\i demo/postgres/tables.sql
\i demo/postgres/seed.sql
\i demo/postgres/run.sql
\i demo/postgres/check.sql

do $check$
declare
    l_metrics integer;
    l_wm      integer;
    l_ok      integer;
begin
    select count(*) into l_metrics from customer_metrics;
    select count(*)
    into l_wm
    from dwa_watermark
    where target_table = 'customer_metrics'
      and data_slice = 'all';

    if l_metrics is distinct from 3 then
        raise exception 'demo metrics=%, expected 3', l_metrics;
    end if;
    if l_wm is distinct from 3 then
        raise exception 'demo watermarks=%, expected 3', l_wm;
    end if;

    select count(*)
    into l_ok
    from customer_metrics
    where (customer_id = 1 and min_amount = 45 and max_amount = 50
           and avg_amount = 47.5 and sum_amount = 95
           and last_order_id = 102 and cnt_completed = 2)
       or (customer_id = 2 and min_amount = 100 and max_amount = 100
           and avg_amount = 100 and sum_amount = 100
           and last_order_id = 201 and cnt_completed = 0)
       or (customer_id = 3 and min_amount = 21 and max_amount = 21
           and avg_amount = 21 and sum_amount = 21
           and last_order_id = 301 and cnt_completed = 1);

    if l_ok is distinct from 3 then
        raise exception 'demo metric values mismatch, matched=%', l_ok;
    end if;

    raise notice 'demo: passed';
end;
$check$;
