# Витрина RFM

## 1.1. Выясните требования к целевой витрине.

Постановка задачи выглядит достаточно абстрактно - постройте витрину. Первым делом вам необходимо выяснить у заказчика детали. Запросите недостающую информацию у заказчика в чате.

Зафиксируйте выясненные требования. Составьте документацию готовящейся витрины на основе заданных вами вопросов, добавив все необходимые детали.

-----------
В базе 2 схемы: 
+ `production` - содержаться оперативные таблицы
+ `analysis` - схема, куда должна помещаться витрина данных


Витрина должна располагаться в схеме `analysis` и должна содержать следующие поля:
+ `user_id`
+ `recency` - число от 1 до 5
+ `frequency` - число от 1 до 5
+ `monetary_value` - число от 1 до 5

Данные с ___начала 2021 года___. 

Имя витрины `dm_rfm_segments`

Обновления витрины не нужны. 

Это заказ со статусом `Closed`.

## 1.2. Изучите структуру исходных данных.

Полключитесь к базе данных и изучите структуру таблиц.

Если появились вопросы по устройству источника, задайте их в чате.

Зафиксируйте, какие поля вы будете использовать для расчета витрины.

-----------

Для расчета витрины в основном нужна будет таблица `orders` из схемы `production`. Чтобы отфильтровать заказы со статусом `Closed`, на потребуется для фильтрации таблицы `orderstatuses` и `orderstatuslog`. 

Потребуются поля `order_id`, `user_id`, `payment` и `order_ts`. 


## 1.3. Проанализируйте качество данных

Изучите качество входных данных. Опишите, насколько качественные данные хранятся в источнике. Так же укажите, какие инструменты обеспечения качества данных были использованы в таблицах в схеме production.

-----------

Поле `order_id` является первичным ключом в таблице, поэтому он уникален. 

В таблице `orders` представлено 10 000 заказов. 

В необходимых нам полях пропусков нет. Значений, равных 0 в поле `payment` нет. 

Проблем с типом данных нет. 

В схеме `production` для обеспечения качества данных были использованы primary keу, имеющие ограничения по уникальности и not null значеним (в таблице `orders` первичным ключом является `order_id`,  в таблице `users` - `id`, в таблице `orderstatuslog` - `id`, в таблице `orderstatuses` - `id`, в таблице `orderitems` - `id`, в таблице `products` - `id`), так же были использованы внешние ключи (в таблице `orderstatuslog` внешними ключами стали `order_id` для таблицы `orders` и `status_id` для таблицы `orderstatuses` - `order_id` для таблицы `orders` и `product_id` для таблицы `products`). 


## 1.4. Подготовьте витрину данных

Теперь, когда требования понятны, а исходные данные изучены, можно приступить к реализации.

### 1.4.1. Сделайте VIEW для таблиц из базы production.**

Вас просят при расчете витрины обращаться только к объектам из схемы analysis. Чтобы не дублировать данные (данные находятся в этой же базе), вы решаете сделать view. Таким образом, View будут находиться в схеме analysis и вычитывать данные из схемы production. 

Напишите SQL-запросы для создания пяти VIEW (по одному на каждую таблицу) и выполните их. Для проверки предоставьте код создания VIEW.

```SQL
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
```

### 1.4.2. Напишите DDL-запрос для создания витрины.**

Далее вам необходимо создать витрину. Напишите CREATE TABLE запрос и выполните его на предоставленной базе данных в схеме analysis.

```SQL
create table analysis.dm_rfm_segments (
    user_id int4 not null primary key,
    recency int2,
    frequency int2,
    monetory_value int2
)
```

### 1.4.3. Напишите SQL запрос для заполнения витрины

Наконец, реализуйте расчет витрины на языке SQL и заполните таблицу, созданную в предыдущем пункте.

Для решения предоставьте код запроса.

```SQL
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
```



