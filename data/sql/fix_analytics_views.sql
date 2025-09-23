-- Fix ambiguous column names in analytics views
-- Drop existing views first
DROP VIEW IF EXISTS hourly_data;
DROP VIEW IF EXISTS daily_data;
DROP VIEW IF EXISTS monthly_data;
DROP VIEW IF EXISTS time_of_use_data;
DROP VIEW IF EXISTS usage_patterns;
DROP VIEW IF EXISTS efficiency_metrics;

-- Create comprehensive hourly aggregation view (fixed)
CREATE VIEW hourly_data AS
SELECT
    p.datum,
    strftime('%H', p.vrijeme) as hour,
    strftime('%Y-%m-%d %H:00:00', p.datum || ' ' || strftime('%H', p.vrijeme) || ':00:00') as datetime_hour,
    SUM(p.energija) as consumed_kwh,
    SUM(r.energija) as produced_kwh,
    SUM(p.energija) - SUM(r.energija) as net_kwh,
    AVG(p.snaga) as avg_power_consumed,
    AVG(r.snaga) as avg_power_produced,
    MAX(p.snaga) as peak_power_consumed,
    MAX(r.snaga) as peak_power_produced,
    COUNT(*) as readings_count
FROM p
JOIN r ON p.datum = r.datum AND p.vrijeme = r.vrijeme
GROUP BY p.datum, strftime('%H', p.vrijeme);

-- Create daily aggregation view (fixed)
CREATE VIEW daily_data AS
SELECT
    p.datum,
    strftime('%Y', p.datum) as year,
    strftime('%m', p.datum) as month,
    strftime('%w', p.datum) as day_of_week, -- 0=Sunday, 1-6=Mon-Sat
    CASE strftime('%w', p.datum)
        WHEN '0' THEN 'Sunday'
        WHEN '1' THEN 'Monday'
        WHEN '2' THEN 'Tuesday'
        WHEN '3' THEN 'Wednesday'
        WHEN '4' THEN 'Thursday'
        WHEN '5' THEN 'Friday'
        WHEN '6' THEN 'Saturday'
    END as day_name,
    CASE WHEN strftime('%w', p.datum) IN ('0', '6') THEN 'Weekend' ELSE 'Weekday' END as day_type,
    SUM(p.energija) as consumed_kwh,
    SUM(r.energija) as produced_kwh,
    SUM(p.energija) - SUM(r.energija) as net_kwh,
    AVG(p.snaga) as avg_power_consumed,
    AVG(r.snaga) as avg_power_produced,
    MAX(p.snaga) as peak_power_consumed,
    MAX(r.snaga) as peak_power_produced,
    -- Self-consumption metrics
    CASE WHEN SUM(r.energija) > 0 THEN
        ROUND((SUM(p.energija) / (SUM(p.energija) + SUM(r.energija))) * 100, 2)
        ELSE 100
    END as self_consumption_ratio,
    CASE WHEN SUM(p.energija) > 0 THEN
        ROUND((SUM(r.energija) / SUM(p.energija)) * 100, 2)
        ELSE 0
    END as production_ratio
FROM p
JOIN r ON p.datum = r.datum AND p.vrijeme = r.vrijeme
GROUP BY p.datum;

-- Create monthly aggregation view (fixed)
CREATE VIEW monthly_data AS
SELECT
    strftime('%Y-%m', p.datum) as month_year,
    strftime('%Y', p.datum) as year,
    strftime('%m', p.datum) as month,
    CASE strftime('%m', p.datum)
        WHEN '01' THEN 'January' WHEN '02' THEN 'February' WHEN '03' THEN 'March'
        WHEN '04' THEN 'April' WHEN '05' THEN 'May' WHEN '06' THEN 'June'
        WHEN '07' THEN 'July' WHEN '08' THEN 'August' WHEN '09' THEN 'September'
        WHEN '10' THEN 'October' WHEN '11' THEN 'November' WHEN '12' THEN 'December'
    END as month_name,
    MIN(p.datum) as start_date,
    MAX(p.datum) as end_date,
    COUNT(DISTINCT p.datum) as days_count,
    SUM(p.energija) as consumed_kwh,
    SUM(r.energija) as produced_kwh,
    SUM(p.energija) - SUM(r.energija) as net_kwh,
    AVG(p.snaga) as avg_power_consumed,
    AVG(r.snaga) as avg_power_produced,
    MAX(p.snaga) as peak_power_consumed,
    MAX(r.snaga) as peak_power_produced,
    -- Calculate daily averages
    ROUND(SUM(p.energija) / COUNT(DISTINCT p.datum), 2) as avg_daily_consumed,
    ROUND(SUM(r.energija) / COUNT(DISTINCT p.datum), 2) as avg_daily_produced,
    ROUND((SUM(p.energija) - SUM(r.energija)) / COUNT(DISTINCT p.datum), 2) as avg_daily_net,
    -- Self-consumption metrics
    CASE WHEN SUM(r.energija) > 0 THEN
        ROUND((SUM(p.energija) / (SUM(p.energija) + SUM(r.energija))) * 100, 2)
        ELSE 100
    END as self_consumption_ratio,
    CASE WHEN SUM(p.energija) > 0 THEN
        ROUND((SUM(r.energija) / SUM(p.energija)) * 100, 2)
        ELSE 0
    END as production_ratio
