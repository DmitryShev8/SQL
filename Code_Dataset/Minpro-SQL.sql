
-- ALTER TABLE --
alter table olist_orders_dataset
alter column order_id
set not null

alter table olist_order_items_dataset
rename TO order_items

alter table olist_orders_dataset
rename to orders

alter table olist_products_dataset
rename to products

alter table olist_sellers_dataset
rename to sellers

alter table public.order_items add constraint order_items_orders_fk foreign key (order_id) references public.orders(order_id)
alter table public.order_items add constraint order_items_orders_fk foreign key (product_id) references public.products(product_id)
alter table public.order_items add constraint order_items_orders_fk foreign key (seller_id) references public.sellers(seller_id)

-- INSERT, UPDATE, DAN DELETE --
insert into orders values ('1', '1', 'canceled', '2018-06-12 20:07:44.000', '2018-06-12 20:44:26.000', '2018-06-13 13:09:00.000', '2018-06-19 12:44:08.000', '2018-07-17 00:00:00.000')
-- Cek --
select * from orders
where order_id = '1'
-- Update --
update orders
set order_status = 'delivered'
where order_id = '1'
-- Cek lagi --
select * from orders
where order_id = '1'
-- Delete --
delete from orders
where order_id = '1'



-- Basic Query SQL --
-- SELECT --
select * from order_items
select * from orders 
select * from products
select * from sellers

select count(*) from order_items
select count(*) from orders
select count(*) from products
select count(*) from sellers

-- WHERE --
select * from orders
where order_status = 'canceled'

select * from order_items
where price > (select avg(price) from order_items)

select * from products
where product_photos_qty is null

select * from products
where product_category_name = ''

-- GROUP BY, ORDER BY, HAVING dan 3 agg function (AVG, SUM, COUNT) --
select product_category_name, count(*) -- Berapa jumlah tiap kategori produk --
from products
group by product_category_name

select order_item_id, round(sum(price)::numeric, 2) as total_price -- Urutkan total price tiap order_item_id --
from order_items
group by order_item_id
order by total_price desc

select seller_id, count(*) AS total_produk -- Cek seller dengan total produk > 100 --
from order_items
group by seller_id
having count(*) > 100

select product_category_name, round(avg(product_weight_g)::numeric, 2) as avg_weight -- Tampilkan kategori produk dengan rata-rata berat > 100 --
from products
group by product_category_name
having avg(product_weight_g) > 1000
order by avg_weight desc

-- Intermediate SQL Query --
-- CASE WHEN --
select order_id, price,
	case
		when price >= (select avg(price) from order_items) then 'High Price'
		else 'Low Price' 
	end as price_category
from order_items

-- JOIN --
select oi.order_id, p.product_category_name, oi.price
from order_items oi left join products p
on oi.product_id = p.product_id

select o.order_id, oi.order_item_id, o.order_status
from order_items oi join orders o
on oi.order_id = o.order_id
where o.order_status = 'canceled'

select product_id, product_category_name, (product_length_cm * product_height_cm * product_width_cm) as volume
from products
where product_category_name = 'moveis_decoracao'
union
select product_id, product_category_name, (product_length_cm * product_height_cm * product_width_cm) as volume
from products
where product_category_name = 'cama_mesa_banho'

-- Subquery --
select avg_oi.order_item_id, avg_oi.avg_price
from (
	select order_item_id, round(avg(price)::numeric, 2) as avg_price
	from order_items
	group by order_item_id
	order by avg_price desc
) as avg_oi

select product_category_name, (select COUNT(*) from products) as total_category
from products

-- Window Function --
select order_item_id, price, rank() over(
order by price desc)
from order_items

select product_category_name, count(*) over(
partition by product_category_name
)
from products



-- CTE WITH --
-- Top Seller Revenue per State
with seller_revenue as (
	select s.seller_state, oi.seller_id, sum(oi.price) as total_revenue
	from order_items oi join sellers s
	on oi.seller_id = s.seller_id
	group by s.seller_state, oi.seller_id
),

ranked_seller as(
	select *,
		dense_rank() over (
			partition by seller_state
			order by total_revenue desc) as ranking
	from seller_revenue
)

select * from ranked_seller
where ranking = 1

-- Average Delivery Delay --

