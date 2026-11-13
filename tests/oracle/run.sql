-- Run the checks. tests/oracle/run.sh deploys pkg_dwa first.

whenever sqlerror exit sql.sqlcode
set serveroutput on size unlimited
set define off
set feedback off
set verify off

begin execute immediate 'drop package pkg_dwa_test'; exception when others then if sqlcode != -4043 then raise; end if; end;
/

@tests/oracle/helpers/tables.sql
@tests/oracle/helpers/pkg_dwa_test.sql

declare
    l_errors number;
begin
    select count(*)
    into l_errors
    from user_errors
    where name in ('PKG_DWA', 'PKG_DWA_TEST');

    if l_errors > 0 then
        for r in (
            select name, line, position, text
            from user_errors
            where name in ('PKG_DWA', 'PKG_DWA_TEST')
            order by name, sequence
        ) loop
            dbms_output.put_line(
                r.name || ' ' || r.line || '/' || r.position || ': ' || r.text
            );
        end loop;
        raise_application_error(-20000, 'dwa did not compile, errors=' || l_errors);
    end if;
end;
/

@tests/oracle/cases/static_without_batches.sql
@tests/oracle/cases/lookback_window.sql
@tests/oracle/cases/capture_placeholders.sql
@tests/oracle/cases/static_batches.sql
@tests/oracle/cases/same_result.sql
@tests/oracle/cases/rerun_after_failed_batch.sql
@tests/oracle/cases/batch_guards.sql
@tests/oracle/cases/debug_and_log.sql
@tests/oracle/cases/one_pk_one_batch.sql
@tests/oracle/cases/rollback_without_commit.sql
@tests/oracle/cases/volume.sql
@tests/oracle/cases/rolling_and_soft_delete.sql

begin
    dbms_output.put_line('pkg_dwa_test: passed');
end;
/

@tests/oracle/helpers/metrics_tables.sql
@tests/oracle/helpers/run_metrics.sql
@tests/oracle/cases/metrics_same_result.sql
@tests/oracle/cases/metrics_silent_dml.sql

delete from dwa_watermark
where target_table = 'customer_metrics';

@demo/oracle/tables.sql
@demo/oracle/seed.sql
@demo/oracle/run.sql
@demo/oracle/check.sql

declare
    l_metrics number;
    l_wm      number;
    l_ok      number;
begin
    select count(*) into l_metrics from customer_metrics;
    select count(*)
    into l_wm
    from dwa_watermark
    where target_table = 'customer_metrics'
      and data_slice = 'all';

    if l_metrics != 3 then
        raise_application_error(-20000, 'demo metrics=' || l_metrics || ', expected 3');
    end if;
    if l_wm != 3 then
        raise_application_error(-20000, 'demo watermarks=' || l_wm || ', expected 3');
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

    if l_ok != 3 then
        raise_application_error(-20000, 'demo metric values mismatch, matched=' || l_ok);
    end if;

    dbms_output.put_line('demo: passed');
end;
/
exit
