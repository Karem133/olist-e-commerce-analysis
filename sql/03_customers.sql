/* =====================================================
   Block:   Customers analysis (Q7 - Q8)
   Rules applied in every query:
   - delivered orders only; Jan 2017 - Aug 2018; revenue = price (no freight)
   - a customer is identified by customer_unique_id (NOT customer_id)
   ===================================================== */


-- Q7: What percentage of customers bought more than once?
-- "Repeat customer" = 2 or more delivered orders in this period.
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS count_order
    FROM orders AS o
    INNER JOIN customers AS c
            ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN count_order > 1 THEN 1 ELSE 0 END) AS repeated_customers,
    CAST(100.0 * SUM(CASE WHEN count_order > 1 THEN 1 ELSE 0 END)
         / COUNT(*) AS DECIMAL(5,2)) AS repeat_rate_pct,
    CAST(AVG(CASE WHEN count_order > 1 THEN count_order * 1.0 END)
         AS DECIMAL(10,2)) AS avg_orders_per_repeat_customer
FROM customer_orders;
-- Result: total_customers = 93,103 | repeated_customers = 2,789 | repeat_rate = 3.00% | avg orders per repeat customer = 2.11
-- Insight: 97% of customers bought only once, and repeat customers placed ~2 orders on average.
--          Growth depends almost entirely on acquiring new customers, not on retention.
-- Limitation: customers acquired late in the period had less time to come back,
--             so the real repeat rate may be slightly higher.
-- Recommendation: test a retention action (e.g., a discount on the second purchase)
--                 and use RFM later to find which customers are worth targeting.


-- Q8: Which 10 states bring the most revenue? (customers, orders, revenue per customer, share of total)
-- State comes from customers (not geolocation). The share is calculated over ALL states
-- first, then TOP 10 is applied.
WITH state_stats AS (
    SELECT
        c.customer_state,
        COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
        COUNT(DISTINCT o.order_id)           AS number_of_orders,
        CAST(SUM(i.price) AS DECIMAL(18,2))  AS total_price,
        CAST(SUM(i.price) / COUNT(DISTINCT c.customer_unique_id) AS DECIMAL(10,2)) AS avg_customer_spend,
        CAST(100.0 * SUM(i.price) / SUM(SUM(i.price)) OVER () AS DECIMAL(5,2))     AS pct_of_total
    FROM orders AS o
    INNER JOIN customers AS c
            ON c.customer_id = o.customer_id
    INNER JOIN items AS i
            ON i.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY c.customer_state
)
SELECT TOP 10 *
FROM state_stats
ORDER BY total_price DESC;
-- Result: 10 rows; top state = <state> (<x>% of revenue); top 3 together = <x>%
-- Insight: revenue is concentrated in a few states, led by <state>.
--          Revenue per customer is highest in <state> and lowest in <state>.
-- Recommendation: <state> is the core market; consider growth actions in states
--                 with high revenue per customer but few customers.

-- Q8 check: total revenue across ALL states (must equal the Q4 check number)
-- Run the CTE above with this final SELECT instead of the TOP 10:
--   SELECT CAST(SUM(total_price) AS DECIMAL(18,2)) AS total_all_states FROM state_stats;
-- Result: <number>
