create or replace procedure dwa_test.debug_and_log()
language plpgsql as $$
declare
    c_t1 constant timestamp := timestamp '2024-01-15 10:00:00';
    l_n  integer;
begin
    call dwa_test.reset();

    select count(*)::integer into l_n from dwa_log;
    call dwa_test.eq('log empty', l_n::text, '0');

    perform dwa_initialize(p_target_table => 'inc_test_tgt', p_data_slice => 'all', p_lookback_hours => 0, p_debug => false, p_log_table => true);
    select count(*)::integer
    into l_n
    from dwa_log
    where proc_name = 'dwa_initialize'
      and message like 'version=' || dwa_version() || '%';
    call dwa_test.eq('log version', case when l_n > 0 then 'y' else 'n' end, 'y');
    call dwa_test.add_row('inc_test_a', '1', 10, c_t1);
    call dwa_test.capture_source('inc_test_a');
    call dwa_test.merge_all();
    perform dwa_finalize();

    select count(*)::integer into l_n from dwa_log where proc_name = 'dwa_capture_delta';
    call dwa_test.eq('log capture', case when l_n > 0 then 'y' else 'n' end, 'y');
    select count(*)::integer into l_n from dwa_log where proc_name = 'dwa_finalize';
    call dwa_test.eq('log dwa_finalize', case when l_n > 0 then 'y' else 'n' end, 'y');
    select count(*)::integer
    into l_n
    from dwa_watermark
    where target_table = 'inc_test_tgt'
      and target_owner = 'public'
      and source_owner = 'public';
    call dwa_test.eq('wm owner', case when l_n > 0 then 'y' else 'n' end, 'y');
    select count(*)::integer into l_n from dwa_log where message like 'lock released name=%';
    call dwa_test.eq('log lock released', case when l_n > 0 then 'y' else 'n' end, 'y');

    perform dwa_initialize(p_target_table => 'inc_test_tgt', p_data_slice => 'all', p_lookback_hours => 0, p_debug => true, p_log_table => true);
    select count(*)::integer into l_n from dwa_log where message like 'lock acquired name=%';
    call dwa_test.eq('log lock acquired', case when l_n > 0 then 'y' else 'n' end, 'y');
    call dwa_test.capture_source('inc_test_a');
    call dwa_test.eq('debug keys', dwa_test.key_count(), '0');
    perform dwa_finalize();

    call dwa_test.pass('debug_and_log');
end;
$$;

call dwa_test.debug_and_log();
