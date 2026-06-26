/*
====================================================================================
ADVANCED ANALYSIS
====================================================================================
*/

------------------------------------------------------------------------------------
-- 7. CHANGE OVER TIME
------------------------------------------------------------------------------------

-- Analyze Sales Performance Over Time
SELECT
YEAR(order_date) AS order_year,
MONTH(order_date) AS order_month,
SUM(amount) AS total_sales,
COUNT(DISTINCT(customer_key)) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date);;

GO
-- Or

SELECT 
DATETRUNC(MONTH,order_date) AS order_date,
SUM(amount) AS total_sales,
COUNT(DISTINCT(customer_key)) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH,order_date)
ORDER BY DATETRUNC(MONTH,order_date);

GO
--Or

SELECT 
FORMAT(order_date, 'yyyy-MMM') AS order_date,
SUM(amount) AS total_sales,
COUNT(DISTINCT(customer_key)) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY FORMAT(order_date, 'yyyy-MMM');

GO

------------------------------------------------------------------------------------
--8.CUMULATIVE ANALYSIS
------------------------------------------------------------------------------------

-- Calculate the total sales per month

-- Cumulative metrix over the MONTHS
SELECT 
order_date,
total_sales,
SUM(total_sales) OVER(PARTITION BY order_date ORDER BY order_date) AS running_total_sales,
AVG(avg_price) OVER(PARTITION BY order_date ORDER BY order_date) AS moving_avg_sales
-- Window Function(Running Total)
FROM
(
SELECT
DATETRUNC(MONTH, order_date) AS order_date,
SUM(amount) AS total_sales,
AVG(price) AS avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
)t;

GO
-- Cumulative metrix over the YEARS
SELECT 
order_date,
total_sales,
SUM(total_sales) OVER(ORDER BY order_date) AS running_total_sales,
AVG(avg_price) OVER(ORDER BY order_date) AS moving_avg_sales
-- Window Function(Running Total)
FROM
(
SELECT
DATETRUNC(YEAR, order_date) AS order_date,
SUM(amount) AS total_sales,
AVG(price) AS avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(YEAR, order_date)
)t;

GO

------------------------------------------------------------------------------------
--- 9.PERFORMANCE ANALYSIS
------------------------------------------------------------------------------------


/*
Analyse the yearly performance of products by comparing each product's sales
to both its average sales performance and the previous year's sales
*/

WITH yearly_product_sales AS(
	SELECT 
		YEAR(fs.order_date) AS order_year,
		dp.product_name,
		SUM(fs.amount) AS current_sales
	FROM gold.fact_sales fs
	LEFT JOIN gold.dim_products dp
	ON fs.product_key = dp.product_key
	WHERE order_date IS NOT NULL
	GROUP BY YEAR(fs.order_date),
	dp.product_name
)

SELECT
	order_year,
	product_name,
	current_sales,
	AVG(current_sales) OVER(PARTITION BY product_name) avg_sales,
	current_sales - AVG(current_sales) OVER(PARTITION BY product_name) AS diff_avg,
	CASE WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) > 0 THEN 'Above Avg'
		WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) < 0 THEN 'Below Avg'
		ELSE 'Avg'
	END avg_change,
	LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) prev_yr_sales,
	current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS diff_prev_yr,
	CASE WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
		WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
		ELSE 'No change'
	END prev_yr_change

FROM yearly_product_sales
ORDER BY product_name, order_year;

GO

------------------------------------------------------------------------------------
-- 10.PART-TO-WHOLE(Proportional ANALYSIS)
------------------------------------------------------------------------------------

-- Which categories contributes the most to overall sales

WITH category_sales AS(
SELECT
category,
SUM(amount) total_sales
FROM gold.dim_products dp
LEFT JOIN gold.fact_sales fs
ON dp.product_key = fs.product_key
WHERE category IS NOT NULL
GROUP BY category
)

SELECT 
category,
total_sales,
SUM(total_sales) OVER() overall_sales,
CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER()) *100, 2), '%') AS percentage_of_total
FROM category_sales
WHERE total_sales IS NOT NULL 
ORDER BY total_sales DESC;

GO

------------------------------------------------------------------------------------
-- 11. DATA SEGMENTATATION
------------------------------------------------------------------------------------

-- Segment products into cost ranges and count how many products fall into eachsegment.
WITH product_segment AS(
SELECT
product_key,
product_name,
cost,
CASE WHEN cost < 100 THEN 'Below 100'
	WHEN cost BETWEEN 100 AND 500 THEN'100-500'
	WHEN cost BETWEEN 500 AND 1000 THEN '500-10000'
	ELSE 'Above 1000'
END cost_range
FROM gold.dim_products)

SELECT 
cost_range,
COUNT(product_key) AS total_products
FROM product_segment
GROUP BY cost_range
ORDER BY total_products DESC;

GO

/*
Group customers into three segments based on their spending behaviour:
	- VIP: Customers with at least 12 months of history and spending more than 5000.
	- Regular: Customers with at least 12 months of history but spending 5000 or less.
	- New: Customers with a lifespan less than 12 month.
And find the total number of customers by each group
*/

WITH customer_segment AS(
SELECT 
dc.customer_key,
SUM(fs.amount) AS total_spending,
MIN(order_date) AS first_order,
MAX(order_date)AS last_order,
DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
FROM gold.dim_customers dc
LEFT JOIN gold.fact_sales fs
ON dc.customer_key = fs.customer_key
GROUP BY dc.customer_key
),

Spending_Beh AS(
SELECT 
CASE WHEN lifespan >=12 and total_spending > 5000 THEN 'VIP'
	WHEN lifespan > = 12 AND total_spending <= 5000 THEN 'Regular'
	ELSE 'New'
END spending_behaviour
FROM customer_segment
)

SELECT 
spending_behaviour,
COUNT(*) AS customer_count
FROM Spending_Beh
GROUP BY spending_behaviour
ORDER BY customer_count DESC;
GO
