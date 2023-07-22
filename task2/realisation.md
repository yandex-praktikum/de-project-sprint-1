
## Создание представления после изменений команды Backend
```SQL
DROP VIEW IF EXISTS analysis.v_orderstatuslog;
CREATE VIEW analysis.v_orderstatuslog AS
SELECT id,
       order_id ,
       status_id,
       dttm 
FROM production.orderstatuslog;
```

## Наполнение витрины после изменений команды Backend
```SQL
TRUNCATE TABLE analysis.dm_rfm_segments;          
WITH lsd AS (SELECT order_id,
                    max(dttm) AS last_st_date
             FROM analysis.v_orderstatuslog
             GROUP BY 1),
prev_ord AS (SELECT vo.order_id,
                    user_id,
                    order_ts::DATE AS order_ts_date,
                    LAG(order_ts::DATE,1,order_ts::DATE) OVER (PARTITION BY user_id ORDER BY order_ts::DATE) AS prev_order_date,
                    PAYMENT
             FROM analysis.v_orders vo
             INNER JOIN lsd ON vo.order_id=lsd.order_id
             LEFT JOIN analysis.v_orderstatuses vo2 ON vo2.id = vo.status
             WHERE vo2.key='Closed' AND EXTRACT (YEAR FROM order_ts)>=2021),
rfm_raw AS (SELECT user_id,
                   MAX(order_ts_date)- MAX(prev_order_date) AS R,
                   COUNT(*) AS F,
                   AVG(PAYMENT) AS M
            FROM prev_ord po
            GROUP BY 1)
INSERT INTO analysis.dm_rfm_segments (user_id,
                                      recency,
                                      frequency,
                                      monetary_value)            
SELECT user_id,
       NTILE(5) OVER (ORDER BY R DESC) recency,
       NTILE(5) OVER (ORDER BY F ASC) as frequency,
       NTILE(5) OVER (ORDER BY M ASC) as monetary_value
FROM rfm_raw;
```
