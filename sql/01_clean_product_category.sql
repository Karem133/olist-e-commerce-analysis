/* =====================================================
   Table:   product_category
   Phase:   Data Cleaning
   Purpose: Fix the issues found in 01_profiling/02_product_category.sql
   Note:    Steps 1-3 were already executed once. This file documents what was done;
            do not re-run them on the cleaned table.
   ===================================================== */

/* Issues found in profiling
   1. Header row and an empty row were loaded as data (73 rows instead of 71)
   2. Columns were imported as column1 / column2
   3. Translation table is missing 2 categories used in products
   4. 610 products have a NULL category (handled with COALESCE -> 'unknown' in analysis) */

-- Step 1: Remove the header row and the empty row (71 valid rows remain)
DELETE FROM product_category
WHERE column1 = 'product_category_name'
   OR column1 IS NULL
   OR LTRIM(RTRIM(column1)) = '';

-- Step 2: Rename the columns
-- (the old names contain the table name because of a first rename attempt, hence the brackets)
EXEC sp_rename 'product_category.[product_category.product_category_name]',
               'product_category_name', 'COLUMN';
EXEC sp_rename 'product_category.[product_category.product_category_name_english]',
               'product_category_name_english', 'COLUMN';
GO

-- Step 3: Clean view = original translations + the 2 missing ones (71 + 2 = 73 rows)
-- The original table is left untouched. Use ALTER VIEW if the view already exists.
CREATE VIEW clean_product_category AS
SELECT product_category_name, product_category_name_english
FROM product_category
UNION ALL
SELECT 'pc_gamer', 'pc_gaming'
UNION ALL
SELECT 'portateis_cozinha_e_preparadores_de_alimentos',
       'portable_kitchen_and_food_preparers';
GO

-- Validation 1: the view should contain 73 rows
SELECT COUNT(*) AS total_rows
FROM clean_product_category;
-- Result: 73

-- Validation 2: every non-NULL category in products should now have a translation
SELECT DISTINCT p.product_category_name
FROM products AS p
LEFT JOIN clean_product_category AS c
       ON p.product_category_name = c.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND c.product_category_name IS NULL;
-- Result: 0 rows -> all categories translated
