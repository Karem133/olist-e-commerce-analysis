/* =====================================================
   Table:   customers
   Phase:   Data Profiling
   Outcome: no cleaning required
   ===================================================== */

-- Q1: Size and uniqueness of customer_id vs customer_unique_id
SELECT
    COUNT(*)                           AS total_rows,
    COUNT(DISTINCT customer_id)        AS distinct_customer_id,
    COUNT(DISTINCT customer_unique_id) AS distinct_customer_unique_id,
    COUNT(DISTINCT customer_id) - COUNT(DISTINCT customer_unique_id) AS difference
FROM customers;
-- Result: 99,441 | 99,441 | 96,096 | 3,345   (check: 99,441 - 3,345 = 96,096)
-- Insight: customer_id is generated per order (unique, links to orders);
--          customer_unique_id is the real customer. The 3,345 extra IDs come from repeat purchases.
-- Decision: use customer_unique_id for every customer-level analysis.

-- Q2: Are there NULLs in any column?
SELECT
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END)              AS null_customer_id,
    SUM(CASE WHEN customer_unique_id IS NULL THEN 1 ELSE 0 END)       AS null_customer_unique_id,
    SUM(CASE WHEN customer_zip_code_prefix IS NULL THEN 1 ELSE 0 END) AS null_zip,
    SUM(CASE WHEN customer_city IS NULL THEN 1 ELSE 0 END)            AS null_city,
    SUM(CASE WHEN customer_state IS NULL THEN 1 ELSE 0 END)           AS null_state
FROM customers;
-- Result: 0 | 0 | 0 | 0 | 0 -> no NULLs

-- Q3: How many real customers appear more than once in the table?
-- (note: this counts customer_id rows, not orders; the repeat purchase rate is in the analysis phase)
SELECT COUNT(*) AS customers_with_several_ids
FROM (
    SELECT customer_unique_id
    FROM customers
    GROUP BY customer_unique_id
    HAVING COUNT(*) > 1
) AS t;
-- Result: <n>

-- Q4: Which customer has the most customer_id values?
SELECT TOP 1 customer_unique_id, COUNT(*) AS ids_count
FROM customers
GROUP BY customer_unique_id
ORDER BY ids_count DESC;
-- Result: 8d50f5eadf50201ccdcedfb9e2ac8455 | <n>

-- Q5: How many states, and are they all 2 characters?
SELECT
    COUNT(DISTINCT customer_state) AS distinct_states,
    SUM(CASE WHEN LEN(customer_state) <> 2 THEN 1 ELSE 0 END) AS states_not_2_chars
FROM customers;
-- Result: 27 | 0
-- Note: LEN() ignores trailing spaces, so a value like 'SP ' would not be caught.

-- Q6: Which 5 states have the most customers?
SELECT TOP 5
    customer_state,
    COUNT(DISTINCT customer_unique_id) AS number_of_customers
FROM customers
GROUP BY customer_state
ORDER BY number_of_customers DESC;
-- Result: SP = <n>, <state> = <n>, <state> = <n>, <state> = <n>, <state> = <n>
-- Insight: SP has by far the most customers.

-- Q7: How many distinct cities?
SELECT COUNT(DISTINCT customer_city) AS number_of_cities
FROM customers;
-- Result: 4,119
-- Decision: city names may have spelling variants, so geographic analysis is done at state level.
