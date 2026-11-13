-- Incremental passes vs full refresh, with batches and without.

declare
    l_full number;
    l_inc  number;
    l_src  number;
    l_diff number;
    l_ok   number;
    l_cnt  number;
begin
    seed_customer_metrics;
    run_customer_metrics(1);

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
        raise_application_error(-20000, 'metrics seed values mismatch, matched=' || l_ok);
    end if;

    seed_customer_delta;
    run_customer_metrics(1);

    select cnt_completed
    into l_cnt
    from customer_metrics
    where customer_id = 1;

    if l_cnt != 0 then
        raise_application_error(
            -20000,
            'metrics cancelled cnt_completed=' || l_cnt || ', expected 0'
        );
    end if;

    dbms_output.put_line('metrics order grain and cancelled status: passed');

    seed_customer_metrics;
    run_incremental_passes(1);
    snapshot_customer_metrics(p_reset => true);
    run_customer_metrics(1);

    l_diff := customer_metrics_xor;
    select count(*) into l_full from customer_metrics;
    select count(*) into l_inc from customer_metrics_inc;
    select count(*) into l_src from customers;

    if l_diff != 0 then
        raise_application_error(-20000, 'metrics batches xor=' || l_diff || ', expected 0');
    end if;
    if l_full != l_src or l_full != l_inc then
        raise_application_error(
            -20000,
            'metrics batches counts full=' || l_full || ' inc=' || l_inc || ' src=' || l_src
        );
    end if;

    dbms_output.put_line('metrics incremental=full refresh (batches): passed');

    seed_customer_metrics;
    run_incremental_passes(null);
    snapshot_customer_metrics(p_reset => true);
    run_customer_metrics(null);

    l_diff := customer_metrics_xor;
    select count(*) into l_full from customer_metrics;
    select count(*) into l_inc from customer_metrics_inc;
    select count(*) into l_src from customers;

    if l_diff != 0 then
        raise_application_error(-20000, 'metrics no-batch xor=' || l_diff || ', expected 0');
    end if;
    if l_full != l_src or l_full != l_inc then
        raise_application_error(
            -20000,
            'metrics no-batch counts full=' || l_full || ' inc=' || l_inc || ' src=' || l_src
        );
    end if;

    dbms_output.put_line('metrics incremental=full refresh (no batches): passed');
end;
/