with delivery_delay as (
	select order_id,
		(order_delivered_customer_date - order_estimated_delivery_date) as delay_interval
	from orders
	where order_delivered_customer_date is not null
)

select avg(delay_interval) as avg_delay
from delivery_delay

-- Most Valuable Product Category --

with category_sales as (
	select p.product_category_name,
		sum(oi.price) as revenue
	from order_items oi join products p
	on oi.product_id = p.product_id
	group by p.product_category_name
)

select * from category_sales
order by revenue desc
limit 10

-- Customer Order Size Segmentation --
with order_size as (
	select order_id, count(*) as total_items
	from order_items
	group by order_id
)

select
	case
		when total_items = 1 then 'Single Item'
		when total_items <= 3 then 'Small Order'
		when total_items <= 5 then 'Medium Order'
		else 'Large Order'
	end as segment,
	count(*) as total_orders
from order_size
group by segment

-- Seller Performance Vs Freight Cost --
with monthly_sales as (
	select to_char(order_purchase_timestamp, 'YYYY-MM') as month,
		sum(oi.price) as revenue
	from orders o join order_items oi
	on o.order_id = oi.order_id
	group by month
)

select *, lag(revenue) over(
	order by month) as previous_month
from monthly_sales

-- Customer Segmentation --
-- Cek Statistik Customer Spending --
with customer_spending as (
	select o.customer_id, sum(oi.price) as total_spending
	from orders o join order_items oi
	on o.order_id = oi.order_id
	group by o.customer_id
)

select count(*) total_customer, 
	round(avg(total_spending)::numeric, 2) as mean,
	round(percentile_cont(0.5)
		within group (order by total_spending)::numeric, 2) as median,
	round(stddev(total_spending)::numeric, 2) as stddev,
	
	min(total_spending) as min_spending,
	max(total_spending) as max_spending
from customer_spending

-- Cek Quartile --
with customer_spending as (
	select o.customer_id, sum(oi.price) as total_spending
	from orders o join order_items oi
	on o.order_id = oi.order_id
	group by o.customer_id
)

select 
	percentile_cont(0.25)
		within group(order by total_spending) as q1,
	percentile_cont(0.5)
		within group(order by total_spending) as median,
	percentile_cont(0.75)
		within group(order by total_spending) as q3
from customer_spending
	

-- Customer Spending Segmentation --
-- Berdasarkan Quartile --
with customer_spending as (
	select o.customer_id, sum(oi.price) as total_spending
	from orders o join order_items oi
	on o.order_id = oi.order_id
	group by o.customer_id
),

quartiles as (
	select 
		percentile_cont(0.25)
			within group(order by total_spending) as q1,
		percentile_cont(0.75)
			within group(order by total_spending) as q3
	from customer_spending
)

select
	case
		when total_spending < q1 then 'low'
		when total_spending < q3 then 'medium'
		else 'High'
	end as customer_segment,
	
	count(*) as total_customers
from customer_spending cross join quartiles
group by customer_segment

-- Data Cleaning --
-- Duplicate --
SELECT
    (
        select count(*)
        from (
            select order_id
            from orders
            group by order_id
            having count(*) > 1
        ) t
    ) as duplicate_order_id,

    (
        select count(*)
        from (
            select order_id, order_item_id
            from order_items
            GROUP BY order_id, order_item_id
            HAVING COUNT(*) > 1
        ) t
    ) as duplicate_order_item,

    (
        select count(*)
        from (
            select product_id
            from products
            group by product_id
            having count(*) > 1
        ) t
    ) as duplicate_product_id,

    (
        select count(*)
        from (
            select seller_id
            from sellers
            group by seller_id
            having count(*) > 1
        ) t
    ) as duplicate_seller_id

-- Missing Values --
select 
	count(*) as total_rows,
	count(*) - count(seller_id) as missing_seller_id,
	count(*) - count(seller_zip_code_prefix) as missing_zip,
	count(*) - count(seller_city) as missing_city,
	count(*) - count(seller_state) as missing_state
from sellers

select
	count(*) as total_rows,
	count(*) - count(order_id) as missing_order_id,
	count(*) - count(customer_id) as missing_customer_id,
	count(*) - count(order_status) as missing_order_status,
	count(*) - count(order_purchase_timestamp) as missing_purchase_ts,
	count(*) - count(order_approved_at) as missing_approved_at,
	count(*) - count(order_delivered_carrier_date) as missing_carrier_date,
	count(*) - count(order_delivered_customer_date) as missing_customer_date,
	count(*) - count(order_estimated_delivery_date) as missing_estimated_date
