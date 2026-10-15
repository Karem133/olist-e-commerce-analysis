/* =====================================================
   Table:   geolocation
   Phase:   Data Profiling
   Note:    No primary key: one zip code has many GPS points.
            Not used in the SQL analysis (state comes from customers / sellers).
            Cleaning is deferred to Power Query, only needed for the map.
   ===================================================== */

-- Q1: Size, distinct zip codes and fully duplicated rows
SELECT
    COUNT(*)                                          AS total_rows,
    COUNT(DISTINCT geolocation_zip_code_prefix)       AS distinct_zip_codes,
    (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM geolocation) AS t) AS distinct_full_rows
FROM geolocation;
-- Result: 1,000,163 | <n> | <n>   (duplicate rows = total_rows - distinct_full_rows)
-- Insight: far fewer zips than rows -> many GPS points per zip, and many exact duplicates.
-- Decision: aggregate to one row per zip (average lat/lng) in Power Query.

-- Q2: NULLs in any column
SELECT
    SUM(CASE WHEN geolocation_zip_code_prefix IS NULL THEN 1 ELSE 0 END) AS null_zip,
    SUM(CASE WHEN geolocation_lat IS NULL THEN 1 ELSE 0 END)             AS null_lat,
    SUM(CASE WHEN geolocation_lng IS NULL THEN 1 ELSE 0 END)             AS null_lng,
    SUM(CASE WHEN geolocation_city IS NULL THEN 1 ELSE 0 END)            AS null_city,
    SUM(CASE WHEN geolocation_state IS NULL THEN 1 ELSE 0 END)           AS null_state
FROM geolocation;
-- Result: 0 | 0 | 0 | 0 | 0 -> no NULLs

-- Q3: Data type of the zip column in the three tables that use it
-- (a type mismatch can break relationships in Power BI; INT also loses leading zeros)
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME IN ('geolocation_zip_code_prefix',
                      'customer_zip_code_prefix',
                      'seller_zip_code_prefix');
-- Result: geolocation = <type>, customers = <type>, sellers = <type>
-- Decision: make the three columns the same type in Power Query.

-- Q4: Rows with coordinates outside Brazil
SELECT COUNT(*) AS outside_brazil
FROM geolocation
WHERE geolocation_lat NOT BETWEEN -33.75 AND 5.27
   OR geolocation_lng NOT BETWEEN -73.99 AND -34.79;
-- Result: <n>
-- Decision: if > 0, filter them out BEFORE averaging the coordinates.

-- Q5: Zip codes mapped to more than one city
SELECT COUNT(*) AS zips_with_multiple_cities
FROM (
    SELECT geolocation_zip_code_prefix
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix
    HAVING COUNT(DISTINCT geolocation_city) > 1
) AS t;
-- Result: <n>
-- Insight: usually spelling variants (sao paulo / são paulo).
-- Decision: keep the most frequent city per zip.

-- Q6: Coverage - customer zip codes and customers missing from geolocation
SELECT
    COUNT(DISTINCT c.customer_zip_code_prefix) AS missing_customer_zips,
    COUNT(*)                                   AS affected_customer_ids,
    CAST(100.0 * COUNT(*) / (SELECT COUNT(*) FROM customers) AS DECIMAL(5,2)) AS pct_of_customers
FROM customers AS c
WHERE NOT EXISTS (
    SELECT 1
    FROM geolocation AS g
    WHERE g.geolocation_zip_code_prefix = c.customer_zip_code_prefix
);
-- Result: <n> | <n> | <x>%

-- Q7: Coverage - seller zip codes missing from geolocation
SELECT COUNT(DISTINCT s.seller_zip_code_prefix) AS missing_seller_zips
FROM sellers AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM geolocation AS g
    WHERE g.geolocation_zip_code_prefix = s.seller_zip_code_prefix
);
-- Result: 7
-- Decision: when attaching geolocation use a LEFT JOIN (never INNER JOIN);
--           use customer_state / seller_state for state-level analysis.
