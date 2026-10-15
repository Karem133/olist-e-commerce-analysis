/* =====================================================
   Table:   product_category (translation table)
   Phase:   Data Profiling
   Outcome: import problems + 2 missing translations (fixed in 02_cleaning/01_clean_product_category.sql)
   Note:    Q1-Q5 were run AFTER the import fix (header/empty row removed, columns renamed).
   ===================================================== */

-- Q0 (before the import fix): how many rows were loaded?
-- Result: 73 instead of 71 -> the header row and an empty row were loaded as data,
--         and the columns were named column1 / column2.

-- Q1: Size and uniqueness
SELECT
    COUNT(*)                                      AS total_rows,
    COUNT(DISTINCT product_category_name)         AS distinct_pt,
    COUNT(DISTINCT product_category_name_english) AS distinct_en
FROM product_category;
-- Result: 71 | 71 | 71 -> both names are unique

-- Q2: NULLs, empty strings and extra spaces
SELECT
    SUM(CASE WHEN product_category_name IS NULL
              OR LTRIM(RTRIM(product_category_name)) = '' THEN 1 ELSE 0 END)          AS bad_pt,
    SUM(CASE WHEN product_category_name_english IS NULL
              OR LTRIM(RTRIM(product_category_name_english)) = '' THEN 1 ELSE 0 END)  AS bad_en,
    SUM(CASE WHEN product_category_name <> LTRIM(RTRIM(product_category_name))
              OR product_category_name_english <> LTRIM(RTRIM(product_category_name_english))
             THEN 1 ELSE 0 END)                                                       AS rows_with_spaces
FROM product_category;
-- Result: 0 | 0 | 0

-- Q3: Which categories used in products have no translation?
SELECT p.product_category_name, COUNT(*) AS products_count
FROM products AS p
LEFT JOIN product_category AS pc
       ON p.product_category_name = pc.product_category_name
WHERE pc.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY products_count DESC;
-- Result: NULL = 610 | portateis_cozinha_e_preparadores_de_alimentos = 10 | pc_gamer = 3
-- Insight: 2 real categories are missing from the translation table (13 products);
--          the NULL row is not a translation problem (see Q4).

-- Q4: How many products have a NULL category?
SELECT COUNT(*) AS null_category_products
FROM products
WHERE product_category_name IS NULL;
-- Result: 610 (about 1.9% of 32,951 products)
-- Decision: label as 'unknown' in analysis (COALESCE) and in Power Query.
