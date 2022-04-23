# Проект 1
## Описание проекта
В базе две схемы: production и analysis. В схеме production содержатся оперативные таблицы. В схему analysis необходимо разместить витрину, описание которой представлено ниже.

Заказчик: компания, которая разрабатывает приложение по доставке еды.
Цель проекта: построить витрину для RFM-классификации в схеме analysis. Для анализа нужно отобрать только успешно выполненные заказы (по статусом Closed).
Описание:
  - Наименование витрины: dm_rfm_segments
  - БД: Витрина дожна располагаться в той же базе, что и исходники. 
  - Схема: Витрина дожна располагаться в схеме analysis.
  - Структура: Витрина должна состоять из таких полей:
        user_id
        recency (число от 1 до 5)
        frequency (число от 1 до 5)
        monetary_value (число от 1 до 5)
  - Глубина данных: с начала 2021 года
  - Частота обновления данных: обновления не нужны

## Проверка качества данных
- доступы ко всем таблицам есть
- все колонки на месте

```SQL
SELECT *
FROM pg_catalog.pg_tables
WHERE schemaname = 'production' AND tablename IN ('orderitems','orders','orderstatuses','orderstatuslog','products','users');
```

- В таблице orders данные только за 2 месяца февраль и март 2022 года
```SQL
SELECT EXTRACT (YEAR FROM order_ts) order_ts_date,
       EXTRACT (month FROM order_ts) order_ts_date,
       SUM(payment)
FROM production.orders vo
GROUP BY 1,
         2
```

- Месяцы тоже неполные. Заказы начинаются с середины февраля и заканчиваются в середине марта
```SQL
SELECT DATE_TRUNC('day',order_ts)::DATE as order_ts_date,
       COUNT(user_id),
       SUM(PAYMENT)
FROM  production.orders vo
LEFT JOIN production.orderstatuses vo2 on vo2.id = vo.status
WHERE vo2.key='Closed' AND EXTRACT (YEAR FROM order_ts)>=2021
GROUP BY 1
```

- Минимальное значение суммы заказа сильно отличается от среднего значения, но в динамике оно постоянное. Динамика среднtего значения и максимального сильно не меняется.
Значения NULL отсутствуют в колонках user_id, order_id, status 
```SQL
WITH cte AS (SELECT user_id,
                    order_id,
                    status,
                    DATE_TRUNC('day',order_ts)::DATE as order_ts_date,
                    SUM(PAYMENT) AS sum_payment
       FROM  production.orders vo
       LEFT JOIN production.orderstatuses vo2 ON vo2.id = vo.status
       WHERE vo2.key='Closed' AND EXTRACT (YEAR FROM order_ts)>=2021
       GROUP BY 1,2,3,4)
SELECT order_ts_date,
       SUM(sum_payment)/COUNT(order_id) AS avg_order,
       MIN(sum_payment) AS sum_payment_min,
       MAX(sum_payment) AS sum_payment_max,
       AVG(sum_payment) AS sum_payment_avg,
       COUNT(CASE WHEN user_id IS NULL THEN 1 END) AS user_id_null,
       COUNT(CASE WHEN order_id IS NULL THEN 1 END) AS order_idnull,
       COUNT(CASE WHEN status IS NULL THEN 1 END) AS order_idnull
FROM cte
GROUP BY 1;
```
