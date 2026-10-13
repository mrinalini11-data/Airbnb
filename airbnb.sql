--create database airbnb_chicago;
go

--create a viwe

CREATE OR ALTER VIEW dbo.v_base AS
SELECT
    TRY_CAST(id AS BIGINT)                                         AS id,
    name,
    TRY_CAST(TRY_CAST(host_id AS FLOAT) AS DECIMAL(20,0))          AS host_id,
    host_name,
    neighbourhood_group,
    neighbourhood,
    TRY_CAST(latitude  AS DECIMAL(9,5))                            AS latitude,
    TRY_CAST(longitude AS DECIMAL(9,5))                            AS longitude,
    room_type,
    TRY_CAST(price AS DECIMAL(10,2))                               AS price,
    TRY_CAST(minimum_nights AS INT)                                AS minimum_nights,
    TRY_CAST(number_of_reviews AS INT)                             AS number_of_reviews,
    TRY_CAST(NULLIF(CAST(last_review AS VARCHAR(30)), '') AS DATE) AS last_review,
    TRY_CAST(reviews_per_month AS DECIMAL(6,2))                    AS reviews_per_month,
    TRY_CAST(TRY_CAST(calculated_host_listings_count AS FLOAT) AS INT) AS calculated_host_listings_count,
    TRY_CAST(availability_365 AS INT)                              AS availability_365,
    TRY_CAST(number_of_reviews_ltm AS INT)                         AS number_of_reviews_ltm,
    ISNULL(license, 'Not Available')                               AS license,
    ISNULL(license_status, 'no license')                           AS license_status
FROM dbo.listings;
GO


-- 2.1 Row count and null audit
SELECT COUNT(*)                                              AS total_rows,
       SUM(CASE WHEN host_id     IS NULL THEN 1 ELSE 0 END)  AS null_host,
       SUM(CASE WHEN last_review IS NULL THEN 1 ELSE 0 END)  AS never_reviewed,
       SUM(CASE WHEN price       IS NULL THEN 1 ELSE 0 END)  AS null_price
FROM dbo.v_base;

-- 2.2 Duplicate ids (should return 0 rows)
SELECT id, COUNT(*) AS cnt
FROM dbo.v_base
GROUP BY id
HAVING COUNT(*) > 1;

-- 2.3 Price outliers (IQR method)
WITH q AS (
    SELECT DISTINCT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY price) OVER () AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY price) OVER () AS q3
    FROM dbo.v_base
)
SELECT b.id, b.name, b.price
FROM dbo.v_base b
CROSS JOIN q
WHERE b.price > q.q3 + 1.5 * (q.q3 - q.q1)
ORDER BY b.price DESC;
--Metrics view
CREATE OR ALTER VIEW dbo.v_listing_metrics AS
SELECT
    b.*,
    (365 - b.availability_365)                                          AS booked_days_est,
    CAST(ROUND((365 - b.availability_365) / 365.0 * 100, 1) AS DECIMAL(5,1)) AS occupancy_pct,
    CAST(ROUND(b.price * (365 - b.availability_365), 0) AS DECIMAL(12,0))    AS est_annual_revenue,
    ISNULL(DATEDIFF(DAY, b.last_review, CAST(GETDATE() AS DATE)), 9999) AS days_since_last_review
FROM dbo.v_base b;
GO
--: Demand analysis
-- 4.1 Demand by neighbourhood group
SELECT
    neighbourhood_group,
    COUNT(*)                                       AS listings,
    ROUND(AVG(price), 2)                           AS avg_price,
    ROUND(AVG(occupancy_pct), 1)                   AS avg_occupancy_pct,
    ROUND(AVG(reviews_per_month), 2)               AS avg_reviews_pm,
    SUM(number_of_reviews_ltm)                     AS total_reviews_ltm,
    ROUND(SUM(est_annual_revenue) / 1000000.0, 2)  AS est_revenue_millions
FROM dbo.v_listing_metrics
GROUP BY neighbourhood_group
ORDER BY total_reviews_ltm DESC;

-- 4.2 Demand by room type
SELECT
    room_type,
    COUNT(*)                         AS listings,
    ROUND(AVG(price), 2)             AS avg_price,
    ROUND(AVG(occupancy_pct), 1)     AS avg_occupancy_pct,
    ROUND(AVG(reviews_per_month), 2) AS avg_reviews_pm
FROM dbo.v_listing_metrics
GROUP BY room_type
ORDER BY avg_occupancy_pct DESC;

