# 🏠 Airbnb Chicago: Listing Performance, Compliance & Decision Engine

An end-to-end data analysis project on **8,704 Airbnb listings in Chicago**. It uses **SQL Server (T-SQL)** to clean the data, measure demand, score listing performance, flag licensing risk, and recommend an action for every listing: **HIRE MORE / KEEP / FIX / IMPROVE / REMOVE**.

---

## 📌 Project Objectives

1. Clean and validate the raw listings data.
2. Measure demand by neighbourhood, room type, price band and minimum-night policy.
3. Find under-supplied, high-demand segments to expand into.
4. Score and classify every listing by performance.
5. Detect licensing non-compliance and risky hosts.
6. Combine all of the above into one actionable decision per listing.

---

## 📁 Repository Structure

```
Airbnb/
├── Clean_Listing_.csv   # Cleaned Chicago listings dataset (8,704 rows, 21 columns)
├── airbnb.sql           # All SQL: views, audits and analysis queries
├── EDA.ipynb            # Python exploratory data analysis notebook
├── Airbnb_Dashboard.pbix   # Interactive dashboard (rename to match your file)
├── dashboard_preview.png   # Dashboard screenshot (optional)
└── README.md
```

---

## 🗂️ Dataset: `Clean_Listing_.csv`

| Item | Detail |
|---|---|
| Rows / Columns | 8,704 / 21 |
| City | Chicago, IL |
| Neighbourhoods | 77 neighbourhoods in 9 groups |
| Last review dates | Jan 2015 to Jul 2026 |
| Price range | $20 to $1,087 (median ≈ $237) |

**Key columns**

| Column | Description |
|---|---|
| `id`, `name` | Listing ID and title |
| `host_id`, `host_name`, `calculated_host_listings_count` | Host details and how many listings they manage |
| `neighbourhood_group`, `neighbourhood`, `latitude`, `longitude` | Location |
| `room_type` | Entire home/apt, Private room, Hotel room, Shared room |
| `price`, `price_imputed` | Nightly price; `price_imputed = 1` marks filled-in values (1,059 rows) |
| `minimum_nights`, `availability_365` | Stay rules and days available per year |
| `number_of_reviews`, `number_of_reviews_ltm`, `reviews_per_month`, `last_review` | Review activity (a proxy for demand) |
| `license`, `license_status` | License number and status: `valid`, `not valid`, `no license` |

**Snapshot**

- **Room types:** 6,663 Entire home/apt · 1,939 Private room · 70 Hotel room · 32 Shared room
- **License status:** 5,737 valid · 2,938 no license · 29 not valid
- **Largest groups by listings:** West Side (2,049), Central (1,900), North Side (1,555)

---

## 🛠️ SQL Workflow (`airbnb.sql`)

The script is written for **Microsoft SQL Server**. It expects the CSV to be loaded into a table named `dbo.listings`.

| Step | Object | What it does |
|---|---|---|
| 1 | `v_base` | Safely casts types (`TRY_CAST`), fills missing licenses with *Not Available* / *no license* |
| 2 | Data quality audit | Row count, null audit, duplicate IDs, IQR price outliers |
| 3 | `v_listing_metrics` | Adds estimated booked days, **occupancy %**, **estimated annual revenue** and days since last review |
| 4 | Demand analysis | Demand by neighbourhood group, room type, top 15 neighbourhoods, minimum-night buckets and price bands |
| 5 | `v_opportunity_matrix` | Compares supply and demand per neighbourhood and room type to find expansion targets |
| 6 | `v_listing_performance` | Weighted **performance score**, classifying listings as `STAR`, `SOLID`, `AT RISK`, `UNDERPERFORMER` or `DORMANT` |
| 7 | `v_compliance_risk` | **Risk score** based on license status, reused licenses, multi-listing hosts and short stays |
| 8 | `v_listing_decision` | Final action for every listing, plus an executive KPI summary |

### Performance score

Each listing is ranked within its room type, then weighted:

```
perf_score = 40% × reviews per month + 35% × occupancy + 25% × estimated revenue
```

| Category | Rule |
|---|---|
| ⭐ STAR | score ≥ 75 |
| ✅ SOLID | score ≥ 50 |
| ⚠️ AT RISK | score ≥ 30 and reviewed within the last year |
| 💤 DORMANT | no review in over a year, or no reviews at all |
| 📉 UNDERPERFORMER | everything else |

### Compliance risk score

Points are added for: no license (+40) or invalid license (+50), a license shared by 3+ listings (+25), hosts with 5+ listings (+15), such hosts having non-compliant listings (+15), and short stays (<30 nights) without a valid license (+20).

