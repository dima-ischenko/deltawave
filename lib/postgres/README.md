# PostgreSQL and Greenplum

[Deploy](deploy.md) into a schema and put that schema on `search_path`, or pass `-v dwa_schema=name` when you run `demo/postgres/run.sql`. Methods and parameters: [root README](../../README.md). From SQL, call the functions with `select`. From PL/pgSQL, use `perform`. Named arguments use `:=` (PostgreSQL 9.4 / Greenplum 6); `=>` needs PostgreSQL 9.5+.

Without batches, one refresh reads `dwa_keys_tmp`. With batches, each refresh reads `dwa_batch_tmp`. `MERGE` needs PostgreSQL 15+. Greenplum has no `MERGE`: use `DELETE` then `INSERT`.

```sql
do $run$
declare
    v_change_date timestamp := clock_timestamp();
    v_merged bigint;
begin
    perform dwa_initialize(p_target_table := 'customer_metrics', p_data_slice := 'all');

    perform dwa_capture_delta(p_source_table := 'customers', p_sql := $sql$
        select id::text as pk_1,
               updated_at as watermark
        from customers
        where updated_at > :since
    $sql$);

    perform dwa_capture_delta(p_source_table := 'orders', p_sql := $sql$
        select customer_id::text as pk_1,
               max(updated_at) as watermark
        from orders
        where updated_at > :since
        group by customer_id
    $sql$);

    perform dwa_capture_delta(p_source_table := 'order_items', p_sql := $sql$
        with changed_items as (
            select order_id, updated_at
            from order_items
            where updated_at > :since
        )
        select o.customer_id::text as pk_1,
               max(ci.updated_at) as watermark
        from changed_items ci
        join orders o on o.id = ci.order_id
        group by o.customer_id
    $sql$);

    perform dwa_prepare_batches(p_batch_size := 5000);

    while dwa_next_batch() loop
        delete from customer_metrics t
        using (
            select pk_1::integer as customer_id
            from dwa_batch_tmp
            group by pk_1
        ) s
        where t.customer_id = s.customer_id;

        insert into customer_metrics (
            customer_id, min_amount, max_amount, avg_amount, sum_amount,
            last_order_id, cnt_completed, mt_change_date
        )
        with changed as (
            select pk_1::integer as customer_id
            from dwa_batch_tmp
            group by pk_1
        ),
        order_amount as (
            select c.id as customer_id,
                   o.id as order_id,
                   o.order_date,
                   o.status,
                   sum(round(oi.quantity * oi.price * (1 - o.order_discount), 2)) as amount
            from customers c
            join changed ch on ch.customer_id = c.id
            left join orders o on o.customer_id = c.id
            left join order_items oi on oi.order_id = o.id
            group by c.id, o.id, o.order_date, o.status
        )
        select customer_id,
               min(amount) as min_amount,
               max(amount) as max_amount,
               round(avg(amount), 2) as avg_amount,
               sum(amount) as sum_amount,
               (array_agg(order_id order by order_date desc, order_id desc))[1] as last_order_id,
               count(case when status = 'completed' then 1 end) as cnt_completed,
               v_change_date
        from order_amount
        group by customer_id;

        get diagnostics v_merged = row_count;
        perform dwa_finish_batch(v_merged);
    end loop;

    perform dwa_finalize();
end;
$run$;
```

The same script is `demo/postgres/run.sql`. See [`demo/README.md`](../../demo/README.md).

The functions do not commit. Commit after each `dwa_finish_batch` and after `dwa_finalize`. A rollback of `dwa_initialize` drops the session temp tables. Pass `GET DIAGNOSTICS ROW_COUNT` of the `INSERT` as `p_merged`.

On Greenplum 6 and 7 use the same [deploy](deploy.md).