from orders

select
	count(*) as total_rows,
	count(*) - count(order_id) as missing_order_id,
	count(*) - count(order_item_id) as missing_order_item_id,
	count(*) - count(product_id) as missing_product_id,
	count(*) - count(seller_id) as missing_seller_id,
	count(*) - count(shipping_limit_date) as missing_shipping_limit_date,
	count(*) - count(price) as missing_price,
	count(*) - count(freight_value) as missing_freight
from order_items


select
	count(*) as total_rows,
	count(*) - count(product_id) as missing_product_id,
	count(*) - count(product_category_name) as missing_category,
	count(*) - count(product_name_lenght) as missing_name_length,
	count(*) - count(product_description_lenght) as missing_desc_length,
	count(*) - count(product_photos_qty) as missing_photos_qty,
	count(*) - count(product_weight_g) as missing_weight,
	count(*) - count(product_length_cm) as missing_length,
	count(*) - count(product_height_cm) as missing_height,
	count(*) - count(product_width_cm) as missing_width
from products

-- Cek apakah null berasal dari canceled / unavailable order
select order_status, count(*) as total_orders
from orders
where
    order_approved_at is null
    or order_delivered_carrier_date is null
    or order_delivered_customer_date is null
group by order_status
order by total_orders desc

select order_status, count(*) as total_orders
from orders
group by order_status
order by total_orders desc

select * from orders
where
    (order_approved_at is null
    or order_delivered_carrier_date is null
    or order_delivered_customer_date is null)
    and order_status = 'delivered'


-- Cell kosong --
select
    count(*) AS total_rows,
    sum(
        case
            when seller_id is null or trim(seller_id) = ''
            then 1
            else 0
        end
    ) as missing_seller_id,

    sum(
        case
            when seller_city IS null or trim(seller_city) = ''
            then 1
            else 0
        END
    ) AS missing_seller_city,

    sum(
        case
            when seller_state is null or trim(seller_state) = ''
            then 1
            else 0
        end
    ) as missing_seller_state

from sellers;

-- Product --
select
    count(*) as total_rows,
    sum(
        case
            when product_id is null
                 or trim(product_id) = ''
            then 1
            else 0
        end
    ) as missing_product_id,

    sum(
        case
            when product_category_name is null
                 or trim(product_category_name) = ''
            then 1
            else 0
        end
    ) as missing_category,

    sum(
        case
            when product_name_lenght is null
            then 1
            else 0
        end
    ) as missing_name_length

from products

select count(*)
from products
where
    product_category_name = ''
    and product_name_lenght is null
    and product_description_lenght is null
    and product_photos_qty is null

-- Cek inkonsistensi --
-- Cek apakah ada FK yang tidak punya parent --
-- order_items -> orders --
select oi.*
from order_items oi
left join orders o
    on oi.order_id = o.order_id
where o.order_id is null;

-- order_items -> products
select oi.*
from order_items oi
left join products p
    on oi.product_id = p.product_id
where p.product_id is null;

-- order_items -> products --
select oi.*
from order_items oi
left join sellers s
    on oi.seller_id = s.seller_id
where s.seller_id is null

-- Invalid numeric values --
-- Harga negatif / nol --
select *
from order_items
where price <= 0

-- Freight negatif --
select *
from order_items
where freight_value < 0

-- Dimensi produk aneh --
select *
from products
where product_weight_g <= 0 or product_length_cm <= 0 or product_height_cm <= 0 or product_width_cm <= 0
    
-- Timestamp Logic Validation --
-- Delivered sebelum purchase --
select *
from orders
where
    order_delivered_customer_date
    < order_purchase_timestamp

-- Estimated delivery sebelum purchase --
select *
from orders
where order_estimated_delivery_date < order_purchase_timestamp
    
-- Categorical Inconsistency --
select order_status, count(*)
from orders
group by order_status
order by count(*) desc;

-- City/State Formatting Issues --
-- Seller city duplicate karena case --
select distinct seller_city
from sellers
order by seller_city;

