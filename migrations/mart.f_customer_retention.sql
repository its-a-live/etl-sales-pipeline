create table if not exists mart.f_customer_retention (
	new_customers_count bigint,
	returning_customers_count bigint,
	refunded_customer_count bigint,
	period_name varchar(10),
	period_id int,
	item_id int,
	new_customers_revenue numeric(14, 2),
	returning_customers_revenue numeric(14, 2),
	customers_refunded bigint,
	UNIQUE(period_id, item_id)
);

delete from mart.f_customer_retention mfr
where mfr.period_id=DATE_PART('week','{{ds}}'::timestamp);

with temp as (
select fs.*,
       dc.week_of_year,
       case when fs.payment_amount < 0 then 'refunded'
       else 'shipped' end as status
from mart.f_sales fs
join mart.d_calendar dc on dc.date_id = fs.date_id
order by fs.customer_id
),

new_customer_count as (
select customer_id,
       week_of_year,
       item_id,
       count(distinct date_id) as new_customers_count
from temp
group by customer_id, week_of_year, item_id
having count(distinct date_id) = 1
),

new_customer_count2 as (
select week_of_year,
       item_id,
       count(distinct customer_id) as new_customers_count
from new_customer_count
group by  week_of_year, item_id
),

returning_customer_count as (
select customer_id,
       week_of_year,
       item_id,
       count(distinct date_id) as returning_customers_count
from temp
group by customer_id, week_of_year, item_id
having count(distinct date_id) > 1
),

returning_customer_count2 as (
select
    week_of_year,
    item_id,
    count(distinct customer_id) as returning_customers_count
from returning_customer_count
group by  week_of_year, item_id
),

refunded_customer as
(select  week_of_year,
         item_id,
         count(distinct customer_id) as refunded_customer_count
from temp
where status = 'refunded'
group by  week_of_year, item_id
),

new_customers_revenue as
(select nc.week_of_year,
        nc.item_id,
        sum(temp.payment_amount) as new_customers_revenue
from new_customer_count nc
left join temp  on nc.customer_id = temp.customer_id and nc.week_of_year = temp.week_of_year and nc.item_id =  temp.item_id
group by  nc.week_of_year, nc.item_id
),

returning_customers_revenue as
(select rt.week_of_year,
        rt.item_id,
        sum(temp.payment_amount) as returning_customers_revenue
from returning_customer_count rt
left join temp  on rt.customer_id=temp.customer_id and rt.week_of_year = temp.week_of_year
and rt.item_id = temp.item_id
group by  rt.week_of_year, rt.item_id
),

customer_refunded1  as
(select
     customer_id,
     week_of_year,
     item_id,
     count(*) as count_costomers
 from temp
where temp.status='refunded'
group by customer_id, week_of_year, item_id
),

customers_refunded2 as (
select  week_of_year,
        item_id,
        sum(count_costomers) as customers_refunded
from customer_refunded1
group by   week_of_year, item_id
)


INSERT INTO mart.f_customer_retention
select  distinct ncc.new_customers_count,
        rcc.returning_customers_count,
        rc.refunded_customer_count,
        'weekly' as period_name,
        dcl.week_of_year as period_id,
        di.item_id,
        ncr.new_customers_revenue,
        rcr.returning_customers_revenue,
        crf.customers_refunded
from mart.d_item di
    left join temp dcl  on 1 = 1
    left join new_customer_count2 ncc on dcl.week_of_year=ncc.week_of_year and di.item_id=ncc.item_id
    left join returning_customer_count2  rcc on dcl.week_of_year=rcc.week_of_year and di.item_id=rcc.item_id
    left join refunded_customer rc on dcl.week_of_year=rc.week_of_year and di.item_id=rc.item_id
    left join new_customers_revenue ncr on dcl.week_of_year=ncr.week_of_year and di.item_id=ncr.item_id
    left join returning_customers_revenue rcr on dcl.week_of_year=rcr.week_of_year and di.item_id=rcr.item_id
    left join customers_refunded2 crf on dcl.week_of_year=crf.week_of_year and di.item_id=crf.item_id
    where  dcl.week_of_year= DATE_PART('week','{{ds}}'::timestamp);