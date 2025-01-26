--ЧАСТЬ 1
-- 2. 
create schema raw_data;

CREATE TABLE raw_data.sales(
	id int,
	auto varchar not null,
	gasoline_consumption decimal,
	price decimal ,
	date date,
	person varchar,
	phone varchar,
	discount int2,
	brand_origin varchar 
);

-- 4. 
COPY raw_data.sales FROM 'C:/univer/Y_practicum_postgre/cars.csv' WITH CSV HEADER NULL 'null'; 

-- 7. 
create schema car_shop;

CREATE TABLE car_shop.person(
id serial primary key, -- ключ
name varchar(100) not null, -- ФИО не более 100 символов
phone varchar(50) -- телефоны записывают в разных стандартах, поэтому храним как строку
);
CREATE TABLE car_shop.colour(
colour_id serial primary key,
colour_name varchar(20) check (colour_name Not Like '% %') -- не существует цветов более чем 20 символов
);

CREATE TABLE IF NOT EXISTS car_shop.brands(
brand_id serial PRIMARY KEY,
brand_name VARCHAR(50) UNIQUE check (brand_name  Not Like '% %'), -- не существует названий брендов длиной более 50 символов, в названии бренда могут быть и цифры, и буквы, поэтому выбираем varchar(50) и только уникальные значения	
brand_origin_name VARCHAR(40)  -- не существует названий стран более 40 символов 
);

CREATE TABLE car_shop.auto(
auto_id serial primary key, -- ключ
brand_id INTEGER REFERENCES car_shop.brands,
name_auto varchar(50) not null, -- не существует марок машин более 50 символов
colour_id integer references car_shop.colour, -- 
gasoline_consumption decimal(4, 2) -- расход топлива не может быть трезначным (количество цифр целой части 2)
-- В базе все значения округлены до сотых. Из-за отсутствия иных требований примем это за базу
);

CREATE TABLE car_shop.sales(
sale_id serial primary key, -- ключ
person_id integer references car_shop.person, -- внешний ключ для связи с инф о покупателе
auto_id integer references car_shop.auto, -- внешний ключ для связи с инф об автомобиле
price numeric(9, 2) not null, -- цена не более 7 цифр целой части и 2 цифр десятичной
date_sale date not null, -- дата покупки. Время не указывается, поэтому выберем date
discount int2 DEFAULT 0 check (discount <= 100)-- скидка в базе представлена целым числом, поэтому берем минимально возможное целое. Скидка не может более 100%
);

--8.
INSERT INTO car_shop.person(name, phone)
(SELECT DISTINCT person, phone
FROM raw_data.sales);

INSERT INTO car_shop.colour(colour_name)
(SELECT DISTINCT SPLIT_PART(auto, ', ', 2)
FROM raw_data.sales);

INSERT INTO car_shop.brands(brand_name , brand_origin_name )
(SELECT DISTINCT split_part(auto, ' ' , 1), brand_origin
FROM raw_data.sales);

INSERT INTO car_shop.auto(brand_id, name_auto , colour_id , gasoline_consumption )
(SELECT DISTINCT
 brand_id
, split_part(substr(auto,strpos(auto,' ')+1),',',1)  
, colour_id
, gasoline_consumption 
FROM raw_data.sales as sale
INNER JOIN car_shop.brands AS brands ON split_part(sale.auto, ' ' , 1) = brands.brand_name
INNER JOIN car_shop.colour as colour ON colour.colour_name = SPLIT_PART(auto, ', ', 2));

INSERT INTO car_shop.sales(person_id, auto_id, price, date_sale, discount)
(SELECT person.id, auto.auto_id, price, sale.date, discount
FROM raw_data.sales as sale
LEFT JOIN car_shop.person as person ON sale.person = person.name
LEFT JOIN car_shop.auto as auto ON split_part(substr(auto,strpos(auto,' ') + 1), ',' ,1) = auto.name_auto 
LEFT JOIN car_shop.colour as colour ON colour.colour_id = auto.colour_id
LEFT JOIN car_shop.brands as brand ON brand.brand_id = auto.brand_id
WHERE SPLIT_PART(auto, ', ', 2) = colour.colour_name and split_part(auto, ' ' , 1) = brand.brand_name
);

--ЧАСТЬ 2
--1
SELECT ROUND((1 - count(gasoline_consumption)/count(*)::float)*100) AS nulls_percentage_gasoline_consumption 
FROM car_shop.auto;

--2
SELECT brand_name, EXTRACT(year from date_sale) as year, round(avg(price),2) as price_avg
FROM car_shop.sales as sale
inner join car_shop.auto as auto on (auto.auto_id = sale.auto_id)
inner join car_shop.brands as brand on (auto.brand_id = brand.brand_id)
GROUP BY brand_name, EXTRACT(year from date_sale)
ORDER BY brand_name, year;

--3
SELECT EXTRACT(month from date_sale) as month, EXTRACT(year from date_sale) as year,  round(avg(price*(1 - discount/100)),2) as price_avg
FROM car_shop.sales as sale
where EXTRACT(year FROM date_sale)=2022
GROUP BY EXTRACT(month from date_sale), EXTRACT(year from date_sale)
ORDER BY month;

--4
SELECT persons.name AS person, string_agg((brand.brand_name||' '||auto.name_auto),', ') AS cars
FROM car_shop.person AS persons
JOIN car_shop.sales AS sale ON persons.id = sale.person_id
JOIN car_shop.auto AS auto ON auto.auto_id = sale.auto_id
JOIN car_shop.brands AS brand ON auto.brand_id = brand.brand_id
GROUP BY name
ORDER BY name;

--5
SELECT brand_origin_name, MAX(sale.price * 100 / 100 - sale.discount) as price_max, MIN(sale.price * 100 / 100 - sale.discount) as price_min
FROM car_shop.sales as sale
inner join car_shop.auto as auto on (auto.auto_id = sale.auto_id)
inner join car_shop.brands as brand on (auto.brand_id = brand.brand_id)
GROUP BY brand_origin_name;

--6
SELECT count(name) AS persons_from_usa_count
FROM car_shop.person
WHERE substring(phone from 1 for 2) = '+1';

