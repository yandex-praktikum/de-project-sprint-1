# Проект 1
Опишите здесь поэтапно ход решения задачи. Вы можете ориентироваться на тот план выполнения проекта, который мы предлагаем в инструкции на платформе.

Описание проекта
Ваш заказчик — компания, которая разрабатывает приложение по доставке еды.
Что сделать:
Вам необходимо составить витрину для RFM-классификации пользователей приложения.

Зачем: 
RFM (от англ. Recency Frequency Monetary Value) — способ сегментации клиентов, при котором анализируют их лояльность: как часто, на какие суммы и когда в последний раз тот или иной клиент покупал что-то.

Каждого клиента оценивают по трём факторам:
	•	Recency (пер. «давность») — сколько времени прошло с момента последнего заказа.
	•	Frequency (пер. «частота») — количество заказов.
	•	Monetary Value (пер. «денежная ценность») — сумма затрат клиента.

		Фактор Recency измеряется по последнему заказу. Распределите клиентов по шкале от одного до пяти, где значение 1 получат те, кто либо вообще не делал заказов, либо делал их очень давно, а 5 — те, кто заказывал относительно недавно.
		Фактор Frequency оценивается по количеству заказов. Распределите клиентов по шкале от одного до пяти, где значение 1 получат клиенты с наименьшим количеством заказов, а 5 — с наибольшим.
		Фактор Monetary оценивается по потраченной сумме. Распределите клиентов по шкале от одного до пяти, где значение 1 получат клиенты с наименьшей суммой, а 5 — с наибольшей.
		
Проверьте, что количество клиентов в каждом сегменте одинаково. Например, если в базе всего 100 клиентов, то 20 клиентов должны получить значение 1, ещё 20 — значение 2 и т. д.

1. Постройте витрину для RFM-анализа
1.1. Выясните требования к целевой витрине

Требования: 
располагаться в той же базе в схеме analysis, данные с начала 2021 года, обновления не нужны.
Название dm_rfm_segments

Необходимая структура:
Витрина должна состоять из таких полей:
	⁃	user_id
	⁃	recency (число от 1 до 5)
	⁃	frequency (число от 1 до 5)
	⁃	monetary_value (число от 1 до 5)

Для анализа нужно отобрать только успешно выполненные заказы - Это заказ со статусом Closed


1.2. Изучите структуру исходных данных
Проверим:
		- нужные таблицы есть в базе и доступны для чтения;
		- структура таблиц соответствует описанию;
		- в таблицах есть все поля, чтобы построить необходимые метрики.

Проанализируем источники на предмет достаточности в нём полей, чтобы построить витрину:
	•	user_id  - из таблицы production.orders  поле user_id, orderstatuses
	•	recency - из таблицы production.orders  поле user_id, orderstatuses, order_ts
	•	Frequency - из таблицы production.orders  поле user_id,  orderstatuses, order_id
	•	monetary_value -  из таблицы production.orders  поле user_id,  orderstatuses, payment

1.3. Проанализируйте качество данных
Основная таблица, необходимая для построения витрины - production.orders. 
Проверим данные в ней. 

а) Определение дублей
Сравним общее количество записей с количеством уникальных значений по ключу
orders_id - дублей нет

Б) Поиск пропущенных значений
Пропущенных значений нет

В) Проверка типов данных
В таблице orders все поля имеют корректные типы данных

Для обеспечения качества данных: 
- есть ограничения-проверки -  CHECK ((cost = (payment + bonus_payment)))
- есть ограничения NOT NULL - все поля
- Первичный ключ  для поля order_id
- Внешние ключи: order_id (связка с таблицей orderitems полем order_id), product_id (связка с таблицей orderitems полем product_id) 

1.4. Подготовьте витрину данных
	•	Необходимо написать SQL-запросы, чтобы создать пять представлений в схеме analysis, и выполните их. 

create view analysis.v_orderitems as
select * from production.orderitems;

create view analysis.v_orders as
select * from production.orders;

create view analysis.v_orderstatuses as
select * from production.orderstatuses;

create view analysis.v_orderstatuslog as
select * from production.orderstatuslog;

create view analysis.v_products as
select * from production.products; 

create view analysis.v_users as
select * from production.users; 


	•	Напишите запрос для создания и заполнения витрины
CREATE table IF NOT EXISTS  analysis.dm_rfm_segments 
(
	user_id integer not null,
	recency  integer not null,
	frequency integer not null,
	monetary_value integer not null
);
insert into analysis.dm_rfm_segments (
user_id, 
  recency,
  frequency,
  monetary_value
)
with recency_ex as (
select 
user_id,
max(order_ts),
EXTRACT(DAY from now()-max(order_ts)) AS DateDifference
from analysis.v_orders
where status = 4 -- Closed
group by 1
order by 1 desc), 
recency as (
select user_id,
  case when row_n < 200 then 1
	when row_n between 200 and 399 then 2
	when row_n between 400 and 599 then 3
	when row_n between 600 and 799 then 4
	else 5 end as recency
from
(
select *,
ROW_NUMBER () OVER (
      order BY datedifference) as row_n
  from recency_ex) t),
  frequency_ex as 
  (
  select
 user_id,
count(order_id) as cnt_order
from analysis.v_orders
where status = 4 -- Closed
group by 1
  ),
   frequency as (
select user_id,
  case when row_n_fr < 200 then 1
	when row_n_fr between 200 and 399 then 2
	when row_n_fr between 400 and 599 then 3
	when row_n_fr between 600 and 799 then 4
	else 5 end as frequency
from
(
select *,
ROW_NUMBER () OVER (
      order BY cnt_order) as row_n_fr
  from frequency_ex) f),
   monetary_ex as 
   (
   select
 user_id,
sum(payment) as total
from analysis.v_orders
where status = 4 -- Closed
group by 1
   ), 
   monetary as (
select user_id,
  case when row_n_mon < 200 then 1
	when row_n_mon between 200 and 399 then 2
	when row_n_mon between 400 and 599 then 3
	when row_n_mon between 600 and 799 then 4
	else 5 end as monetary
from
(
select *,
ROW_NUMBER () OVER (
      order BY total) as row_n_mon
  from monetary_ex) m)
  select r.user_id, 
  recency,
  frequency,
  monetary
  from recency r
 inner join frequency f on (r.user_id = f.user_id)
 inner join monetary m on (r.user_id = m.user_id);


2. Необходимо внести изменения в то, как формируется представление analysis.Orders: вернуть в него поле status. Значение в этом поле должно соответствовать последнему по времени статусу из таблицы production.OrderStatusLog.
CREATE OR REPLACE VIEW analysis.v_orders
AS
select 
o.order_id, 
o.order_ts,
o.user_id, 
o.bonus_payment,
o.payment,
o."cost",
o.bonus_grant, 
x.status_id
 from
 production.orders o
 left join 
 (select order_id, status_id
 from 
 (
 select order_id, status_id,dttm,
 row_number  () OVER (
 	partition by order_id
      order BY dttm desc) as row_dt
 from production.orderstatuslog )r
where row_dt = 1
 ) as x on (o.order_id = x.order_id)