select * from sellers
where seller_city = '04482255'

-- Cek kota yang berbeda hanya karena casing --
select
    lower(trim(seller_city)) as normalized_city,
    count(distinct seller_city) as variation_count,
    string_agg(distinct seller_city, ' | ') as variations
from sellers
group by normalized_city
having count(distinct seller_city) > 1
order by variation_count desc;

-- Cek leading/trailing whitespace --
select
    seller_city
from sellers
where seller_city != trim(seller_city)

-- Cek karakter aneh --
select distinct seller_city
from sellers
where seller_city ilike '%sao%'
   or seller_city ilike '%são%'
order by seller_city

-- Cari typo mirip --
create extension pg_trgm -- Cukup jalankan sekali --
select distinct
    least(a.seller_city, b.seller_city) as city_1,

    greatest(a.seller_city, b.seller_city) as city_2,

    round(
        similarity(a.seller_city, b.seller_city)::numeric,
        2
    ) as sim_score

from sellers a join sellers b
on a.seller_city <> b.seller_city and a.seller_state = b.seller_state
where similarity(a.seller_city, b.seller_city) > 0.4
order by sim_score desc

-- Cek yang tidak konsisten --
select * from sellers
where seller_city = 'rio de janeiro rio de janeiro'

select distinct seller_city
from sellers
where seller_city like '%/%'

select distinct seller_city
from sellers

-- Outlier Detection --
with quartiles as (
    select
        percentile_cont(0.25)
            within group (order by price) as q1,

        percentile_cont(0.75)
            within group (order by price) as q3
    from order_items
),

iqr_calc as (
    select q1, q3, (q3 - q1) AS iqr
    from quartiles
)

select
    oi.*
from order_items oi
cross join iqr_calc

where price < (q1 - 1.5 * iqr) or price > (q3 + 1.5 * iqr)

-- Hitung jumlah outlier --
-- Price --
with quartiles as (
    select
        percentile_cont(0.25)
            within group (order by price) as q1,

        percentile_cont(0.75)
            within group (order by price) as q3
    from order_items
),

iqr_calc as (
    select q1, q3, (q3 - q1) as iqr
    from quartiles
)

select count(*) as total_data,
	sum(
		case
			when price < (q1 - 1.5 * iqr) or price > (q3 + 1.5 * iqr) then 1
			else 0
		end
	) as total_outliers
	
from order_items
cross join iqr_calc

-- Freight_value --
with quartiles as (
    select
        percentile_cont(0.25)
            within group (order by freight_value) as q1,

        percentile_cont(0.75)
            within group (order by freight_value) as q3
    from order_items
),

iqr_calc as (
    select q1, q3, (q3 - q1) as iqr
    from quartiles
)

select count(*) as total_data,
	sum(
		case
			when freight_value < (q1 - 1.5 * iqr) or freight_value > (q3 + 1.5 * iqr) then 1
			else 0
		end
	) as total_outliers
	
from order_items
cross join iqr_calc

-- Data Cleaning --
-- Buat Copy Table Raw --
create table sellers_raw as
select * from sellers

create table products_raw as
select * from products

create table order_items_raw as
select * from order_items

create table orders_raw as
select * from orders

-- Karena kategori produk masih berbentuk empty string (menandakan null), buat jadi NULL biar konsisten --
update products
set product_category_name = NULL
where trim(product_category_name) = ''

select count(*)
from products
where product_category_name is null and product_name_lenght is null and product_description_lenght is null and product_photos_qty is null

-- Mengatasi null value --
-- Atasi nilai ambigu --
update orders
set order_status = 'ambiguous'
where (order_approved_at is null or order_delivered_carrier_date is null or order_delivered_customer_date is null) and order_status = 'delivered'
    
select * from orders
where order_status = 'ambiguous'

-- Products --
update products
set product_category_name = 'unknown'
where product_category_name is null

select * from products
where product_category_name = 'unknown'

update products
set
    product_weight_g = (
        select
            percentile_cont(0.5) within group (order by product_weight_g)
        from products
        where product_weight_g is not null
    ),
    product_length_cm = (
        select percentile_cont(0.5) within group (order by product_length_cm)
        from products
        where product_length_cm is not null
    ),
    product_height_cm = (
        select
            percentile_cont(0.5) within group (order by product_height_cm)
        from products
        where product_height_cm is not null
    ),
    product_width_cm = (
        select
            percentile_cont(0.5) within group (order by product_width_cm)
        from products
        where product_width_cm is not null
    )
