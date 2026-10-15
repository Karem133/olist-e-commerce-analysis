/* =====================================================
   Block:   Products analysis (Q5 - Q6)
   Rules applied in every query:
   - delivered orders only; Jan 2017 - Aug 2018; revenue = price (no freight)
   - NULL category -> 'unknown'
   - one review score per order = the latest review (same rule as Q11/Q12)
   ===================================================== */


-- Q5: Which 10 categories bring the most revenue, and what share of TOTAL revenue is each?
-- The share is calculated over ALL categories first, then TOP 10 is applied.
WITH category_revenue AS (
    SELECT
        COALESCE(c.product_category_name_english, 'unknown') AS category_product,
        CAST(SUM(i.price) AS DECIMAL(18,2)) AS revenue,
        CAST(100.0 * SUM(i.price) / SUM(SUM(i.price)) OVER () AS DECIMAL(5,2)) AS pct_of_total
    FROM orders AS o
    INNER JOIN items AS i
            ON i.order_id = o.order_id
    INNER JOIN products AS p
            ON p.product_id = i.product_id
    LEFT JOIN clean_product_category AS c
           ON c.product_category_name = p.product_category_name
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY COALESCE(c.product_category_name_english, 'unknown')
)
SELECT TOP 10 category_product, revenue, pct_of_total
FROM category_revenue
ORDER BY revenue DESC;
-- Result: 10 rows; top category = <name> (<x>%); top 10 together = <sum of pct>%
-- Insight: revenue is concentrated in a few categories: the top 10 produce ~<x>% of total
--          revenue out of ~70 categories. 'unknown' is / is not in the top 10.
-- Decision: focus the Products page in Power BI on the top 10, with the rest grouped as 'Other'.

-- Q5 check: total revenue through the same joins (must equal the Q4 check number)
SELECT CAST(SUM(i.price) AS DECIMAL(18,2)) AS total_revenue
FROM orders AS o
INNER JOIN items AS i
        ON i.order_id = o.order_id
INNER JOIN products AS p
        ON p.product_id = i.product_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01';
-- Result: <number>


-- Q6: Among the top 10 revenue categories, which have the lowest average review score?
-- Joining reviews directly would multiply revenue, so reviews are reduced to one row per
-- order first, and revenue is summed per (order, category) before averaging.
WITH order_reviews AS (
    SELECT order_id, review_score
    FROM (
        SELECT order_id,
               review_score,
               ROW_NUMBER() OVER (PARTITION BY order_id
                                  ORDER BY review_answer_timestamp DESC, review_id DESC) AS rn
        FROM reviews
    ) AS t
    WHERE rn = 1
),
order_category AS (
    SELECT
        o.order_id,
        COALESCE(c.product_category_name_english, 'unknown') AS category,
        SUM(i.price)        AS revenue,
        MAX(r.review_score) AS review_score
    FROM orders AS o
    INNER JOIN items AS i
            ON o.order_id = i.order_id
    INNER JOIN products AS p
            ON i.product_id = p.product_id
    LEFT JOIN clean_product_category AS c
           ON p.product_category_name = c.product_category_name
    LEFT JOIN order_reviews AS r
           ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY o.order_id, COALESCE(c.product_category_name_english, 'unknown')
),
category_stats AS (
    SELECT
        category,
        CAST(SUM(revenue) AS DECIMAL(18,2))     AS revenue,
        COUNT(*)                                AS number_of_orders,
        CAST(AVG(review_score * 1.0) AS DECIMAL(3,2)) AS avg_review_score
    FROM order_category
    GROUP BY category
),
top10 AS (
    SELECT TOP 10 *
    FROM category_stats
    ORDER BY revenue DESC
)
SELECT category, revenue, number_of_orders, avg_review_score
FROM top10
ORDER BY avg_review_score ASC;
-- Result: 10 rows (same categories as Q5); lowest score = <category> (<x>), highest = <category> (<x>)
-- Insight: <category> is a top-10 revenue category with the lowest average rating
--          (<x> vs <y> for the others), so it is the first one to investigate.
-- Limitation: a review belongs to the whole order, so multi-category orders share one score;
--             orders without a review are excluded from the average (not counted as 0).
