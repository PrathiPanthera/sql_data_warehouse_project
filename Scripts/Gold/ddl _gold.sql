/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================

IF OBJECT_ID('gold.dim_customers','V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER(ORDER BY ci.cust_id) AS customer_key,
    ci.cust_id AS customer_id,
    ci.cust_key AS customer_number,
    ci.cust_firstname AS firstname,
    ci.cust_lastname AS lastname,
    la.cust_country AS country,
    ci.cust_marital_status AS marital_status,
    CASE
        WHEN ci.cust_gender <> 'n/a'
            THEN ci.cust_gender
        ELSE COALESCE(ca.cust_gender,'n/a')
    END AS gender,
    ca.cust_bdate AS birthdate,
    ci.cust_create_date AS create_date
FROM silver.crm_customer_info ci
LEFT JOIN silver.erp_customer_info ca
    ON ci.cust_key = ca.cust_id
LEFT JOIN silver.erp_customer_loc la
    ON ci.cust_key = la.cust_id;
GO

-- =============================================================================
-- Create Dimension: gold.dim_products
-- =============================================================================


IF OBJECT_ID('gold.dim_products','V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS
SELECT
ROW_NUMBER() OVER(ORDER BY pn.prod_start_date,pn.prod_key) AS product_key,
pn.prod_id AS product_id,
pn.prod_key AS product_number,
pn.prod_name AS product_name,
pn.cat_id AS category_id,
pc.prod_cat_category AS category,
pc.prod_cat_subcat AS subcategory,
pc.prod_cat_maintainance AS maintainance,
pn.prod_cost AS cost,
pn.prod_line AS product_line,
pn.prod_start_date AS start_date
FROM silver.crm_product_info pn
LEFT JOIN silver.erp_product_cat pc
ON pn.cat_id = pc.prod_cat_id
WHERE pn.prod_end_date IS NULL; -- Filter out all historical Data

GO

-- =============================================================================
-- Create Fact: gold.fact_sales
-- =============================================================================

IF OBJECT_ID ('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
SELECT
	so.sls_ord_number AS order_number,
	pr.product_key,
	cu.customer_key,
	so.sls_ord_date AS order_date,
	so.sls_ship_date AS shipping_date,
	so.sls_due_date AS due_date,
	so.sls_sales AS amount,
	so.sls_quantity AS quantity,
	so.sls_price AS price
FROM silver.crm_sales_orders so
LEFT JOIN gold.dim_products pr
ON so.sls_ord_key = pr.product_number
LEFT JOIN gold.dim_customers cu
ON so.sls_cust_id = cu.customer_id;
