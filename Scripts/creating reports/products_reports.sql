/*
=========================================================================================
-- PRODUCTS REPORT
=========================================================================================
Purpose:	- This report consolidates key products metrics and behaviours

Highlights:
	1. Gather essential fields such as product names,category, subcategory, and cost.
	2. Segments products by revenue to identify High-Performers, Mid_Range, or Low-Performers.
	3. agreegates product-level metrics:
		- total orders
		- total sales
		- total quantity sold
		- total consumers (unique)
		- lifespan(in months)
	4. Calculates valuable KPIs:
		- recency(months since last order)
		- average order value(AOR)
		- average revenue
=========================================================================================
*/

IF OBJECT_ID ('gold.products_report', 'V') IS NOT NULL
    DROP VIEW gold.products_report;
GO

CREATE VIEW gold.products_report AS

WITH basequery AS (
/* --------------------------------------------------------------------------------------
1. Base Query: Retrives core columns from tables
---------------------------------------------------------------------------------------*/
	SELECT
		fs.order_number,
		fs.order_date,
		fs.product_key,
		fs.customer_key,
		fs.amount,
		fs.quantity,
		dp.product_number,
		dp.product_name,
		dp.category,
		dp.subcategory,
		dp.cost,
		dp.start_date
	FROM gold.fact_sales fs
	LEFT JOIN gold.dim_products dp
		ON dp.product_key = fs. product_key
	WHERE order_date IS NOT NULL -- only consider valid sales dates
),


product_aggregation AS (
/* --------------------------------------------------------------------------------------
2. Customer Aggregations: Summarise key metrics at the customer level
---------------------------------------------------------------------------------------*/
	SELECT
		product_key,
		product_name,
		category,
		subcategory,
		cost,
		DATEDIFF(MONTH,	MIN(order_date), MAX(order_date)) AS lifespan,
		MAX(order_date) AS last_sale_date,
		COUNT(DISTINCT order_number) AS total_orders,
		COUNT(DISTINCT customer_key) AS total_customers,
		SUM(amount) AS total_sales,
		SUM(quantity) AS total_quantity,
		ROUND(AVG(CAST(amount AS FLOAT) / NULLIF(quantity, 0)), 1) AS avg_selling_price
	FROM basequery
	GROUP BY 
		product_key,
		product_name,
		category,
		subcategory,
		cost
)

/* --------------------------------------------------------------------------------------
3. Final Query: Combines all products into one output
---------------------------------------------------------------------------------------*/
SELECT
	product_key,
		product_name,
		category,
		subcategory,
		cost,
		last_sale_date,
		DATEDIFF(MONTH, last_sale_date, GETDATE()) AS recency,
		CASE 
			WHEN total_sales > 50000 THEN 'High-Perfoemer'
			WHEN total_sales >= 10000 THEN 'Mid-Range'
			ELSE 'Low-Performer'
		END AS product_segment,
		lifespan,
		total_customers,
		total_orders,
		total_sales,
		total_quantity,
		avg_selling_price,
	--Compute average order value(avo)
	CASE WHEN total_orders = 0 THEN 0 
		ELSE total_sales / total_orders
	END	AS avg_order_value,
	-- Compute average revenue
	CASE WHEN lifespan = 0 THEN total_sales
		ELSE total_sales / lifespan
	END	AS avg__revenue
FROM product_aggregation;

GO

SELECT * FROM gold.products_report;
