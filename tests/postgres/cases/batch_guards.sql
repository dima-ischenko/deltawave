create or replace procedure dwa_test.batch_guards()
language plpgsql as $$
declare
    c_t1 constant timestamp := timestamp '2024-01-15 10:00:00';
begin
    call dwa_test.reset();
    call dwa_test.add_row('inc_test_a', 'a', 1, c_t1);
    call dwa_test.add_row('inc_test_a', 'b', 1, c_t1);
    call dwa_test.add_row('inc_test_a', 'c', 1, c_t1);
    call dwa_test.capture_source('inc_test_a');
    perform dwa_prepare_batches(p_batch_size => 2);
    if not dwa_next_batch() then
        call dwa_test.fail('guard dwa_finalize', 'missing batch');
    end if;
    call dwa_test.expect_dwa('guard dwa_finalize', 'DWA-20005', 'select dwa_finalize()');
    call dwa_test.merge_batch();
    perform dwa_finish_batch();
    while dwa_next_batch() loop
        call dwa_test.merge_batch();
        perform dwa_finish_batch();
    end loop;
    perform dwa_finalize();
    call dwa_test.eq('guard tgt', dwa_test.tgt_state(), 'a:1:1,b:1:1,c:1:1');

    call dwa_test.reset();
    call dwa_test.add_row('inc_test_a', 'a', 1, c_t1);
    call dwa_test.add_row('inc_test_a', 'b', 1, c_t1);
    call dwa_test.capture_source('inc_test_a');
    perform dwa_prepare_batches(p_batch_size => 1);
    if not dwa_next_batch() then
        call dwa_test.fail('guard next', 'missing batch');
    end if;
    call dwa_test.expect_dwa('guard next', 'DWA-20014', 'select dwa_next_batch()');
    call dwa_test.merge_batch();
    perform dwa_finish_batch();
    while dwa_next_batch() loop
        call dwa_test.merge_batch();
        perform dwa_finish_batch();
    end loop;
    perform dwa_finalize();

    call dwa_test.reset();
    call dwa_test.add_row('inc_test_a', 'a', 1, c_t1);
    call dwa_test.capture_source('inc_test_a');
    perform dwa_prepare_batches(p_batch_size => 2);
    call dwa_test.expect_dwa(
        'guard size', 'DWA-20009', 'select dwa_prepare_batches(p_batch_size => 3)'
    );
    call dwa_test.expect_dwa(
        'guard capture', 'DWA-20013',
        'call dwa_test.capture_source(''inc_test_a'')'
    );
    while dwa_next_batch() loop
        call dwa_test.merge_batch();
        perform dwa_finish_batch();
    end loop;
    perform dwa_finalize();

    call dwa_test.reset();
    call dwa_test.expect_dwa('guard no prepare', 'DWA-20016', 'select dwa_next_batch()');
    call dwa_test.expect_dwa(
        'guard missing target', 'DWA-20022',
        'select dwa_initialize(p_target_table => ''no_such_dwa_table'')'
    );
    call dwa_test.expect_dwa('guard no batch', 'DWA-20017', 'select dwa_finish_batch()');
    call dwa_test.pass('batch_guards');
end;
$$;

call dwa_test.batch_guards();