### Decision engine

| Decision | Triggered when |
|---|---|
| 🔴 **REMOVE** | Risk score ≥ 80, non-compliant and low performing, or dormant in a saturated segment |
| 🟠 **FIX** | Good listing (STAR/SOLID) that still lacks a valid license |
| 🟢 **HIRE MORE** | Strong listing in a high-opportunity segment, so replicate it there |
| 🟢 **KEEP** | Top performer, or stable listing to monitor |
| 🟡 **IMPROVE** | At-risk or underperforming listing that needs repricing or optimisation |

---

## 📊 Airbnb Dashboard

An interactive dashboard built on the SQL views (`v_listing_metrics`, `v_listing_performance`, `v_compliance_risk`, `v_listing_decision`).

![Airbnb Dashboard](dashboard_preview.png)

**What it shows**

- KPI cards: total listings, average price, average occupancy, estimated revenue
- Demand by neighbourhood group and room type
- Map of listings by location and price
- Performance categories (STAR / SOLID / AT RISK / DORMANT / UNDERPERFORMER)
- License compliance and risk tiers
- Decision summary (HIRE MORE / KEEP / FIX / IMPROVE / REMOVE)

**How to use it:** open `Airbnb_Dashboard.pbix` in Power BI Desktop, point the data source to your SQL Server database (or to `Clean_Listing_.csv`), then refresh. Use the slicers to filter by neighbourhood, room type and price band.

---

## 🚀 How to Run

1. **Create a database** in SQL Server (e.g. `airbnb_chicago`).
2. **Import `Clean_Listing_.csv`** into a table called `dbo.listings` (SQL Server Management Studio: *Tasks → Import Flat File*).
3. **Run `airbnb.sql`** top to bottom. The views are created in order and each analysis query can then be run on its own.
4. **Open `EDA.ipynb`** in Jupyter for the Python exploration:

```bash
pip install pandas numpy matplotlib seaborn jupyter
jupyter notebook EDA.ipynb
```

---

## 🧰 Tools & Skills

- **SQL Server / T-SQL:** views, CTEs, window functions (`PERCENT_RANK`, `NTILE`, `PERCENTILE_CONT`), conditional scoring
- **Python:** pandas, Jupyter Notebook (EDA)
- **Analytics:** data cleaning, outlier detection, KPI design, segmentation, risk scoring

---

## 🔍 Key Questions Answered

- Which neighbourhoods and room types have the highest demand?
- How do minimum nights and price bands affect occupancy?
- Where is demand high but supply low?
- Which listings are stars, and which are dormant?
- Which hosts and listings carry the highest licensing risk?
- Which listings should be kept, fixed, improved or removed?

---

## ⚠️ Limitations

- **Estimated, not actual, bookings:** occupancy and revenue come from `availability_365`. Hosts can block dates for personal use, so occupancy may be overstated.
- **Reviews as a demand proxy:** not every guest leaves a review, and newer listings naturally have fewer reviews.
- **Single snapshot:** the data is one point in time, so seasonality and price changes over the year are not captured.
- **Imputed prices:** 1,059 listings (about 12%) have imputed prices, which can affect revenue and price-band results.
- **Missing values:** 1,525 listings have no `last_review`, and 44 are missing host information.
- **License data:** `license_status` depends on what hosts report. A listing marked "no license" may be exempt or simply unreported.
- **Rule-based scoring:** the performance weights (40/35/25), risk points and decision thresholds are judgement-based, not statistically validated. Different weights give different results.
- **Date-dependent output:** `days_since_last_review` uses `GETDATE()`, so categories such as DORMANT shift as time passes.
- **Segment size:** neighbourhood analysis excludes small segments (fewer than 30 or 10 listings), so tiny areas are not covered.
- **No external data:** competitor pricing, local events, and hotel supply are not included.

---

## 📝 Notes

- Occupancy and revenue are **estimates** derived from `availability_365` (booked days = 365 − availability). They are not actual booking data.
- `days_since_last_review` is calculated from the current date (`GETDATE()`), so results change over time.
- 1,059 prices were imputed (`price_imputed = 1`); consider filtering them for price-sensitive analysis.
- `EDA.ipynb` is currently a starter notebook and will be expanded with visualisations.

---

## 👤 Author

**mrinalini11-data**
GitHub: [github.com/mrinalini11-data](https://github.com/mrinalini11-data)

⭐ If you found this project useful, consider giving the repo a star!