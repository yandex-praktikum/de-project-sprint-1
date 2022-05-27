--Задание 1
drop table if exists public.shipping_country_rates;

create table public.shipping_country_rates(
shipping_country_id serial ,
 shipping_country text,
 shipping_country_base_rate numeric(14,
3),
 primary key (shipping_country_id) );

insert
    into
    public.shipping_country_rates (shipping_country,
    shipping_country_base_rate)
 select
    distinct shipping_country,
    shipping_country_base_rate
from
    shipping;


--Задание 2

create table public.shipping_agreement (
agreementid BIGINT ,
agreement_number varchar(200),
agreement_rate numeric(14,
2),
agreement_commission numeric(14,
2),
primary key(agreementid) );

insert
    into
    public.shipping_agreement (agreementid,
    agreement_number,
    agreement_rate,
    agreement_commission)
select
    distinct (regexp_split_to_array(vendor_agreement_description, ':'))[1]::BIGINT as agreementid,
    (regexp_split_to_array(vendor_agreement_description, ':'))[2]::varchar as agreement_number,
    (regexp_split_to_array(vendor_agreement_description, ':'))[3]::numeric as agreement_rate,
    (regexp_split_to_array(vendor_agreement_description, ':'))[4]::numeric as agreement_commission
from
    shipping ;
--select * from shipping_agreement sa limit 10;
--Задание 3 
 
drop table if exists shipping_transfer;

create table shipping_transfer ( 
 transfer_type_id serial ,
 transfer_type varchar(2),
transfer_model text,
shipping_transfer_rate numeric(14,
3),
primary key(transfer_type_id));

insert
    into
    public.shipping_transfer (transfer_type,
    transfer_model,
    shipping_transfer_rate)
select
    distinct 
(regexp_split_to_array(shipping_transfer_description, ':'))[1]::varchar as transfer_type,
    (regexp_split_to_array(shipping_transfer_description, ':'))[2]::text as transfer_model,
    shipping_transfer_rate
from
    shipping;
--select * from  public.shipping_transfer limit 10;
--Задача 4

drop table if exists public.shipping_info;

create table public.shipping_info (
  shippingid BIGINT,
  shipping_plan_datetime timestamp, 
  payment_amount numeric(14,
2), 
  vendorid INT,
  transfer_type_id int ,
  shipping_country_id int ,
  agreementid int ,
  
primary key(shippingid),
foreign key(transfer_type_id) references shipping_transfer (transfer_type_id),
foreign key(shipping_country_id) references shipping_country_rates (shipping_country_id),
foreign key(agreementid) references shipping_agreement (agreementid)
);

insert
    into
    public.shipping_info 
  select
    distinct 
  shippingid,
    shipping_plan_datetime,
    payment_amount,
    vendorid,
    transfer_type_id,
    shipping_country_id,
    agreementid
from
    shipping s
left join shipping_transfer on
    (regexp_split_to_array(shipping_transfer_description, ':'))[1]::varchar = transfer_type
    and 
(regexp_split_to_array(shipping_transfer_description, ':'))[2]::text = transfer_model
join public.shipping_country_rates scr on
    s.shipping_country = scr.shipping_country
join public.shipping_agreement sa on
    (regexp_split_to_array(vendor_agreement_description, ':'))[1]::BIGINT = agreementid
    and 
(regexp_split_to_array(vendor_agreement_description, ':'))[2]::varchar = agreement_number
    and 
(regexp_split_to_array(vendor_agreement_description, ':'))[3]::numeric = agreement_rate
    and 
(regexp_split_to_array(vendor_agreement_description, ':'))[4]::numeric = agreement_commission  
   

--- select count(*) from  public.shipping_info
--Задание 5
drop table if exists public.shipping_status;

create table public.shipping_status (
	shippingid int,
	status text ,
	state text,
	shipping_start_fact_datetime timestamp,
	shipping_end_fact_datetime timestamp
   
  );
/*
with tt as (
select
    shippingid,
    status ,
    state,
    state_datetime as shipping_start_fact_datetime,
    null as shipping_end_fact_datetime
from
    shipping
where
    state = 'booked'

select
    shippingid,
    status ,
    state,
    null as shipping_start_fact_datetime,
    state_datetime as shipping_end_fact_datetime
from
    shipping
where
    state = 'recieved')
  
  insert
    into
    shipping_status 
  select
    shippingid,
    status,
    state,
    shipping_start_fact_datetime,
    shipping_end_fact_datetime
from
    tt*/
------------ исправление 5 го ----------- 
insert
    into
    shipping_status 
  select
    sub1.shippingid,
    sub1.status,
    sub1.state,
    sub1.shipping_start_fact_datetime,
    sub2.shipping_end_fact_datetime
from
    (select
    shippingid,
    status ,
    state,
    state_datetime as shipping_start_fact_datetime,
    null as shipping_end_fact_datetime
from
    shipping
where
    state = 'booked') as sub1 left join (select
                                          shippingid,
                                          status ,
                                          state,
                                          null as shipping_start_fact_datetime,
                                          state_datetime as shipping_end_fact_datetime
                                          from
                                              shipping
                                          where
                                              state = 'recieved') as sub2 on sub1.shippingid=sub2.shippingid

----------------------------------------- 
    -- select * from tt  where shippingid=543
    --Задание 6 
	/*drop view if exists public.shipping_datamart;*/
	create view public.shipping_datamart as 
	
	
/*with tt3 as (
    select
        distinct 
    ss1.shippingid,
        ss1.shipping_end_fact_datetime,
        ss2.shipping_start_fact_datetime
    from
        shipping_status ss1
    left join shipping_status ss2 on
        ss1.shippingid = ss2.shippingid
    where
        ss1.shipping_end_fact_datetime is not null
        and ss2.shipping_start_fact_datetime is not null
    order by
        shippingid ,
        shipping_end_fact_datetime ),*/
    with tt4 as (
    select
        shippingid,
        status
    from
        shipping s2
    where
        status = 'finished')

select distinct
    si.shippingid,
    si.vendorid,
    transfer_type,
    date_part('day', age(shipping_status.shipping_end_fact_datetime, shipping_status.shipping_start_fact_datetime)) as full_day_at_shipping,
    case
        when shipping_status.shipping_end_fact_datetime > s.shipping_plan_datetime then 1
        else 0
    end as is_delay,
    case
        when tt4.status is null then 0
        else 1
    end as is_shipping_finish,
    case
        when shipping_status.shipping_end_fact_datetime >s.shipping_plan_datetime then date_part('day', age(shipping_status.shipping_end_fact_datetime, s.shipping_plan_datetime))
        else 0
    end as delay_day_at_shipping,
    s.payment_amount,
    (s.payment_amount * (scr.shipping_country_base_rate + sa.agreement_rate + st.shipping_transfer_rate)) as vat,
    s.payment_amount * sa.agreement_commission as profit
from
    shipping_info si
left join shipping_transfer st on
    si.transfer_type_id = st.transfer_type_id
left join shipping_status on
    shipping_status.shippingid = si.shippingid
left join shipping s on
    s.shippingid = si.shippingid
left join tt4 on
    si.shippingid = tt4.shippingid
left join shipping_agreement sa on
    si.agreementid = sa.agreementid
left join shipping_country_rates scr on
    si.shipping_country_id = scr.shipping_country_id