-- 4.3 Top 15 neighbourhoods by demand (min. 30 listings)
SELECT TOP 15
    neighbourhood,
    neighbourhood_group,
    COUNT(*)                     AS listings,
    ROUND(AVG(occupancy_pct), 1) AS avg_occupancy_pct,
    SUM(number_of_reviews_ltm)   AS reviews_ltm,
    ROUND(AVG(price), 0)         AS avg_price
FROM dbo.v_listing_metrics
GROUP BY neighbourhood, neighbourhood_group
HAVING COUNT(*) >= 30
ORDER BY reviews_ltm DESC;

-- 4.4 Minimum-nights effect on demand
SELECT
    stay_bucket,
    COUNT(*)                         AS listings,
    ROUND(AVG(occupancy_pct), 1)     AS avg_occupancy_pct,
    ROUND(AVG(reviews_per_month), 2) AS avg_reviews_pm,
    ROUND(AVG(price), 0)             AS avg_price
FROM (
    SELECT *,
           CASE WHEN minimum_nights < 7  THEN '1. Short (<7)'
                WHEN minimum_nights < 30 THEN '2. Medium (7-29)'
                ELSE                          '3. Long (30+)' END AS stay_bucket
    FROM dbo.v_listing_metrics
) x
GROUP BY stay_bucket
ORDER BY stay_bucket;

-- 4.5 Price band vs demand
SELECT
    price_band,
    COUNT(*)                         AS listings,
    ROUND(AVG(occupancy_pct), 1)     AS avg_occupancy_pct,
    ROUND(AVG(reviews_per_month), 2) AS avg_reviews_pm
FROM (
    SELECT *,
           CASE WHEN price < 100 THEN '1. <100'
                WHEN price < 200 THEN '2. 100-199'
                WHEN price < 300 THEN '3. 200-299'
                WHEN price < 500 THEN '4. 300-499'
                ELSE                  '5. 500+' END AS price_band
    FROM dbo.v_listing_metrics
) x
GROUP BY price_band
ORDER BY price_band;
--Opportunity matrix
CREATE OR ALTER VIEW dbo.v_opportunity_matrix AS
WITH segment AS (
    SELECT
        neighbourhood_group,
        neighbourhood,
        room_type,
        COUNT(*)                   AS supply_listings,
        SUM(number_of_reviews_ltm) AS demand_reviews_ltm,
        AVG(occupancy_pct)         AS avg_occupancy,
        AVG(price)                 AS avg_price,
        AVG(est_annual_revenue)    AS avg_revenue_per_listing
    FROM dbo.v_listing_metrics
    GROUP BY neighbourhood_group, neighbourhood, room_type
    HAVING COUNT(*) >= 10
),
shares AS (
    SELECT
        s.*,
        demand_reviews_ltm * 1.0 / SUM(demand_reviews_ltm) OVER () AS demand_share,
        supply_listings    * 1.0 / SUM(supply_listings)    OVER () AS supply_share
    FROM segment s
),
scored AS (
    SELECT
        *,
        CAST(demand_share / NULLIF(supply_share, 0) AS DECIMAL(8,2)) AS opportunity_index,
        PERCENT_RANK() OVER (ORDER BY avg_occupancy)   AS demand_pctile,
        PERCENT_RANK() OVER (ORDER BY supply_listings) AS supply_pctile
    FROM shares
)
SELECT
    neighbourhood_group, neighbourhood, room_type,
    supply_listings,
    demand_reviews_ltm,
    CAST(avg_occupancy AS DECIMAL(5,1))            AS avg_occupancy_pct,
    CAST(avg_price AS DECIMAL(10,0))               AS avg_price,
    CAST(avg_revenue_per_listing AS DECIMAL(12,0)) AS avg_revenue_per_listing,
    opportunity_index,
    CASE
        WHEN demand_pctile >= 0.5 AND supply_pctile <  0.5 THEN 'A. HIGH DEMAND / LOW SUPPLY - Expand'
        WHEN demand_pctile >= 0.5 AND supply_pctile >= 0.5 THEN 'B. HIGH DEMAND / HIGH SUPPLY - Defend and optimise'
        WHEN demand_pctile <  0.5 AND supply_pctile <  0.5 THEN 'C. LOW DEMAND / LOW SUPPLY - Test or monitor'
        ELSE                                                    'D. LOW DEMAND / HIGH SUPPLY - Saturated'
    END AS opportunity_quadrant
FROM scored;
GO