FROM p
JOIN r ON p.datum = r.datum AND p.vrijeme = r.vrijeme
GROUP BY strftime('%Y-%m', p.datum);

-- Create time-of-use analysis view (Croatian peak/off-peak hours) (fixed)
CREATE VIEW time_of_use_data AS
SELECT
    p.datum,
    strftime('%H', p.vrijeme) as hour,
    CASE
        WHEN CAST(strftime('%H', p.vrijeme) AS INTEGER) BETWEEN 7 AND 21 THEN 'Peak'
        ELSE 'Off-Peak'
    END as tariff_period,
    CASE
        WHEN CAST(strftime('%H', p.vrijeme) AS INTEGER) BETWEEN 6 AND 10 THEN 'Morning'
        WHEN CAST(strftime('%H', p.vrijeme) AS INTEGER) BETWEEN 10 AND 16 THEN 'Midday'
        WHEN CAST(strftime('%H', p.vrijeme) AS INTEGER) BETWEEN 16 AND 22 THEN 'Evening'
        ELSE 'Night'
    END as time_period,
    SUM(p.energija) as consumed_kwh,
    SUM(r.energija) as produced_kwh,
    SUM(p.energija) - SUM(r.energija) as net_kwh
FROM p
JOIN r ON p.datum = r.datum AND p.vrijeme = r.vrijeme
GROUP BY p.datum, strftime('%H', p.vrijeme);

-- Create usage patterns view for different time dimensions (fixed)
CREATE VIEW usage_patterns AS
SELECT
    'Hourly' as pattern_type,
    strftime('%H', p.vrijeme) as time_unit,
    strftime('%H', p.vrijeme) || ':00' as time_label,
    AVG(p.energija) as avg_consumed_kwh,
    AVG(r.energija) as avg_produced_kwh,
    AVG(p.energija) - AVG(r.energija) as avg_net_kwh,
    COUNT(*) as sample_count
FROM p
JOIN r ON p.datum = r.datum AND p.vrijeme = r.vrijeme
GROUP BY strftime('%H', p.vrijeme)

UNION ALL

SELECT
    'Daily' as pattern_type,
    strftime('%w', datum) as time_unit,
    CASE strftime('%w', datum)
        WHEN '0' THEN 'Sunday' WHEN '1' THEN 'Monday' WHEN '2' THEN 'Tuesday'
        WHEN '3' THEN 'Wednesday' WHEN '4' THEN 'Thursday' WHEN '5' THEN 'Friday'
        WHEN '6' THEN 'Saturday'
    END as time_label,
    AVG(consumed_kwh) as avg_consumed_kwh,
    AVG(produced_kwh) as avg_produced_kwh,
    AVG(net_kwh) as avg_net_kwh,
    COUNT(*) as sample_count
FROM daily_data
GROUP BY strftime('%w', datum)

UNION ALL

SELECT
    'Monthly' as pattern_type,
    strftime('%m', datum) as time_unit,
    CASE strftime('%m', datum)
        WHEN '01' THEN 'Jan' WHEN '02' THEN 'Feb' WHEN '03' THEN 'Mar'
        WHEN '04' THEN 'Apr' WHEN '05' THEN 'May' WHEN '06' THEN 'Jun'
        WHEN '07' THEN 'Jul' WHEN '08' THEN 'Aug' WHEN '09' THEN 'Sep'
        WHEN '10' THEN 'Oct' WHEN '11' THEN 'Nov' WHEN '12' THEN 'Dec'
    END as time_label,
    AVG(consumed_kwh) as avg_consumed_kwh,
    AVG(produced_kwh) as avg_produced_kwh,
    AVG(net_kwh) as avg_net_kwh,
    COUNT(*) as sample_count
FROM daily_data
GROUP BY strftime('%m', datum);

-- Create energy efficiency metrics view (fixed)
CREATE VIEW efficiency_metrics AS
SELECT
    datum,
    consumed_kwh,
    produced_kwh,
    net_kwh,
    -- Energy independence (% of consumption covered by production)
    CASE WHEN consumed_kwh > 0 THEN
        ROUND(CASE WHEN (produced_kwh / consumed_kwh * 100) < 100
              THEN (produced_kwh / consumed_kwh * 100)
              ELSE 100 END, 2)
        ELSE 0
    END as energy_independence_pct,
    -- Grid export ratio (% of production exported to grid)
    CASE WHEN produced_kwh > 0 THEN
        ROUND(CASE WHEN ((produced_kwh - consumed_kwh) / produced_kwh * 100) > 0
              THEN ((produced_kwh - consumed_kwh) / produced_kwh * 100)
              ELSE 0 END, 2)
        ELSE 0
    END as grid_export_pct,
    -- Self sufficiency (1 for self-sufficient day, 0 otherwise)
    CASE WHEN net_kwh <= 0 THEN 1 ELSE 0 END as self_sufficient_day
FROM daily_data;