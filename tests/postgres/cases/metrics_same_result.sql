-- Incremental passes vs full refresh, with batches and without.

do $check$
declare
    l_full integer;
    l_inc  integer;
    l_src  integer;
    l_diff integer;
    l_ok   integer;
    l_cnt  numeric;
begin
    call dwa_test.seed_customer_metrics();
    call dwa_test.run_customer_metrics(1);

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
        raise exception 'metrics seed values mismatch, matched=%', l_ok;
    end if;

    call dwa_test.seed_customer_delta();
    call dwa_test.run_customer_metrics(1);

    select cnt_completed
    into l_cnt
    from customer_metrics
    where customer_id = 1;

    if l_cnt is distinct from 0 then
        raise exception 'metrics cancelled cnt_completed=%, expected 0', l_cnt;
    end if;

    raise notice 'metrics order grain and cancelled status: passed';

    call dwa_test.seed_customer_metrics();
    call dwa_test.run_incremental_passes(1);
    call dwa_test.snapshot_customer_metrics(true);
    call dwa_test.run_customer_metrics(1);

    l_diff := dwa_test.customer_metrics_xor();
    select count(*) into l_full from customer_metrics;
    select count(*) into l_inc from customer_metrics_inc;
    select count(*) into l_src from customers;

    if l_diff is distinct from 0 then
        raise exception 'metrics batches xor=%, expected 0', l_diff;
    end if;
    if l_full is distinct from l_src or l_full is distinct from l_inc then
        raise exception 'metrics batches counts full=% inc=% src=%', l_full, l_inc, l_src;
    end if;

    raise notice 'metrics incremental=full refresh (batches): passed';

    call dwa_test.seed_customer_metrics();
    call dwa_test.run_incremental_passes(null);
    call dwa_test.snapshot_customer_metrics(true);
    call dwa_test.run_customer_metrics(null);

    l_diff := dwa_test.customer_metrics_xor();
    select count(*) into l_full from customer_metrics;
    select count(*) into l_inc from customer_metrics_inc;
    select count(*) into l_src from customers;

    if l_diff is distinct from 0 then
        raise exception 'metrics no-batch xor=%, expected 0', l_diff;
    end if;
    if l_full is distinct from l_src or l_full is distinct from l_inc then
        raise exception 'metrics no-batch counts full=% inc=% src=%', l_full, l_inc, l_src;
    end if;

    raise notice 'metrics incremental=full refresh (no batches): passed';
end;
$check$;