-- 5.1 Top expansion targets
SELECT TOP 20 *
FROM dbo.v_opportunity_matrix
WHERE opportunity_quadrant LIKE 'A.%'
ORDER BY opportunity_index DESC, avg_revenue_per_listing DESC;

-- 5.2 Matrix summary
SELECT opportunity_quadrant,
       COUNT(*)                 AS segments,
       SUM(supply_listings)     AS listings,
       ROUND(AVG(avg_price), 0) AS avg_price
FROM dbo.v_opportunity_matrix
GROUP BY opportunity_quadrant
ORDER BY opportunity_quadrant;

-- 5.3 Pivot: neighbourhood group x room type (opportunity index)
SELECT
    neighbourhood_group,
    ROUND(AVG(CASE WHEN room_type = 'Entire home/apt' THEN opportunity_index END), 2) AS entire_home,
    ROUND(AVG(CASE WHEN room_type = 'Private room'    THEN opportunity_index END), 2) AS private_room,
    ROUND(AVG(CASE WHEN room_type = 'Hotel room'      THEN opportunity_index END), 2) AS hotel_room,
    ROUND(AVG(CASE WHEN room_type = 'Shared room'     THEN opportunity_index END), 2) AS shared_room
FROM dbo.v_opportunity_matrix
GROUP BY neighbourhood_group
--: Performance category (perfcat)
CREATE OR ALTER VIEW dbo.v_listing_performance AS
WITH ranked AS (
    SELECT
        v.*,
        PERCENT_RANK() OVER (PARTITION BY room_type ORDER BY reviews_per_month)  AS pr_reviews,
        PERCENT_RANK() OVER (PARTITION BY room_type ORDER BY occupancy_pct)      AS pr_occupancy,
        PERCENT_RANK() OVER (PARTITION BY room_type ORDER BY est_annual_revenue) AS pr_revenue
    FROM dbo.v_listing_metrics v
),
scored AS (
    SELECT
        *,
        CAST(pr_reviews * 40 + pr_occupancy * 35 + pr_revenue * 25 AS DECIMAL(5,1)) AS perf_score
    FROM ranked
)
SELECT
    id, name, host_id, host_name, neighbourhood_group, neighbourhood, room_type,
    price, occupancy_pct, reviews_per_month, est_annual_revenue,
    number_of_reviews, days_since_last_review, perf_score,
    NTILE(10) OVER (ORDER BY perf_score DESC) AS perf_decile,
    CASE
        WHEN perf_score >= 75                                       THEN 'STAR'
        WHEN perf_score >= 50                                       THEN 'SOLID'
        WHEN perf_score >= 30 AND days_since_last_review <= 365     THEN 'AT RISK'
        WHEN days_since_last_review > 365 OR number_of_reviews = 0  THEN 'DORMANT'
        ELSE                                                             'UNDERPERFORMER'
    END AS perf_category
FROM scored;
GO

-- 6.1 Category distribution
SELECT perf_category,
       COUNT(*)                                            AS listings,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)  AS pct,
       ROUND(AVG(price), 0)                                AS avg_price,
       ROUND(AVG(est_annual_revenue), 0)                   AS avg_revenue
FROM dbo.v_listing_performance
GROUP BY perf_category
ORDER BY listings DESC;

-- 6.2 Performance category by neighbourhood group
SELECT neighbourhood_group,
       SUM(CASE WHEN perf_category = 'STAR'           THEN 1 ELSE 0 END) AS stars,
       SUM(CASE WHEN perf_category = 'SOLID'          THEN 1 ELSE 0 END) AS solid,
       SUM(CASE WHEN perf_category = 'AT RISK'        THEN 1 ELSE 0 END) AS at_risk,
       SUM(CASE WHEN perf_category = 'UNDERPERFORMER' THEN 1 ELSE 0 END) AS underperformers,
       SUM(CASE WHEN perf_category = 'DORMANT'        THEN 1 ELSE 0 END) AS dormant
FROM dbo.v_listing_performance
GROUP BY neighbourhood_group
ORDER BY stars DESC;

-- 6.3 Overpriced and weak listings (30% above neighbourhood + room type median)
WITH med AS (
    SELECT DISTINCT neighbourhood, room_type,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price)
               OVER (PARTITION BY neighbourhood, room_type) AS median_price
    FROM dbo.v_base
)
SELECT p.id, p.name, p.neighbourhood, p.room_type, p.price,
       m.median_price,
       ROUND((p.price / NULLIF(m.median_price, 0) - 1) * 100, 1) AS pct_above_median,
       p.perf_category
