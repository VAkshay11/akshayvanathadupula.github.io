SET search_path TO amazon_brazil;

--ANALYSIS -1 Q1

select payment_type, 
round(avg(payment_value)) as rounded_avg_payment
from payments
group by payment_type
order by rounded_avg_payment asc

--ANALYSIS -1 Q2

select payment_type, 
       round(
           (count( distinct order_id)::numeric /
           (select count( distinct order_id) from payments)) * 100
       , 1) 
	   as percentage_orders
from payments
group by payment_type
order by percentage_orders desc

-- I used distinct to select a single unique order Id; 
--which gives exact number used with respective payment type

--ANALYSIS -1 Q3

SELECT 
    p.product_id, 
    o.price
FROM product AS p
INNER JOIN order_items AS o
    ON o.product_id = p.product_id
WHERE o.price BETWEEN 100 AND 500
  AND p.product_category_name ILIKE '%Smart%'
ORDER BY o.price DESC

--ANALYSIS -1 Q4

select extract(month from o.order_purchase_timestamp) as month,
--Need to check why date trunc and extract behaving in different way!

select date_trunc('month', o.order_purchase_timestamp) as month,
round(sum(op.price)) as total_sales
from orders as o
join
order_items as op
on
o.order_id=op.order_id
group by month
order by total_sales desc
limit 3

--ANALYSIS -1 Q5

select
p.product_category_name as product_category_name,
max(o.price)-min(o.price) as price_difference
from product as p
inner join
order_items as o
on
p.product_id=o.product_id
where p.product_category_name is not null
and 
o.price is not null
group by p.product_category_name
having max(o.price)-min(o.price)>500

--ANALYSIS -1 Q6

select payment_type,
round(stddev(payment_value),2) as std_deviation
from payments
group by payment_type
order by stddev(payment_value) asc

--ANALYSIS -1 Q7

select product_id, product_category_name
from product
where product_category_name is null
   or length(trim(product_category_name)) = 1

--ANALYSIS -2 Q1

select s.order_value_segment as order_value_segment, 
s.payment_type as payment_type,
count(*) as count
from
(
select 
case when price<200 then 'low'
when price >= 200 and price< 1000 then 'medium'
else 'high'
end 
as order_value_segment,
payment_type from payments as p
join order_items as o
on p.order_id=o.order_id
) s
group by order_value_segment, payment_type
order by count desc

--ANALYSIS -2 Q2

select p.product_category_name as product_category_name,
max(o.price) as max_price,
min(o.price) as min_price, 
round(avg(o.price),2) as avg_price
from order_items as o
join
product as p
on 
o.product_id=p.product_id
group by p.product_category_name
order by avg_price desc

--ANALYSIS -2 Q3

select c.customer_unique_id as customer_unique_id, 
count(o.order_id) as total_orders
from customers as c
join 
orders as o
on
c.customer_id=o.customer_id
group by c.customer_unique_id
having count(o.order_id)>1
order by total_orders desc

--ANALYSIS -2 Q4

with customers as 
(
select c.customer_unique_id as customer_unique_id, 
count(o.order_id) as total_orders ,
case when count(o.order_id)=1 then 'New'
when count(o.order_id) between 2 and 4 then 'Returning'
when count(o.order_id)>4 then 'Loyal'
end as
customer_type
from orders as o
join
customers as c
on c.customer_id=o.customer_id
group by customer_unique_id
)
select customer_unique_id, customer_type from customers

--ANALYSIS -2 Q5

select p.product_category_name as product_category_name,
sum(o.price) as total_revenue
from product as p
join
order_items as o
on
p.product_id=o.product_id
group by p.product_category_name
order by total_revenue desc
Limit 5

--ANALYSIS -3 Q1

SELECT 
    CASE 
        WHEN month_number IN (3, 4, 5) THEN 'Spring'
        WHEN month_number IN (6, 7, 8) THEN 'Summer'
        WHEN month_number IN (9, 10, 11) THEN 'Autumn'
        ELSE 'Winter'
    END AS season,
    sum(price) AS total_sales
FROM (
    SELECT 
        op.price,
        EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month_number
    FROM orders as o
	join order_items as op
	on o.order_id=op.order_id
) sub
GROUP BY season
ORDER BY total_sales desc


--ANALYSIS -3 Q2

--With CTE

with temp_table as
(
select product_id, count(*) as total_quantity_sold from order_items
group by product_id
)
select * from temp_table
where total_quantity_sold> (select avg(total_quantity_sold) from temp_table)
order by total_quantity_sold desc

--With Subquery

