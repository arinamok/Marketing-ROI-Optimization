-- Data Cleaning
USE MarketingTesting

SELECT * FROM marketing_AB_sample

-- Check the datatypes
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'marketing_AB_sample';


-- 1. Fix the Decimal/Money columns (Changing from float to decimal)
ALTER TABLE marketing_AB_sample ALTER COLUMN revenue DECIMAL(10,2);
ALTER TABLE marketing_AB_sample ALTER COLUMN cost_per_impression DECIMAL(10,4);
ALTER TABLE marketing_AB_sample ALTER COLUMN total_cost DECIMAL(10,2);
ALTER TABLE marketing_AB_sample ALTER COLUMN profit DECIMAL(10,2);
ALTER TABLE marketing_AB_sample ALTER COLUMN roi DECIMAL(10,4);

-- 2. Fix the Integer columns (Changing smallint/tinyint to standard INT)
-- This prevents the '32768' error from happening again if you add more data
ALTER TABLE marketing_AB_sample ALTER COLUMN total_ads INT;
ALTER TABLE marketing_AB_sample ALTER COLUMN most_ads_hour INT;
-- Null Check
SELECT 
    COUNT(*) AS total_rows,
    SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END) AS null_user_id,
    SUM(CASE WHEN test_group IS NULL THEN 1 ELSE 0 END) AS null_test_group,
    SUM(CASE WHEN converted IS NULL THEN 1 ELSE 0 END) AS null_converted
FROM marketing_AB_sample;

-- Overall Comparison KPIs
-- conversion rate, revenue, total_cost, profit, ROI by test group
SELECT
    test_group,
    COUNT(*) AS total_users,
    SUM(CAST(converted AS INT)) AS total_conversions,
    CAST(SUM(CAST(converted AS INT))*100.0/COUNT(*) AS DECIMAL(5,2)) AS conversion_rate_pct,
    SUM(revenue) AS total_revenue,
    SUM(total_cost) AS total_cost,
    SUM(profit) AS total_profit,
    AVG(roi) AS avg_roi
FROM marketing_AB_sample
GROUP BY test_group;


-- Categorize total_ads into 3 buckets
SELECT
    CASE 
        WHEN total_ads BETWEEN 0 AND 50 THEN '0-50'
        WHEN total_ads BETWEEN 51 AND 200 THEN '51-200'
        ELSE '200+' 
    END AS ads_bucket,
    COUNT(*) AS total_users,
    SUM(CAST(converted AS INT)) AS total_conversions,
    CAST(SUM(CAST(converted AS INT))*100.0/COUNT(*) AS DECIMAL(5,2)) AS conversion_rate_pct,
    SUM(profit) AS total_profit
FROM marketing_AB_sample
GROUP BY 
    CASE 
        WHEN total_ads BETWEEN 0 AND 50 THEN '0-50'
        WHEN total_ads BETWEEN 51 AND 200 THEN '51-200'
        ELSE '200+' 
    END;


-- Time Analysis
-- Conversion rate by most_ads_day
SELECT
    most_ads_day,
    COUNT(*) AS total_users,
    SUM(CAST(converted AS INT)) AS total_conversions,
    CAST(SUM(CAST(converted AS INT))*100.0/COUNT(*) AS DECIMAL(5,2)) AS conversion_rate_pct
FROM marketing_AB_sample
GROUP BY most_ads_day
ORDER BY CASE most_ads_day
             WHEN 'Monday' THEN 1
             WHEN 'Tuesday' THEN 2
             WHEN 'Wednesday' THEN 3
             WHEN 'Thursday' THEN 4
             WHEN 'Friday' THEN 5
             WHEN 'Saturday' THEN 6
             WHEN 'Sunday' THEN 7
         END;

-- Conversion rate by most_ads_hour
SELECT
    most_ads_hour,
    COUNT(*) AS total_users,
    SUM(CAST(converted AS INT)) AS total_conversions,
    CAST(SUM(CAST(converted AS INT))*100.0/COUNT(*) AS DECIMAL(5,2)) AS conversion_rate_pct
FROM marketing_AB_sample
GROUP BY most_ads_hour
ORDER BY total_users DESC; -- shows which hours had the most users seeing ads


SELECT
    most_ads_hour,
    COUNT(*) AS total_users,
    SUM(CAST(converted AS INT)) AS total_conversions,
    CAST(SUM(CAST(converted AS INT))*100.0/COUNT(*) AS DECIMAL(5,2)) AS conversion_rate_pct
FROM marketing_AB_sample
GROUP BY most_ads_hour
ORDER BY total_conversions DESC; -- to sort by highest money made

SELECT
    most_ads_hour,
    COUNT(*) AS total_users,
    SUM(CAST(converted AS INT)) AS total_conversions,
    CAST(SUM(CAST(converted AS INT))*100.0/COUNT(*) AS DECIMAL(5,2)) AS conversion_rate_pct
FROM marketing_AB_sample
GROUP BY most_ads_hour
ORDER BY conversion_rate_pct DESC; -- to see which hours are most effective at turning viewers into conversions



SELECT user_id, test_group, converted, total_ads, most_ads_hour
FROM marketing_AB_sample;
