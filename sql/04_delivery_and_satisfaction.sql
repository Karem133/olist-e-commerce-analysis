/* =====================================================
   Block:   Delivery and satisfaction (Q9 - Q12)
   Rules applied in every query:
   - delivered orders only; Jan 2017 - Aug 2018; only orders with a delivery date
   - delivery time = days from purchase to the customer receiving the order
   - late = delivered on a later calendar day than the estimated date
     (DATEDIFF(DAY) counts calendar-day boundaries, not full 24-hour periods)
   - review score = the latest review per order
   ===================================================== */


-- Q9: Average delivery time and late delivery rate
SELECT
    COUNT(*) AS total_orders_delivered,
    SUM(CASE WHEN DATEDIFF(DAY, o.order_estimated_delivery_date,
                                o.order_delivered_customer_date) > 0
             THEN 1 ELSE 0 END) AS number_of_late_orders,
    CAST(AVG(DATEDIFF(DAY, o.order_purchase_timestamp,
                           o.order_delivered_customer_date) * 1.0)
         AS DECIMAL(10,2)) AS avg_delivery_days,
    CAST(100.0 * SUM(CASE WHEN DATEDIFF(DAY, o.order_estimated_delivery_date,
                                             o.order_delivered_customer_date) > 0
                          THEN 1 ELSE 0 END)
         / COUNT(*) AS DECIMAL(5,2)) AS late_delivery_rate_pct
FROM orders AS o
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01';
-- Result: total_orders_delivered = <n> | late orders = <n> | avg delivery = <x> days | late rate = <x>%
-- Insight: orders take about <x> days to arrive and <x>% arrive after the estimated date.
-- Limitation: <n> delivered orders without a delivery date were excluded.


-- Q10: Top 5 slowest states for delivery vs the national average
-- Ranked by average delivery days; states with fewer than 100 orders excluded;
-- national average = total delivery days / total orders (not an average of averages).
-- The 100-order filter is applied at the end so the national average still uses ALL states.
WITH state_delivery AS (
    SELECT
        c.customer_state,
        COUNT(*) AS number_of_delivered_orders,
        SUM(DATEDIFF(DAY, o.order_purchase_timestamp,
                          o.order_delivered_customer_date)) AS total_days,
        SUM(CASE WHEN DATEDIFF(DAY, o.order_estimated_delivery_date,
                                    o.order_delivered_customer_date) > 0
                 THEN 1 ELSE 0 END) AS late_orders
    FROM orders AS o
    INNER JOIN customers AS c
            ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY c.customer_state
),
state_stats AS (
    SELECT
        customer_state,
        number_of_delivered_orders,
        CAST(total_days * 1.0 / number_of_delivered_orders AS DECIMAL(10,2)) AS avg_delivery_days,
        CAST(100.0 * late_orders / number_of_delivered_orders AS DECIMAL(5,2)) AS late_delivery_rate,
        CAST(SUM(total_days) OVER () * 1.0
             / SUM(number_of_delivered_orders) OVER () AS DECIMAL(10,2)) AS national_avg_days,
        CAST(total_days * 1.0 / number_of_delivered_orders
             - SUM(total_days) OVER () * 1.0
               / SUM(number_of_delivered_orders) OVER () AS DECIMAL(10,2)) AS days_vs_national_avg
    FROM state_delivery
)
SELECT TOP 5 *
FROM state_stats
WHERE number_of_delivered_orders >= 100
ORDER BY avg_delivery_days DESC;
-- Result: 5 rows; slowest = <state> (<x> days, <y> days slower than the national average of <z>)
-- Insight: the slowest states are <states>; their late rate is <x>% vs <y>% nationally.
-- Limitation: states with fewer than 100 delivered orders were excluded (<n> states).
-- Recommendation: review delivery estimates for these states, or recruit sellers closer to them.


-- Q11: Review score distribution (1 to 5)
-- Orders without a review are not part of the distribution.
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
reviewed_orders AS (
    SELECT o.order_id, r.review_score
    FROM orders AS o
    INNER JOIN order_reviews AS r
            ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
)
SELECT
    review_score,
    COUNT(*) AS total_orders,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct_of_reviewed_orders
FROM reviewed_orders
GROUP BY review_score
ORDER BY review_score;
-- Result: 5 rows; 5 stars = <x>%; 1 star = <x>%
-- Insight: ratings are polarized: most customers give 5, and a noticeable group gives 1.
-- Limitation: <n> delivered orders (<x>%) have no review.


-- Q11b: Review summary (average score, % satisfied, % unsatisfied)
-- satisfied = score 4 or 5; unsatisfied = score 1 or 2; score 3 = neutral.
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
reviewed_orders AS (
    SELECT o.order_id, r.review_score
    FROM orders AS o
    INNER JOIN order_reviews AS r
            ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
)
SELECT
    COUNT(*) AS reviewed_orders,
    CAST(AVG(review_score * 1.0) AS DECIMAL(3,2)) AS avg_review_score,
    CAST(100.0 * SUM(CASE WHEN review_score >= 4 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS pct_satisfied,
    CAST(100.0 * SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS pct_unsatisfied
FROM reviewed_orders;
-- Result: reviewed orders = <n> | avg = <x> | satisfied (4-5) = <x>% | unsatisfied (1-2) = <x>%
-- Insight: most customers are satisfied, but about <x>% are unhappy (1-2 stars).


-- Q12: Do late deliveries get lower review scores than on-time deliveries?
-- The comparison covers reviewed orders only.
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
reviewed_orders AS (
    SELECT
        o.order_id,
        r.review_score,
        CASE WHEN DATEDIFF(DAY, o.order_estimated_delivery_date,
                                o.order_delivered_customer_date) > 0
             THEN 'late' ELSE 'on_time' END AS delivery_status
    FROM orders AS o
    INNER JOIN order_reviews AS r
            ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
)
SELECT
    delivery_status,
    COUNT(*) AS number_of_orders,
    CAST(AVG(review_score * 1.0) AS DECIMAL(3,2)) AS avg_review_score,
    CAST(100.0 * SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS pct_unsatisfied
FROM reviewed_orders
GROUP BY delivery_status
ORDER BY delivery_status DESC;
-- Result: late = <n> orders, avg <x>, <x>% unsatisfied | on_time = <n> orders, avg <x>, <x>% unsatisfied
-- Insight: late orders score <x> points lower and are <x> times more likely to get 1-2 stars.
-- Limitation: correlation, not proof of causation (product quality also affects ratings),
--             but delivery is the factor the platform can control.
-- Recommendation: improve delivery in the slowest states (Q10) to raise satisfaction.

-- Q12b: Does the score keep falling as the delay grows?
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
reviewed_orders AS (
    SELECT
        r.review_score,
        DATEDIFF(DAY, o.order_estimated_delivery_date,
                      o.order_delivered_customer_date) AS days_late
    FROM orders AS o
    INNER JOIN order_reviews AS r
            ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
),
banded AS (
    SELECT
        review_score,
        CASE WHEN days_late <= 0 THEN '1. on time'
             WHEN days_late <= 3 THEN '2. 1-3 days late'
             WHEN days_late <= 7 THEN '3. 4-7 days late'
             ELSE '4. more than 7 days late' END AS delay_band
    FROM reviewed_orders
)
SELECT
    delay_band,
    COUNT(*) AS number_of_orders,
    CAST(AVG(review_score * 1.0) AS DECIMAL(3,2)) AS avg_review_score
FROM banded
GROUP BY delay_band
ORDER BY delay_band;
-- Result: 4 rows
-- Insight: the average score falls from <x> (on time) to <x> (more than 7 days late).
