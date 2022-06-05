 CREATE TABLE analysis.tmp_rfm_recency (
 user_id INT NOT NULL PRIMARY KEY,
 recency INT NOT NULL CHECK(recency >= 1 AND recency <= 5)
);

  -- Заполнение таблицы tmp_rfm_recency
insert into tmp_rfm_recency (
with q1 as (
  select *,
  row_number() over(order by q.timedelta) user_rate -- Ранжируем пользователей по дате последнего заказа
  from(
	select -- выбираем только последние закрытые заказы по пользователю
	  sq.user_id,
	  sq.timedelta
	from (  
		select *,
		  localtimestamp-order_ts timedelta, 
		  row_number() over(partition by user_id order by order_ts desc) ord_rate 
	  	from analysis.orders 
	  	where status = (select id from analysis.orderstatuses where key = 'Closed')
		   ) sq
	where sq.ord_rate = 1
		   ) q right join analysis.users u on u.id = q.user_id
)
select
q1.id as user_id,
--q1.user_rate,
case when q1.user_rate >= 0.8 *(select max(q1.user_rate) from q1) then 1
	when q1.user_rate >= 0.6 *(select max(q1.user_rate) from q1) then 2
	when q1.user_rate >= 0.4 *(select max(q1.user_rate) from q1) then 3
	when q1.user_rate >= 0.2 *(select max(q1.user_rate) from q1) then 4
	else 5
end as recency 
from q1
  );
