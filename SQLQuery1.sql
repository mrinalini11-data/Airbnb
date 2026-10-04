--create database chicago;
-- Some Chicago areas charge considerably higher prices. 
--Management wants to know whether those higher prices are associated with stronger guest demand-WITH neighborhood_stats AS
WITH neighborhood_agg AS
(
    SELECT
        neighbourhood,
        COUNT(*) AS number_of_listings,

        AVG(CAST(price AS DECIMAL(18,2))) AS avg_price,

        AVG(CAST(reviews_per_month AS DECIMAL(18,2))) 
            AS avg_reviews_per_month,

        AVG(CAST(number_of_reviews_ltm AS DECIMAL(18,2))) 
            AS avg_reviews_ltm,

        AVG(CAST(availability_365 AS DECIMAL(18,2))) 
            AS avg_availability

    FROM Cleanlisting
    WHERE price IS NOT NULL
      AND neighbourhood IS NOT NULL

    GROUP BY neighbourhood
),

neighborhood_median AS
(
    SELECT DISTINCT
        neighbourhood,

        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY CAST(price AS DECIMAL(18,2)))
        OVER (PARTITION BY neighbourhood) AS median_price

    FROM Cleanlisting
    WHERE price IS NOT NULL
      AND neighbourhood IS NOT NULL
)

SELECT TOP 10
    a.neighbourhood,
    a.number_of_listings,

    ROUND(a.avg_price, 2) AS avg_price,

    ROUND(m.median_price, 2) AS median_price,

    ROUND(a.avg_reviews_per_month, 2) 
        AS avg_reviews_per_month,

    ROUND(a.avg_reviews_ltm, 2) 
        AS avg_reviews_ltm,

    ROUND(a.avg_availability, 2) 
        AS avg_availability

FROM neighborhood_agg a

JOIN neighborhood_median m
    ON a.neighbourhood = m.neighbourhood

ORDER BY a.avg_price DESC;


---
GO
CREATE OR ALTER VIEW dbo.vw_Listing AS
SELECT
    l.id, l.host_id, l.host_name, l.neighbourhood_group, l.neighbourhood, l.room_type,
    l.price, l.minimum_nights, l.availability_365, l.number_of_reviews,
    l.number_of_reviews_ltm, l.reviews_per_month, l.license_status,
    l.calculated_host_listings_count AS host_listings,
    TRY_CAST(l.last_review AS date) AS last_review_dt,
    r.ref_date,
    DATEDIFF(DAY, TRY_CAST(l.last_review AS date), r.ref_date) AS days_since_review,
    CASE WHEN TRY_CAST(l.last_review AS date) IS NULL
           OR TRY_CAST(l.last_review AS date) < DATEADD(DAY, -365, r.ref_date)
         THEN 1 ELSE 0 END AS is_inactive,
    CASE WHEN l.availability_365 = 0 THEN 1 ELSE 0 END AS is_unavailable,
    CASE WHEN l.room_type = 'Hotel room' THEN 'Hotel' ELSE 'Home stay' END AS stay_type,
    CASE WHEN (l.number_of_reviews_ltm / 0.5) * CASE WHEN l.minimum_nights > 3 THEN l.minimum_nights ELSE 3 END
              > (365 - l.availability_365)
         THEN (365 - l.availability_365)
         ELSE (l.number_of_reviews_ltm / 0.5) * CASE WHEN l.minimum_nights > 3 THEN l.minimum_nights ELSE 3 END
    END AS est_booked_nights
FROM dbo.CleanListing l
CROSS JOIN (SELECT MAX(TRY_CAST(last_review AS date)) AS ref_date FROM dbo.CleanListing) r;
GO

   -- Neighbourhoods with unusually high price but NOT stronger demand--

WITH city AS (
    SELECT AVG(price*1.0) AS city_price, AVG(number_of_reviews_ltm*1.0) AS city_demand
    FROM dbo.vw_Listing
),
n AS (
    SELECT neighbourhood, COUNT(*) AS listings,
           AVG(price*1.0) AS avg_price, AVG(number_of_reviews_ltm*1.0) AS avg_reviews_ltm
    FROM dbo.vw_Listing GROUP BY neighbourhood HAVING COUNT(*) >= 30
)
SELECT n.neighbourhood, n.listings,
       ROUND(n.avg_price,0) AS avg_price,
       ROUND(n.avg_price / c.city_price,2)          AS price_index,
       ROUND(n.avg_reviews_ltm,1)                   AS avg_reviews_ltm,
       ROUND(n.avg_reviews_ltm / c.city_demand,2)   AS demand_index,
       CASE WHEN n.avg_price/c.city_price > 1.2 AND n.avg_reviews_ltm/c.city_demand < 1
            THEN 'High price / weak demand' END      AS flag
