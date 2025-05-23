delete from mart.f_sales as fs
where fs.date_id in (select dc.date_id from staging.user_order_log uol
left join mart.d_calendar as dc on uol.date_time::Date = dc.date_actual
where uol.date_time::Date = '{{ds}}');



insert into mart.f_sales (
                          date_id,
                          item_id,
                          customer_id,
                          city_id,
                          quantity,
                          payment_amount)
select dc.date_id,
       item_id,
       customer_id,
       city_id,
       quantity,
       case when uol.status='shipped' then uol.payment_amount
            when uol.status='refunded' then (-1)*uol.payment_amount
            end as payment_amount
from staging.user_order_log uol
left join mart.d_calendar as dc on uol.date_time::Date = dc.date_actual
where uol.date_time::Date = '{{ds}}';