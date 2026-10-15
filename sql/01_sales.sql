/* =====================================================
   Block:   Sales analysis (Q1 - Q4)
   Rules applied in every query:
   - delivered orders only (97.02% of orders)
   - Jan 2017 - Aug 2018 only (2016 and Sep/Oct 2018 are incomplete)
   - revenue = price, without freight_value
   ===================================================== */


-- Q1: How much revenue did we make each month, and is it growing or shrinking?
SELECT
    YEAR(o.order_purchase_timestamp)  AS yearofpurchase,
    MONTH(o.order_purchase_timestamp) AS monthofpurchase,
    CAST(SUM(i.price) AS DECIMAL(18,2)) AS sum_revenue
FROM orders AS o
INNER JOIN items AS i
        ON o.order_id = i.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp)
ORDER BY yearofpurchase, monthofpurchase;
-- Result: 20 rows, Jan 2017 - Aug 2018
-- Insight: revenue grew through 2017, peaked in Nov 2017 (~988K, likely Black Friday),
--          then plateaued around 830K-980K/month in 2018 (peak in May 2018, ~978K).
--          Jun-Aug 2018 dip slightly, but may be understated because late orders
--          may not be delivered yet.


-- Q2: By what percentage did revenue grow or shrink compared to the previous month (MoM)?
WITH monthly_revenue AS (
    SELECT
        YEAR(o.order_purchase_timestamp)  AS year_of_order,
        MONTH(o.order_purchase_timestamp) AS month_of_order,
        CAST(SUM(i.price) AS DECIMAL(18,2)) AS revenue
    FROM orders AS o
    INNER JOIN items AS i
            ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp)
)
SELECT
    year_of_order,
    month_of_order,
    revenue,
    LAG(revenue) OVER (ORDER BY year_of_order, month_of_order) AS previous_month_revenue,
    CAST(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY year_of_order, month_of_order))
        / NULLIF(LAG(revenue) OVER (ORDER BY year_of_order, month_of_order), 0)
        AS DECIMAL(10,2)
    ) AS mom_growth_pct
FROM monthly_revenue
ORDER BY year_of_order, month_of_order;
-- Result: 20 rows; Jan 2017 = NULL (no previous month)
-- Insight: biggest jump = <month> (<x>%), followed by a drop of <x>% the next month,
--          so the Black Friday spike was temporary, not a new baseline.
--          2018 growth is much flatter: the business moved from fast growth to a plateau.
--          Early 2017 percentages are large mainly because the base is small.


-- Q3: How much does a customer spend per order on average (AOV), month by month?
-- COUNT(DISTINCT order_id) because one order can have several rows in items.
SELECT
    YEAR(o.order_purchase_timestamp)  AS year_of_order,
    MONTH(o.order_purchase_timestamp) AS month_of_order,
    CAST(SUM(i.price) AS DECIMAL(18,2)) AS revenue,
    COUNT(DISTINCT o.order_id)          AS number_of_orders,
    CAST(SUM(i.price) / COUNT(DISTINCT o.order_id) AS DECIMAL(10,2)) AS aov
FROM orders AS o
INNER JOIN items AS i
        ON o.order_id = i.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp)
ORDER BY year_of_order, month_of_order;
-- Result: 20 rows
-- Insight: AOV is ~<x> BRL and stays <stable / rising / falling> over time.
--          Revenue growth came mainly from <more orders / higher order value>.


-- Q4: How much revenue have we accumulated by the end of each month? (running total)
WITH monthly_revenue AS (
    SELECT
        YEAR(o.order_purchase_timestamp)  AS year_of_order,
        MONTH(o.order_purchase_timestamp) AS month_of_order,
        CAST(SUM(i.price) AS DECIMAL(18,2)) AS revenue
    FROM orders AS o
    INNER JOIN items AS i
            ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp)
)
SELECT
    year_of_order,
    month_of_order,
    revenue,
    CAST(SUM(revenue) OVER (
            ORDER BY year_of_order, month_of_order
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
         ) AS DECIMAL(18,2)) AS total_running_revenue
FROM monthly_revenue
ORDER BY year_of_order, month_of_order;
-- Result: 20 rows; last running total = <number> (must match the check below)
-- Insight: cumulative revenue reached ~<x>M BRL by Aug 2018; Nov 2017 (~988K) is the biggest month.

-- Q4 check: total revenue for the whole period (the reference number for all other checks)
SELECT CAST(SUM(i.price) AS DECIMAL(18,2)) AS total_revenue
FROM orders AS o
INNER JOIN items AS i
        ON o.order_id = i.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01';
-- Result: <number>