FROM n CROSS JOIN city c
ORDER BY price_index DESC;

-- Is supply concentrated in a few areas?--

WITH s AS (
    SELECT neighbourhood, COUNT(*) AS listings FROM dbo.vw_Listing GROUP BY neighbourhood
)
SELECT neighbourhood, listings,
       ROUND(100.0*listings/SUM(listings) OVER(),2) AS pct_of_supply,
       ROUND(100.0*SUM(listings) OVER(ORDER BY listings DESC ROWS UNBOUNDED PRECEDING)
                  / SUM(listings) OVER(),2)         AS cumulative_pct,
       RANK() OVER (ORDER BY listings DESC)         AS supply_rank
FROM s ORDER BY listings DESC;

-- Concentration index (HHI; >0.15 = concentrated)
SELECT ROUND(SUM(POWER(1.0*listings/tot,2)),4) AS HHI
FROM (SELECT COUNT(*) listings, SUM(COUNT(*)) OVER() tot
      FROM dbo.vw_Listing GROUP BY neighbourhood) x;

  --  Stronger recent guest activity by neighbourhood

SELECT neighbourhood, COUNT(*) AS listings,
       SUM(number_of_reviews_ltm)                         AS reviews_ltm,
       ROUND(AVG(number_of_reviews_ltm*1.0),2)            AS avg_reviews_per_listing,
       ROUND(AVG(reviews_per_month),2)                    AS avg_reviews_per_month,
       SUM(CASE WHEN days_since_review <= 90 THEN 1 ELSE 0 END) AS reviewed_last_90d,
       ROUND(100.0*SUM(CASE WHEN days_since_review<=90 THEN 1 ELSE 0 END)/COUNT(*),1) AS pct_reviewed_90d
FROM dbo.vw_Listing
GROUP BY neighbourhood HAVING COUNT(*) >= 30
ORDER BY avg_reviews_per_listing DESC;

   --Are unavailable listings (availability_365 = 0) concentrated?--

-- by neighbourhood
SELECT neighbourhood, COUNT(*) AS listings, SUM(is_unavailable) AS unavailable,
       ROUND(100.0*SUM(is_unavailable)/COUNT(*),1) AS pct_unavailable
FROM dbo.vw_Listing GROUP BY neighbourhood HAVING COUNT(*)>=30
ORDER BY pct_unavailable DESC;

-- by host
SELECT TOP 20 host_id, MAX(host_name) AS host_name, COUNT(*) AS listings,
       SUM(is_unavailable) AS unavailable,
       ROUND(100.0*SUM(is_unavailable)/COUNT(*),1) AS pct_unavailable
FROM dbo.vw_Listing WHERE host_id IS NOT NULL
GROUP BY host_id HAVING SUM(is_unavailable) > 0
ORDER BY unavailable DESC;

/* =========================================================
   Are professional / multi-listing hosts dominating?
   ========================================================= */
SELECT CASE WHEN host_listings = 1 THEN '1 listing (individual)'
            WHEN host_listings BETWEEN 2 AND 4 THEN '2-4 listings'
            WHEN host_listings BETWEEN 5 AND 9 THEN '5-9 listings'
            WHEN host_listings >= 10 THEN '10+ (professional)'
            ELSE 'Unknown' END AS host_segment,
       COUNT(DISTINCT host_id) AS hosts,
       COUNT(*) AS listings,
       ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER(),1) AS pct_of_listings,
       ROUND(AVG(price*1.0),0) AS avg_price
FROM dbo.vw_Listing
GROUP BY CASE WHEN host_listings = 1 THEN '1 listing (individual)'
            WHEN host_listings BETWEEN 2 AND 4 THEN '2-4 listings'
            WHEN host_listings BETWEEN 5 AND 9 THEN '5-9 listings'
            WHEN host_listings >= 10 THEN '10+ (professional)'
            ELSE 'Unknown' END
ORDER BY listings DESC;