select product_id, count(*) as total_quantitiy_sold from order_items
group by product_id
having count(*)>
(
select avg(total_quantity_sold) from
(
select product_id, count(*) as total_quantity_sold
from order_items
group by product_id
) as avg_table
)
order by total_quantitiy_sold desc


--ANALYSIS -3 Q3

with monthly_sales as 
(
select order_id,
date_trunc('month', order_purchase_timestamp)::date AS month
from orders
 WHERE order_purchase_timestamp >= '2018-01-01'
    AND order_purchase_timestamp < '2019-01-01'
)
select monthly_sales.month, 
sum(p.payment_value) as total_revenue 
from monthly_sales
join
payments as p
on
p.order_id=monthly_sales.order_id
group by monthly_sales.month
order by monthly_sales.month asc

--ANALYSIS -3 Q4

with customer_classification as
(
select c.customer_unique_id,
case
when count(o.order_id) between 1 and 2 then 'Occasional'
when count(o.order_id) between 3 and 5 then 'Regular'
when count(o.order_id)>5 then 'Loyal'
end as customer_type,
count(o.order_id) as count_of_orders from customers as c
join
orders as o
on
c.customer_id=o.customer_id
group by c.customer_unique_id
)
select customer_type, count(*) as count
from customer_classification
group by customer_type

--ANALYSIS -3 Q5

with order_totals as
(
select order_id,
sum(payment_value) as order_total
from payments
group by order_id
),
/*
Why are we using SUM(payment_value) grouped by order_id?

In the payments table, one order_id can appear multiple times
because customers may pay in installments (EMI).
Because in schema as we see there's a column called payment sequential

Example:

payments table
order_id | payment_sequential | payment_value
------------------------------------------------
101      | 1                  | 100
101      | 2                  | 150
102      | 1                  | 200

Order 101 was paid in 2 installments (100 + 150).
If we directly average payment_value, we would treat
those as separate rows, which is incorrect.

So first, we reconstruct the real order value:

order_totals:
order_id | order_total
-----------------------
101      | 250
102      | 200
--select order_id, order_total from order_totals
Now each order appears only once.
Then we compute AVG(order_total) per customer,
which gives the true Average Order Value.
*/
/*
We first aggregate payments at the order level because
one order_id can have multiple payment rows (e.g., installments).

If we directly average payment_value, we would be averaging
installments instead of full orders.

So:
1) SUM(payment_value) → gives total value per order
2) AVG(order_total) → gives true average order value per customer
*/

order_value as 
(
select o.customer_id, round(avg(ot.order_total),2) as average_order_value,
dense_rank() over (order by round(avg(ot.order_total),2) desc)
as customer_rank
from order_totals as ot
join orders as o
on
o.order_id=ot.order_id
group by o.customer_id
)
select customer_id, average_order_value,
customer_rank
from order_value
where customer_rank<=20

--ANALYSIS -3 Q6

with recursive main_table as (
    select 
        oi.product_id,
        TO_CHAR(o.order_purchase_timestamp, 'Month') AS sale_month, 
        oi.price,
        row_number() over(partition by oi.product_id order by o.order_purchase_timestamp)
		as row_num
    from order_items as oi
    join orders as o 
    using (order_id)
),
table_cte as (
    select 
        product_id, 
        sale_month, 
        price, 
        price::numeric as cumulative_sales, 
        row_num  -- Base query
    from main_table 
    where row_num = 1
    union all
    select 
        m.product_id, 
        m.sale_month, 
        m.price, 
        m.price + t.cumulative_sales, 
        m.row_num  -- Recursive Query
    from main_table as m 
    join table_cte as t 
    using (product_id)
    where m.row_num = t.row_num + 1
)

select 
    product_id, 
    sale_month, 
    sum(cumulative_sales) over (partition by product_id order by sale_month)
	as total_sales
from table_cte
order by product_id, row_num

--ANALYSIS -3 Q7

with total_sales as
(
select p.payment_type,
date_trunc('month', o.order_purchase_timestamp):: date as sale_month,
sum(p.payment_value) as monthly_sales,
lag(sum(p.payment_value))
over (partition by payment_type
order by date_trunc('month', o.order_purchase_timestamp):: date asc)
as monthly_change
from payments as p
join
orders as o
on
p.order_id=o.order_id
where order_purchase_timestamp >= '2018-01-01'
and order_purchase_timestamp < '2019-01-01'
group by p.payment_type, sale_month
order by payment_type asc, sale_month asc
)
select
payment_type, sale_month, monthly_sales,
ROUND (((monthly_sales-monthly_change)/ NULLIF (monthly_change, 0)) * 100,2) 
as monthly_change
from total_sales;