FROM dbo.v_listing_performance p
JOIN med m
  ON m.neighbourhood = p.neighbourhood AND m.room_type = p.room_type
WHERE p.price > m.median_price * 1.3
  AND p.perf_category IN ('AT RISK', 'UNDERPERFORMER', 'DORMANT')
ORDER BY pct_above_median DESC;


--Compliance (infringer detection)
CREATE OR ALTER VIEW dbo.v_compliance_risk AS
WITH license_use AS (
    SELECT license, COUNT(*) AS listings_on_license
    FROM dbo.v_base
    WHERE license <> 'Not Available'
    GROUP BY license
),
host_stats AS (
    SELECT host_id,
           COUNT(*) AS host_listings,
           SUM(CASE WHEN license_status <> 'valid' THEN 1 ELSE 0 END) AS host_noncompliant
    FROM dbo.v_base
    WHERE host_id IS NOT NULL
    GROUP BY host_id
)
SELECT
    l.id, l.name, l.host_id, l.host_name,
    l.neighbourhood_group, l.neighbourhood, l.room_type,
    l.price, l.minimum_nights, l.license, l.license_status,
    ISNULL(lu.listings_on_license, 0) AS listings_on_license,
    ISNULL(hs.host_listings, 1)       AS host_listings,
    ISNULL(hs.host_noncompliant, 0)   AS host_noncompliant,
    (   CASE WHEN l.license_status = 'no license' THEN 40
             WHEN l.license_status = 'not valid'  THEN 50 ELSE 0 END
      + CASE WHEN ISNULL(lu.listings_on_license, 0) >= 3 THEN 25 ELSE 0 END
      + CASE WHEN ISNULL(hs.host_listings, 1) >= 5 THEN 15 ELSE 0 END
      + CASE WHEN ISNULL(hs.host_listings, 1) >= 5
              AND ISNULL(hs.host_noncompliant, 0) > 0 THEN 15 ELSE 0 END
      + CASE WHEN l.minimum_nights < 30
              AND l.license_status <> 'valid' THEN 20 ELSE 0 END
    ) AS risk_score
FROM dbo.v_base l
LEFT JOIN license_use lu ON lu.license = l.license
LEFT JOIN host_stats  hs ON hs.host_id = l.host_id;
GO

-- 7.1 License status overview
SELECT license_status,
       COUNT(*)                                           AS listings,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct,
       ROUND(AVG(price), 0)                               AS avg_price
FROM dbo.v_base
GROUP BY license_status;

-- 7.2 Licenses reused across many listings
SELECT license,
       COUNT(*)                AS listings_on_license,
       COUNT(DISTINCT host_id) AS distinct_hosts
FROM dbo.v_base
WHERE license <> 'Not Available'
GROUP BY license
HAVING COUNT(*) >= 3
ORDER BY listings_on_license DESC;