-- Top 10 hosts and share of market
SELECT TOP 10 host_id, MAX(host_name) AS host_name, COUNT(*) AS listings,
       ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM dbo.vw_Listing),2) AS pct_of_market
FROM dbo.vw_Listing WHERE host_id IS NOT NULL
GROUP BY host_id ORDER BY listings DESC;

/* =========================================================
   Do long-stay requirements reduce guest engagement?
   ========================================================= */
SELECT CASE WHEN minimum_nights <= 2  THEN '1-2 nights'
            WHEN minimum_nights <= 6  THEN '3-6 nights'
            WHEN minimum_nights <= 29 THEN '7-29 nights'
            ELSE '30+ nights (long stay)' END AS min_stay_band,
       COUNT(*) AS listings,
       ROUND(AVG(number_of_reviews_ltm*1.0),2) AS avg_reviews_ltm,
       ROUND(AVG(reviews_per_month),2)         AS avg_reviews_per_month,
       ROUND(100.0*SUM(is_inactive)/COUNT(*),1) AS pct_inactive
FROM dbo.vw_Listing
GROUP BY CASE WHEN minimum_nights <= 2  THEN '1-2 nights'
            WHEN minimum_nights <= 6  THEN '3-6 nights'
            WHEN minimum_nights <= 29 THEN '7-29 nights'
            ELSE '30+ nights (long stay)' END
ORDER BY MIN(minimum_nights);

/* =========================================================
    Does premium pricing correspond to stronger demand?
   ========================================================= */
SELECT price_quartile, COUNT(*) AS listings,
       MIN(price) AS min_price, MAX(price) AS max_price,
       ROUND(AVG(number_of_reviews_ltm*1.0),2) AS avg_reviews_ltm,
       ROUND(AVG(reviews_per_month),2)         AS avg_reviews_per_month,
       ROUND(AVG(365-availability_365*1.0),0)  AS avg_days_booked_proxy,
       ROUND(100.0*SUM(is_inactive)/COUNT(*),1) AS pct_inactive
FROM (SELECT *, NTILE(4) OVER (ORDER BY price) AS price_quartile FROM dbo.vw_Listing) q
GROUP BY price_quartile ORDER BY price_quartile;

-- Correlation price vs demand (Pearson)
SELECT ROUND(
   (COUNT(*)*SUM(price*1.0*number_of_reviews_ltm) - SUM(price*1.0)*SUM(number_of_reviews_ltm*1.0)) /
   NULLIF(SQRT(COUNT(*)*SUM(POWER(price*1.0,2)) - POWER(SUM(price*1.0),2)) *
          SQRT(COUNT(*)*SUM(POWER(number_of_reviews_ltm*1.0,2)) - POWER(SUM(number_of_reviews_ltm*1.0),2)),0),3)
   AS corr_price_vs_reviews_ltm
FROM dbo.vw_Listing;

/* =========================================================
 . Are licensing issues concentrated geographically?
   ========================================================= */
SELECT neighbourhood_group, neighbourhood, COUNT(*) AS listings,
       SUM(CASE WHEN license_status='no license'  THEN 1 ELSE 0 END) AS no_license,
       SUM(CASE WHEN license_status='not valid'   THEN 1 ELSE 0 END) AS not_valid,
       ROUND(100.0*SUM(CASE WHEN license_status<>'valid' THEN 1 ELSE 0 END)/COUNT(*),1) AS pct_issue
FROM dbo.vw_Listing
GROUP BY neighbourhood_group, neighbourhood HAVING COUNT(*)>=30
ORDER BY pct_issue DESC;

   -- Proportion of inactive / not recently reviewed listings
  
SELECT COUNT(*) AS total_listings,
       SUM(CASE WHEN last_review_dt IS NULL THEN 1 ELSE 0 END)      AS never_reviewed,
       SUM(CASE WHEN days_since_review > 365 THEN 1 ELSE 0 END)     AS no_review_12m,
       SUM(CASE WHEN days_since_review > 180 THEN 1 ELSE 0 END)     AS no_review_6m,
       ROUND(100.0*SUM(is_inactive)/COUNT(*),1)                     AS pct_inactive_12m
FROM dbo.vw_Listing;

-- By neighbourhood
SELECT neighbourhood, COUNT(*) AS listings,
       ROUND(100.0*SUM(is_inactive)/COUNT(*),1) AS pct_inactive
