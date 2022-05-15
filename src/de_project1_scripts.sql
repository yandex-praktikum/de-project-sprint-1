-- create view in analysis schema
create view analysis.dm_row_payments as 
select 
 order_id,
 order_ts,
 user_id, 
 payment
from production.orders
where status in (
 select
    id
 from production.orderstatuses 
   where key = 'Closed'
)

-- create table view in analysis schema for RFM datamart
create table analysis.dm_rfm_segments (
    user_id int4 not null primary key,
    recency int2,
    frequency int2,
    monetory_value int2
)

-- insert data in RFM datamart
insert into analysis.dm_rfm_segments (
    with last_order as (
        select
            user_id,
            order_ts,
            round((extract(epoch from order_ts - lag(order_ts) over(partition by user_id order by order_ts)) / 3600)) as last_order_ts_diff,
            order_ts - max(order_ts) over(partition by user_id) as max_order_ts_diff
        from analysis.dm_row_payments
    ),
    f_and_m as (
        select
            user_id,
            ntile(5) over(order by count(distinct order_id)) as frequency,
            ntile(5) over(order by sum(payment)) as monetary_value
        from analysis.dm_row_payments
        group by user_id
        order by user_id
    )
    select
        last_order.user_id,
        ntile(5) over(order by coalesce(last_order.last_order_ts_diff, 0)) as recency,
        f_and_m.frequency,
        f_and_m.monetary_value
    from last_order
    left join f_and_m on last_order.user_id = f_and_m.user_id
    where last_order.max_order_ts_diff = '00:00:00' 
    order by user_id
)


-- correction scripot after change reletionships in production schema
create or replace view analysis.dm_row_payments as 
select 
 order_id,
 order_ts,
 user_id, 
 payment
from production.orders
where order_id in (
 select
  order_id
 from production.orderstatuslog
 where status_id = (
  select
     id
  from production.orderstatuses 
    where 
     key = 'Closed'
 )
)


© 2022 GitHub, Inc.
Terms
Privacy
Security
Status
Docs
Contact GitHub
Pricing
API
Training
Blog
About