-- 7.3 Top infringing hosts
SELECT TOP 25
    host_id, host_name,
    COUNT(*) AS total_listings,
    SUM(CASE WHEN license_status <> 'valid' THEN 1 ELSE 0 END) AS non_compliant,
    ROUND(100.0 * SUM(CASE WHEN license_status <> 'valid' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_non_compliant,
    ROUND(SUM(CASE WHEN license_status <> 'valid' THEN est_annual_revenue ELSE 0 END) / 1000.0, 1) AS revenue_at_risk_k
FROM dbo.v_listing_metrics
WHERE host_id IS NOT NULL
GROUP BY host_id, host_name
HAVING SUM(CASE WHEN license_status <> 'valid' THEN 1 ELSE 0 END) > 0
ORDER BY non_compliant DESC, revenue_at_risk_k DESC;

-- 7.4 Risk tiers
SELECT risk_tier, COUNT(*) AS listings
FROM (
    SELECT CASE WHEN risk_score >= 80 THEN 'CRITICAL'
                WHEN risk_score >= 55 THEN 'HIGH'
                WHEN risk_score >= 30 THEN 'MEDIUM'
                ELSE 'LOW' END AS risk_tier,
           risk_score
    FROM dbo.v_compliance_risk
) t
GROUP BY risk_tier
ORDER BY MIN(risk_score) DESC;
--Decision engine (HIRE / KEEP / FIX / REMOVE)
CREATE OR ALTER VIEW dbo.v_listing_decision AS
SELECT
    p.id, p.name, p.host_id, p.host_name,
    p.neighbourhood_group, p.neighbourhood, p.room_type,
    p.price, p.occupancy_pct, p.est_annual_revenue,
    p.perf_score, p.perf_category,
    c.license_status, c.risk_score,
    o.opportunity_quadrant,
    CASE
        WHEN c.risk_score >= 80
            THEN 'REMOVE - Critical compliance breach'
        WHEN c.license_status <> 'valid' AND p.perf_category IN ('DORMANT','UNDERPERFORMER')
            THEN 'REMOVE - Non-compliant and low performing'
        WHEN p.perf_category = 'DORMANT' AND o.opportunity_quadrant LIKE 'D.%'
            THEN 'REMOVE - Dormant in saturated segment'
        WHEN c.license_status <> 'valid' AND p.perf_category IN ('STAR','SOLID')
            THEN 'FIX - Good listing, obtain valid license'
        WHEN p.perf_category IN ('STAR','SOLID') AND o.opportunity_quadrant LIKE 'A.%'
            THEN 'HIRE MORE - Replicate in this segment'
        WHEN p.perf_category = 'STAR'
            THEN 'KEEP - Top performer'
        WHEN p.perf_category IN ('AT RISK','UNDERPERFORMER')
            THEN 'IMPROVE - Reprice or optimise'
        ELSE 'KEEP - Monitor'
    END AS decision
FROM dbo.v_listing_performance p
JOIN dbo.v_compliance_risk c
  ON c.id = p.id
LEFT JOIN dbo.v_opportunity_matrix o
  ON o.neighbourhood_group = p.neighbourhood_group
 AND o.neighbourhood       = p.neighbourhood
 AND o.room_type           = p.room_type;
GO

-- 8.1 Decision summary
SELECT decision,
       COUNT(*)                                  AS listings,
       ROUND(AVG(price), 0)                      AS avg_price,
       ROUND(SUM(est_annual_revenue)/1000000.0, 2) AS revenue_millions
FROM dbo.v_listing_decision
GROUP BY decision
ORDER BY listings DESC;

-- 8.2 REMOVE list (enforcement list)
SELECT id, name, host_id, host_name, neighbourhood, license_status, risk_score, decision
FROM dbo.v_listing_decision
WHERE decision LIKE 'REMOVE%'
ORDER BY risk_score DESC, est_annual_revenue DESC;

-- 8.3 HIRE / expansion segments
SELECT TOP 20
    neighbourhood_group, neighbourhood, room_type,
    COUNT(*)                     AS strong_listings,
    ROUND(AVG(price), 0)         AS benchmark_price,
    ROUND(AVG(occupancy_pct), 1) AS benchmark_occupancy
FROM dbo.v_listing_decision
WHERE decision LIKE 'HIRE MORE%'
GROUP BY neighbourhood_group, neighbourhood, room_type
ORDER BY strong_listings DESC, benchmark_occupancy DESC;

-- 8.4 Hosts worth recruiting (compliant, multi-listing, strong)
SELECT TOP 25
    host_id, host_name,
    COUNT(*)                                 AS listings,
    ROUND(AVG(perf_score), 1)                AS avg_perf_score,
    ROUND(SUM(est_annual_revenue)/1000.0, 1) AS revenue_k
FROM dbo.v_listing_decision
WHERE license_status = 'valid'
  AND perf_category IN ('STAR','SOLID')
  AND host_id IS NOT NULL
GROUP BY host_id, host_name
HAVING COUNT(*) >= 2
ORDER BY avg_perf_score DESC, revenue_k DESC;

-- 8.5 Executive KPI summary
SELECT
    COUNT(*)                                                                     AS total_listings,
    ROUND(AVG(price), 0)                                                         AS avg_price,
    ROUND(100.0 * SUM(CASE WHEN license_status = 'valid' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_compliant,
    SUM(CASE WHEN decision LIKE 'REMOVE%'
         THEN 1 ELSE 0 END)                                                      AS to_remove,
    SUM(CASE WHEN decision LIKE 'FIX%'       THEN 1 ELSE 0 END)                  AS to_fix,
    SUM(CASE WHEN decision LIKE 'HIRE MORE%' THEN 1 ELSE 0 END)                  AS to_replicate,
    ROUND(SUM(CASE WHEN decision LIKE 'REMOVE%' THEN est_annual_revenue ELSE 0 END)/1000000.0, 2) AS revenue_removed_millions
FROM dbo.v_listing_decision;
---