FROM dbo.vw_Listing GROUP BY neighbourhood HAVING COUNT(*)>=30
ORDER BY pct_inactive DESC;



-- Seasonality by calendar month across all years (index vs average = 100)
WITH c AS (
    SELECT MONTH(last_review_dt) AS mth, COUNT(*) AS n
    FROM dbo.vw_Listing WHERE last_review_dt IS NOT NULL GROUP BY MONTH(last_review_dt)
)
SELECT mth, n, ROUND(100.0*n/AVG(n*1.0) OVER(),1) AS seasonality_index FROM c ORDER BY mth;


--. ADR (Average Daily Rate) – by neighbourhood and stay type

SELECT neighbourhood, COUNT(*) AS listings,
       ROUND(AVG(price*1.0),2) AS simple_adr,
       ROUND(SUM(price*est_booked_nights)*1.0/NULLIF(SUM(est_booked_nights),0),2) AS booked_night_weighted_adr
FROM dbo.vw_Listing GROUP BY neighbourhood HAVING COUNT(*)>=30
ORDER BY booked_night_weighted_adr DESC;

SELECT stay_type, room_type, COUNT(*) AS listings,
       ROUND(AVG(price*1.0),2) AS adr,
       ROUND(SUM(price*est_booked_nights)*1.0/NULLIF(SUM(est_booked_nights),0),2) AS weighted_adr
FROM dbo.vw_Listing GROUP BY stay_type, room_type;

-- CLV (host lifetime value proxy; no guest IDs exist)
  -- Lifetime revenue = price x est. booked nights; annualised from LTM

SELECT TOP 25 host_id, MAX(host_name) AS host_name, COUNT(*) AS listings,
       ROUND(SUM(price*est_booked_nights),0) AS est_annual_revenue,
       ROUND(SUM(price*1.0*number_of_reviews/0.5 * CASE WHEN minimum_nights>3 THEN minimum_nights ELSE 3 END),0)
             AS est_lifetime_revenue_CLV,
       ROUND(AVG(price*1.0),0) AS avg_price
FROM dbo.vw_Listing WHERE host_id IS NOT NULL
GROUP BY host_id ORDER BY est_lifetime_revenue_CLV DESC;

-- Guest-side CLV proxy: value of an average guest booking, by neighbourhood
SELECT neighbourhood,
       ROUND(AVG(price * CASE WHEN minimum_nights>3 THEN minimum_nights ELSE 3 END *1.0),0) AS avg_booking_value,
       ROUND(AVG(number_of_reviews*1.0),1) AS avg_lifetime_reviews
FROM dbo.vw_Listing GROUP BY neighbourhood HAVING COUNT(*)>=30
ORDER BY avg_booking_value DESC;


  -- REVIEWS & RATING (no star-rating column ->> review volume/velocity)--
 
SELECT neighbourhood, COUNT(*) AS listings,
       SUM(number_of_reviews)               AS total_reviews,
       ROUND(AVG(number_of_reviews*1.0),1)  AS avg_reviews,
       ROUND(AVG(reviews_per_month),2)      AS avg_review_velocity,
       ROUND(100.0*SUM(CASE WHEN number_of_reviews>=50 THEN 1 ELSE 0 END)/COUNT(*),1) AS pct_well_reviewed
FROM dbo.vw_Listing GROUP BY neighbourhood HAVING COUNT(*)>=30
ORDER BY avg_review_velocity DESC;

  -- . HOME STAY vs HOTEL demand

SELECT stay_type, COUNT(*) AS listings,
       ROUND(AVG(price*1.0),0)                   AS avg_price,
       ROUND(AVG(number_of_reviews_ltm*1.0),2)   AS avg_reviews_ltm,
       ROUND(AVG(reviews_per_month),2)           AS avg_reviews_per_month,
       ROUND(AVG((365-availability_365)*1.0/365)*100,1) AS est_occupancy_pct,
       ROUND(100.0*SUM(is_inactive)/COUNT(*),1)  AS pct_inactive
FROM dbo.vw_Listing GROUP BY stay_type;

-- Demand by room type
SELECT room_type, COUNT(*) AS listings,
       ROUND(AVG(number_of_reviews_ltm*1.0),2) AS avg_reviews_ltm,
       ROUND(AVG(price*1.0),0) AS avg_price
FROM dbo.vw_Listing GROUP BY room_type ORDER BY avg_reviews_ltm DESC;

