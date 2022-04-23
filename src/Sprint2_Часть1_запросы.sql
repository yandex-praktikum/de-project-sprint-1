CREATE OR REPLACE VIEW analysis.orderitems (
	id ,
	product_id,
	order_id,
	"name",
	price,
	discount,
	quantity
) 
AS 
SELECT
id,
product_id,
order_id,
"name",
price,
discount,
quantity
FROM production.orderitems;

CREATE OR REPLACE VIEW analysis.orders (
order_id,
order_ts,
user_id,
bonus_payment,
payment,
cost,
bonus_grant,
status)
AS 
SELECT
order_id,
order_ts,
user_id,
bonus_payment,
payment,
cost,
bonus_grant,
status
FROM production.orders;

CREATE OR REPLACE VIEW analysis.orderstatuses (
id, key)
AS 
SELECT id, key FROM production.orderstatuses;


CREATE OR REPLACE VIEW analysis.products (
id,
name,
price)
AS 
SELECT id, name, price
FROM production.products;

CREATE OR REPLACE VIEW analysis.users (
id,
name,
login)
AS 
SELECT id, login, name
FROM production.users;

--создание таблицы
DROP TABLE analysis.dm_rfm_segments;
CREATE TABLE analysis.dm_rfm_segments (
id SERIAL PRIMARY KEY,
user_id INT UNIQUE NOT NULL,
recency INT CHECK (recency > 0),
frequency INT CHECK (frequency > 0),
monetary_value INT CHECK (monetary_value > 0)
);


--запрос для заполнения таблицы
INSERT INTO analysis.dm_rfm_segments (user_id, recency, frequency, monetary_value)
WITH a AS (SELECT u.id AS user_id, rfm.rec_ts, rfm.freq_count, rfm.mon_sum
FROM analysis.users u
LEFT JOIN (
SELECT user_id, MAX(order_ts) rec_ts, COUNT(order_id) freq_count, SUM(payment) mon_sum
FROM analysis.orders
WHERE status = (SELECT id FROM analysis.orderstatuses WHERE key = 'Closed') AND
EXTRACT(YEAR FROM order_ts) >=2021
GROUP BY user_id) AS rfm ON rfm.user_id = u.id),
b AS (
--считаем rfm
SELECT a.user_id, 
--a.rec_ts, 
NTILE(5) OVER (ORDER BY a.rec_ts DESC) AS recency,
--a.freq_count, 
NTILE(5) OVER (ORDER BY a.freq_count DESC) AS frequency,
--a.mon_sum, 
NTILE(5) OVER (ORDER BY a.mon_sum DESC) AS monetary_value
FROM a)
SELECT b.user_id, b.recency, b.frequency, b.monetary_value
FROM b;