# Проект 1
## Задача 1
### 1.1 Требования к целевой витрине
**dm_rfm_segments**
Витрина для RFM-сегментации клиентов в анализе сбыта по лояльности.
Глубина данных: с начала 2021 года.
Обновления не требуются. 
Находится в директории production.
Собирается из представлений из папки 
В расчетах учитываются только закрытые заказы с меткой Closed.

**Структура витрины:**
Ключи в агрегате
- User_id - ID клиента
- Recency (давность) — давность с момента последнего заказа (число от 1 до 5)
- Frequency (частота) — количество заказов (число от 1 до 5)
- Monetary Value (деньги) — сумма затрат клиента.user_activity_log (число от 1 до 5)

### 1.2 Используемые поля:
**таблица production.orders**
order_id - ID транзации
order_ts - дата и время транзакции
user_id - ID клиента
payment - сумма транзакции
status - статус транзации

таблица production.orderstatuses
id - код статуса
key - статус

### 1.3 Проанализируйте качество данных
В данных не обнаружены пропущенные и нулевые значения.
Таже отсутствтуют дубликаты.
Используемые инструменты:
IS NULL, 
= 0, 
DISTINCT

### 1.4 Подготовка витрины данных
**1.4.1 Сделаем представление для таблиц из production**
create view analysis.orders as select * from production.orders;
create view analysis.orderitems as select * from production.orderitems;
create view analysis.orderstatuses as select * from production.orderstatuses;
create view analysis.orderstatuslog as select * from production.orderstatuslog;
create view analysis.products as select * from production.products;
create view analysis.users as select * from production.users;

**1.4.2 DDL-запрос для создания витрины**
create table dm_rfm_segments(
client_id bigint PRIMARY KEY,
recency bigint not NULL,
frequency bigint not NULL, 
monetary_value bigint not NULL 
);

**1.4.3 SQL запрос для заполнения витрины**
-- добавим в таблицу данные, в каждом СТЕ фильтруем по статусу и дате
insert into dm_rfm_segments 
with date_group as (
	select user_id, -- используем оконную функцию для нумерации и сортировки
	 	   ROW_NUMBER() OVER (order by last_order) AS date_num
	from (select user_id,
		   	     max(order_ts) last_order
		  from analysis.orders
		  where status = 4 and date_part('year', order_ts) >= 2021
		  group by user_id) foo
),
amt_group as (
	select user_id, 
       	   ROW_NUMBER() OVER (order by count(order_id)) AS amt_num
	from analysis.orders
	where status = 4 and date_part('year', order_ts) >= 2021
	group by user_id
),
pay_group as (
	select user_id, 
       	   ROW_NUMBER() OVER (order by sum(payment)) AS pay_num
	from analysis.orders
	where status = 4 and date_part('year', order_ts) >= 2021
	group by user_id
)
select dg.user_id, 
	   case 
	   		when date_num <= 200 then 1
	   		when date_num <= 400 then 2
	   		when date_num <= 600 then 3
	   		when date_num <= 800 then 4
	   		when date_num <= 1000 then 5
	   end recency,
	   case 
	   		when amt_num <= 200 then 1
	   		when amt_num <= 400 then 2
	   		when amt_num <= 600 then 3
	   		when amt_num <= 800 then 4
	   		when amt_num <= 1000 then 5
	   end frequency,
	   case 
	   		when pay_num <= 200 then 1
	   		when pay_num <= 400 then 2
	   		when pay_num <= 600 then 3
	   		when pay_num <= 800 then 4
	   		when pay_num <= 1000 then 5
	   end monetary_value
from date_group dg join amt_group ag on dg.user_id = ag.user_id join pay_group pg on dg.user_id = pg.user_id;


## Задача 2
**1 . Поменяем представление analysis.orders**
-- создадим представление, объединив таблицу orders и OrderStatusLog. Учитываем только статус 4 и дату от 2021 года
create or replace view analysis.orders as select * from (
select user_id, po.order_id, order_ts, payment from production.orders po 
		 join (select order_id, max_time, status_id
	  		   from (select max(dttm) max_time
	  		   		 from production.OrderStatusLog
	  		   group by order_id) sub1 join production.OrderStatusLog
							   	   	   on sub1.max_time = production.orderstatuslog.dttm
	     where status_id = 4 and date_part('year', dttm) >= 2021) last_four
on po.order_ts = last_four.max_time and po.order_id = last_four.order_id) foo;

**2 . Уберем условия фильтрации**
/*добавим в таблицу агрегированные данные из представления
  фильтрация по дате и статусу уже произведены выше*/
insert into dm_rfm_segments 
with date_group as (
	select user_id, -- используем оконную функцию для нумерации и сортировки
	 	   ROW_NUMBER() OVER (order by last_order) AS date_num
	from (select user_id,
		   	     max(order_ts) last_order
		  from analysis.orders
		  group by user_id) foo
),
amt_group as (
	select user_id, 
       	   ROW_NUMBER() OVER (order by count(order_id)) AS amt_num
	from analysis.orders
	group by user_id
),
pay_group as (
	select user_id, 
       	   ROW_NUMBER() OVER (order by sum(payment)) AS pay_num
	from analysis.orders
	group by user_id
)
select dg.user_id, 
	   case 
	   		when date_num <= 200 then 1
	   		when date_num <= 400 then 2
	   		when date_num <= 600 then 3
	   		when date_num <= 800 then 4
	   		when date_num <= 1000 then 5
	   end recency,
	   case 
	   		when amt_num <= 200 then 1
	   		when amt_num <= 400 then 2
	   		when amt_num <= 600 then 3
	   		when amt_num <= 800 then 4
	   		when amt_num <= 1000 then 5
	   end frequency,
	   case 
	   		when pay_num <= 200 then 1
	   		when pay_num <= 400 then 2
	   		when pay_num <= 600 then 3
	   		when pay_num <= 800 then 4
	   		when pay_num <= 1000 then 5
	   end monetary_value
from date_group dg join amt_group ag on dg.user_id = ag.user_id join pay_group pg on dg.user_id = pg.user_id;

** Можно не менять, если код не громоздкий и нет потери в скорости. 