;--demand-versus-price classification.
WITH city AS (
    SELECT AVG(price*1.0) AS city_price,
           AVG(number_of_reviews_ltm*1.0) AS city_demand,
           COUNT(*) AS total
    FROM dbo.vw_Listing
),
n AS (
    SELECT neighbourhood,
           COUNT(*) AS listings,
           AVG(price*1.0) AS adr,
           AVG(number_of_reviews_ltm*1.0) AS avg_reviews_ltm,
           AVG(reviews_per_month) AS review_velocity,
           100.0*SUM(CASE WHEN days_since_review <= 90 THEN 1 ELSE 0 END)/COUNT(*) AS pct_active_90d,
           100.0*SUM(est_booked_nights)/(COUNT(*)*365.0) AS occupancy_pct,
           SUM(price*est_booked_nights)/(COUNT(*)*365.0) AS revpar,
           100.0*SUM(is_inactive)/COUNT(*) AS pct_inactive,
           100.0*SUM(is_unavailable)/COUNT(*) AS pct_unavailable,
           100.0*SUM(CASE WHEN host_listings >= 5 THEN 1 ELSE 0 END)/COUNT(*) AS pct_pro_host,
           100.0*SUM(CASE WHEN license_status <> 'valid' THEN 1 ELSE 0 END)/COUNT(*) AS pct_license_issue
    FROM dbo.vw_Listing
    GROUP BY neighbourhood
    HAVING COUNT(*) >= 30
)
SELECT n.neighbourhood, n.listings,
       ROUND(100.0*n.listings/c.total,2)          AS supply_share_pct,
       ROUND(n.adr,0)                             AS adr,
       ROUND(n.adr/c.city_price,2)                AS price_index,
       ROUND(n.avg_reviews_ltm/c.city_demand,2)   AS demand_index,
       ROUND(n.review_velocity,2)                 AS review_velocity,
       ROUND(n.pct_active_90d,1)                  AS pct_active_90d,
       ROUND(n.occupancy_pct,1)                   AS occupancy_pct,
       ROUND(n.revpar,1)                          AS revpar,
       ROUND(n.pct_inactive,1)                    AS pct_inactive,
       ROUND(n.pct_unavailable,1)                 AS pct_unavailable,
       ROUND(n.pct_pro_host,1)                    AS pct_pro_host,
       ROUND(n.pct_license_issue,1)               AS pct_license_issue,
       CASE WHEN n.adr/c.city_price >= 1 AND n.avg_reviews_ltm/c.city_demand >= 1 THEN 'Premium & strong demand'
            WHEN n.adr/c.city_price >= 1 AND n.avg_reviews_ltm/c.city_demand <  1 THEN 'Overpriced / weak demand'
            WHEN n.adr/c.city_price <  1 AND n.avg_reviews_ltm/c.city_demand >= 1 THEN 'Value hotspot (room to raise price)'
            ELSE 'Low price & low demand' END       AS market_segment
FROM n CROSS JOIN city c
ORDER BY revpar DESC;

---neighorhood

WITH neighborhood_analysis AS
(
    SELECT
        neighbourhood,
        -- Number of listings
        COUNT(*) AS total_listings,
 -- Average price
        AVG(CAST(price AS DECIMAL(18,2))) AS avg_price,
 -- Booking / demand proxy
        SUM(CAST(number_of_reviews_ltm AS DECIMAL(18,2)))
            AS estimated_bookings,
 -- Review activity
        AVG(CAST(reviews_per_month AS DECIMAL(18,2)))
            AS avg_reviews_per_month,
 -- Estimated revenue proxy
        SUM(
            CAST(price AS DECIMAL(18,2))
            * CAST(number_of_reviews_ltm AS DECIMAL(18,2))
        ) AS estimated_revenue
    FROM Cleanlisting
    WHERE neighbourhood IS NOT NULL
      AND price IS NOT NULL
      AND number_of_reviews_ltm IS NOT NULL
GROUP BY neighbourhood
)SELECT
    neighbourhood,
    total_listings,
    ROUND(avg_price, 2) AS avg_price,
estimated_bookings,
    ROUND(avg_reviews_per_month, 2)
        AS avg_reviews_per_month,
ROUND(estimated_revenue, 2)
        AS estimated_revenue
FROM neighborhood_analysis
ORDER BY estimated_revenue DESC;