where product_weight_g is null or product_length_cm is null or product_height_cm is null or product_width_cm is null
    
    
-- Memperbaiki inkonsistensi (seller_city) --
-- Phase 1: Standardization --
UPDATE sellers
SET seller_city = LOWER(TRIM(seller_city))
    
-- Phase 2: Remove double spaces --
update sellers
set seller_city =
    regexp_replace(
        seller_city,
        '\s+',
        ' ',
        'g'
    )
    
-- Phase 3: Hapus /state --
update sellers
set seller_city =
    regexp_replace(
        seller_city,
        '\s+',
        ' ',
        'g'
    )
    
-- Phase 4: Hapus - sp --
update sellers
set seller_city =
    regexp_replace(
        seller_city,
        '\s*-\s*[a-z]{2}$',
        '',
        'i'
    )
    
-- Phase 5: Remove trailing state abbreviation --
update sellers
set seller_city =
    regexp_replace(
        seller_city,
        '\s+[a-z]{2}$',
        '',
        'i'
    )
where seller_city ~ '\s+[a-z]{2}$'


-- Phase 6: Trailing Slash --
update sellers
set seller_city =
    regexp_replace(
        seller_city,
        '/$',
        ''
    )
where seller_city like '%/'

-- Phase 7: Duplicating City Name --
update sellers
set seller_city = 'rio de janeiro'
where seller_city = 'rio de janeiro rio de janeiro'

-- Phase 8: Accent Inconsistency --
update sellers
set seller_city = 'santa barbara d''oeste'
where seller_city IN (
    'santa barbara d oeste',
    'santa barbara d´oeste'
)

select seller_city, COUNT(*)
from sellers
where seller_city IN ('sp', 'sp /')
group by seller_city;

-- Phase 9: Handle kota yang gak jelas, jangan isi dengan asumsi, lebih baik dikosongkan --
update sellers
set seller_city = null
where seller_city in ('sp', 'sp /', '04482255')

-- Phase 10: Fix duplicated city after slash --
update sellers
set seller_city =
    trim(split_part(seller_city, '/', 1))
where seller_city like '%/%';

-- Phase 11: Trailing space issue --
update sellers
set seller_city = trim(seller_city)



-- Insight Searching --
-- Delivery Performance Analysis --

-- A. On-time vs Late Delivery --
select
	case
		when order_delivered_customer_date <= order_estimated_delivery_date then 'On Time'
		else 'Late'
	end as delivery_status,
	
	count(*) as total_orders
from orders
where order_status = 'delivered' and order_delivered_customer_date is not null
group by delivery_status

-- B. Average Delay Days --
select round(
	avg(order_delivered_customer_date::date - order_estimated_delivery_date::date)::numeric, 2) as avg_delay_days
from orders
where order_status = 'delivered'

-- Bandingkan rata-rata estimated days dan rata-rata actual days --
select
    round(
        avg(
            order_estimated_delivery_date::date
            - order_purchase_timestamp::date
        )::numeric,
        2
    ) as avg_estimated_days,

    round(
        avg(
            order_delivered_customer_date::date
            - order_purchase_timestamp::date
        )::numeric,
        2
    ) as avg_actual_days

from orders
where order_status = 'delivered'

-- C. Delivery Trend per Month --
create or replace view monthly_delivery_trend as
with delivery_performance as (
    select
        date_trunc('month', order_purchase_timestamp)::date as month,
        case
            when order_delivered_customer_date <= order_estimated_delivery_date
            then 1
            else 0
        end as on_time
    from orders
    where order_status = 'delivered'
)

select
    month,
    round(avg(on_time)::numeric * 100, 2) as on_time_rate
from delivery_performance
group by month
order by month

-- Bulan september 2019 --
select order_id, order_purchase_timestamp, order_estimated_delivery_date, order_delivered_customer_date,
	case
        when order_delivered_customer_date
             <= order_estimated_delivery_date
        then 'On Time'
        else 'Late'
    end as delivery_status
from orders
where date_trunc(
    'month',
    order_purchase_timestamp
) = '2016-09-01'
AND order_status = 'delivered'

