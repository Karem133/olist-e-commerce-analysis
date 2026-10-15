/* =====================================================
   Block:   Sellers analysis (Q13)
   Rules: delivered orders only; Jan 2017 - Aug 2018; revenue = price (no freight)
   ===================================================== */


-- Q13: Who are the 10 top sellers by revenue, and how concentrated is revenue in them?
-- Seller state comes from sellers; shares are calculated over ALL sellers (before cutting
-- to 10 rows); ties in revenue are broken by seller_id so the ranking is stable.
WITH seller_revenue AS (
    SELECT
        s.seller_id,
        s.seller_state,
        COUNT(DISTINCT o.order_id)          AS number_of_orders,
        CAST(SUM(i.price) AS DECIMAL(18,2)) AS total_revenue
    FROM orders AS o
    INNER JOIN items AS i
            ON o.order_id = i.order_id
    INNER JOIN sellers AS s
            ON i.seller_id = s.seller_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY s.seller_id, s.seller_state
),
ranked AS (
    SELECT
        seller_id,
        seller_state,
        number_of_orders,
        total_revenue,
        CAST(100.0 * total_revenue / SUM(total_revenue) OVER () AS DECIMAL(5,2)) AS pct_of_total,
        CAST(100.0 * SUM(total_revenue) OVER (
                 ORDER BY total_revenue DESC, seller_id
                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
             / SUM(total_revenue) OVER () AS DECIMAL(5,2)) AS cumulative_pct
    FROM seller_revenue
)
SELECT TOP 10 *
FROM ranked
ORDER BY total_revenue DESC, seller_id;
-- Result: 10 rows; top seller = <seller_id> (<state>, <x>% of revenue);
--         top 10 sellers together = <cumulative_pct of row 10>% of total revenue
-- Insight: the top 10 sellers alone bring <x>% of revenue, so the platform depends on a
--          small group of sellers; most of them are located in <states>.
-- Limitation: ranking uses delivered orders from Jan 2017 to Aug 2018 only.
-- Recommendation: an account-management program for the top sellers and
--                 monitoring of their delivery performance.

-- Q13 check: total revenue across ALL sellers (must equal the Q4 check number)
SELECT CAST(SUM(i.price) AS DECIMAL(18,2)) AS total_revenue_all_sellers
FROM orders AS o
INNER JOIN items AS i
        ON o.order_id = i.order_id
INNER JOIN sellers AS s
        ON i.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01';
-- Result: <number>
