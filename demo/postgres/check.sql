\if :{?dwa_schema}
set search_path to :"dwa_schema", "$user", public;
\endif


-- Result of the last run.sql.
select (select count(*) from customers) as customers,
       (select count(*) from orders) as orders,
       (select count(*) from order_items) as order_items,
       (select count(*) from customer_metrics) as customer_metrics;

select * from customer_metrics order by customer_id limit 20;

select source_table, watermark, updated_at
from dwa_watermark
where target_table = 'customer_metrics'
  and data_slice = 'all'
order by source_table;