-- Transaction & Seller Behavior --
-- Average Order Value --
with order_value as (
	select order_id, sum(price) as total_order_value
	from order_items
	group by order_id
)

select
	round(
		avg(total_order_value)::numeric,2) as avg_order_value
from order_value

-- Most sold product category --
select p.product_category_name, count(*) as total_items_sold
from order_items oi join products p
on oi.product_id = p.product_id
group by p.product_category_name
order by total_items_sold desc
limit 10

-- Repeat purchase behavior --
create or replace view repeat_purchase as
select
    total_items,
    COUNT(*) as total_orders

from (
    select order_id, count(*) as total_items
    from order_items
    group by order_id
) t
group by total_items
order by total_items

-- Freight Sensitivity --
select
    round(
        avg(freight_value / price)::numeric,
        2
    ) as avg_freight_ratio

from order_items

-- Seller distribution by revenue segment --
with seller_revenue as (
    select
        seller_id,
        SUM(price) AS revenue

    from order_items

    group by seller_id
),

quartiles as (
    select
        percentile_cont(0.25)
            within group (
                order by revenue
            ) as q1,

        PERCENTILE_CONT(0.75)
            WITHIN GROUP (
                ORDER BY revenue
            ) AS q3

    FROM seller_revenue
)

select
    case
        when revenue < q1
            then 'Small Seller'

        when revenue < q3
            then 'Medium Seller'

        else 'Large Seller'
    end as seller_segment,

    count(*) AS total_sellers

from seller_revenue
cross join quartiles
group by seller_segment
order by total_sellers desc

-- Nilai kuartal seller --
WITH seller_revenue AS (
    SELECT
        seller_id,
        SUM(price) AS revenue

    FROM order_items

    GROUP BY seller_id
)

select
    round(
        percentile_cont(0.25)
        within group (
            order by revenue
        )::numeric,
        2
    ) AS q1,

    round(
        percentile_cont(0.50)
        within group (
            ORDER by revenue
        )::numeric,
        2
    ) as median,

    round(
        percentile_cont(0.75)
        within group (
            order by revenue
        )::numeric,
        2
    ) as q3

from seller_revenue

-- Seller Activity Distribution --
-- Apakah seller aktif merata? --
with seller_orders as (
	select seller_id, count(distinct order_id) as total_orders
	from order_items
	group by seller_id
)

select round(
	avg(total_orders)::numeric,2) as avg_orders,
	percentile_cont(0.5) within group (order by total_orders) as median_orders,
	max(total_orders) as max_orders
from seller_orders

-- Hasil: aktivitas seller sangat skewed, median = 6, max = 1854, average = 32 --

-- Seller Shipping Behavior --
select round(avg(order_delivered_carrier_date::date - order_purchase_timestamp::date)::numeric, 2) as avg_shipping_prep_days
from orders
where order_delivered_carrier_date is not null

-- Seller Category Diversity --
with seller_category_count as(
	select oi.seller_id, count(distinct p.product_category_name) as total_categories
	from order_items oi join products p
	on oi.product_id = p.product_id 
	group by oi.seller_id 
	order by total_categories desc
)

select total_categories, count(*) as total_sellers
from seller_category_count
group by total_categories
order by total_categories desc

-- Revenue Analysis --
-- Monthly Revenue Trend --
create or replace view monthly_revenue as
with monthly_revenue as (
    select 
        date_trunc('month', o.order_purchase_timestamp)::date as month,
        sum(oi.price) as revenue
    from orders o 
    join order_items oi
    on o.order_id = oi.order_id
    group by month
)

select 
    month,
    round(revenue::numeric, 2) as revenue
from monthly_revenue
order by month

-- Cek bulan terakhir --
select o.*, oi.price
from orders o join order_items oi
on o.order_id = oi.order_id
where o.order_purchase_timestamp >= '2018-09-01'
  and o.order_purchase_timestamp <  '2018-10-01'
order by o.order_purchase_timestamp
-- Bulan terakhir, hanya ada transaksi

-- Revenue Contribution by State --
select s.seller_state,
	round(sum(oi.price)::numeric, 2) as revenue
from order_items oi join sellers s
on oi.seller_id = s.seller_id
group by s.seller_state
order by revenue desc
	



