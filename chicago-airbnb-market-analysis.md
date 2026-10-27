# Chicago Airbnb Market Analysis | Data Analytics Project

## Project Overview

This project analyzes Airbnb listings in Chicago to identify neighbourhood-level market opportunities, understand pricing patterns, evaluate listing performance, and support data-driven decisions.

The project combines Python-based data cleaning and exploratory data analysis (EDA) with SQL-based data exploration and a Power BI dashboard built using neighbourhood-level opportunity metrics generated through Python.

Rather than presenting only descriptive charts, the project focuses on answering a business question:

**Which Chicago neighbourhoods present attractive Airbnb market opportunities based on pricing, listing activity, guest engagement, and market stability?**

The analysis is intended to help prospective hosts, property investors, and market researchers compare neighbourhoods and identify areas worth investigating further.

## Business Objectives

- Understand the distribution of Airbnb listings across Chicago neighbourhoods.
- Analyze listing prices, review activity, and market characteristics.
- Identify neighbourhoods with different levels of market opportunity.
- Compare market activity with indicators of listing engagement and stability.
- Build an interactive Power BI dashboard that supports neighbourhood-level exploration and investment research.
- Communicate analytical findings through actionable business insights rather than charts alone.

## Project Workflow

The project follows a data analytics workflow from raw data preparation to business reporting.

1. **Data preparation:** Inspect the dataset, evaluate missing values, examine data types, and identify inconsistent or potentially invalid records.
2. **Data cleaning:** Use Python and Pandas to prepare listing data and handle selected missing values, price anomalies, and neighbourhood classifications.
3. **Exploratory data analysis:** Investigate pricing, reviews, listing distribution, and differences between neighbourhoods.
4. **Opportunity analysis:** Generate neighbourhood-level metrics and opportunity indicators using Python.
5. **SQL analysis:** Use SQL for data exploration, validation, aggregations, and analytical queries.
6. **Power BI reporting:** Import `neighbourhood_opportunity.csv` and build an interactive dashboard around the Python-generated opportunity metrics.

## Tools and Technologies

- **Python:** Data preparation, exploratory analysis, metric calculation, and opportunity analysis.
- **Pandas and NumPy:** Data manipulation, aggregation, and numerical calculations.
- **Jupyter Notebook:** Analysis workflow and documentation of analytical steps.
- **SQL Server:** Data exploration, querying, aggregations, and validation.
- **Power BI:** Interactive reporting, KPI presentation, neighbourhood comparisons, and opportunity analysis.
- **CSV:** Storage and transfer of cleaned listing data and neighbourhood-level analytical results.

## Repository Structure

| File | Purpose |
|---|---|
| `EDA.ipynb` | Python notebook for data exploration, cleaning, and analytical work. |
| `Clean_Listing_.csv` | Cleaned Airbnb listing dataset used for listing-level analysis. |
| `neighbourhood_opportunity.csv` | Neighbourhood-level opportunity dataset generated through Python and used as the primary Power BI data source. |
| `airbnb.pbix` | Power BI report for exploring neighbourhood-level Airbnb market opportunities. |
| `airbnb.sql` | SQL queries for data exploration, validation, aggregation, and listing analysis. |

## Power BI Dashboard

The Power BI dashboard uses `neighbourhood_opportunity.csv` as its primary data source. Its purpose is to help users compare neighbourhoods and investigate market opportunities using metrics prepared in Python.

The report is organized around three business-focused pages.

### 1. Market Brief

Provides an overview of the Chicago Airbnb market and establishes the context for neighbourhood comparisons.

**Analytical focus:**
- Listing distribution and market size.
- Neighbourhood-level pricing patterns.
- Guest review activity and engagement indicators.
- Overall market characteristics and variation between neighbourhoods.

**Business question:** What does the Chicago Airbnb market look like, and how does it vary across neighbourhoods?

### 2. Opportunity Explorer

Helps users compare neighbourhoods using the available opportunity indicators and identify areas that may warrant further research.

**Analytical focus:**
- Neighbourhood-level listing counts.
- Median listing prices.
- Review activity and engagement indicators.
- Opportunity segments or quadrants calculated in Python.
- Comparisons between market activity and other available opportunity measures.

**Business question:** Which neighbourhoods appear promising, and what characteristics distinguish them from other areas?

Opportunity classifications are analytical screening tools, not proof of profitability or future demand.

### 3. Investment Simulator

Provides a decision-support perspective for comparing potential neighbourhood opportunities.

**Analytical focus:**
- Comparing neighbourhood characteristics.
- Examining price and market-activity indicators.
- Assessing how alternative neighbourhood choices compare on the available metrics.
- Supporting an initial shortlist for further investment research.

**Business question:** Which neighbourhoods should be investigated further based on the selected market indicators?

The dashboard should not be interpreted as a financial forecasting model unless verified rental income, operating expenses, occupancy, taxes, and investment costs are incorporated.

## Understanding the Opportunity Dataset

The file `neighbourhood_opportunity.csv` is the main analytical dataset for the Power BI report.

It contains neighbourhood-level metrics derived from listing data and Python-based analysis. Depending on the implemented calculations, these metrics include:

- **Listing count:** Number of listings represented in a neighbourhood.
- **Median price:** Median recorded listing price, useful for comparing typical advertised prices.
- **Review metrics:** Indicators of guest review activity.
- **Engagement index:** A calculated indicator intended to compare engagement across neighbourhoods.
- **Expected and actual values:** Analytical comparison measures used by the opportunity methodology.
- **Stability:** A calculated indicator representing the stability dimension defined by the Python analysis.
- **Active share:** A calculated proportion representing the activity definition used in the analysis.
- **Opportunity segment or quadrant:** A category assigned using the implemented segmentation logic.

The precise interpretation of derived metrics depends on their formulas in the notebook. They should not be treated as standard industry measures without documenting the calculations and validating their assumptions.

## Analytical Approach

The project combines descriptive analysis with neighbourhood-level comparisons.

### Data quality and preparation

The notebook examines missing values, data types, inconsistent fields, and unusual price values. Selected fields are cleaned or imputed according to the implemented rules.

Imputed values and modified outliers should be distinguished from original observations when interpreting price-related findings.

### Neighbourhood comparison

Listing counts, median prices, and review activity are compared to identify differences in market characteristics.

### Opportunity segmentation

Python calculates neighbourhood-level indicators and assigns opportunity categories using the implemented segmentation method. These categories support comparison and exploration; they do not establish that one neighbourhood will necessarily outperform another.

### Business interpretation

Power BI presents the prepared metrics in a format that helps users investigate patterns, compare neighbourhoods, and identify areas for additional research.

## Key Questions This Project Explores

- How does Airbnb listing supply vary across Chicago neighbourhoods?
- Which neighbourhoods have relatively high or low median listing prices?
- How does review activity differ between neighbourhoods?
- Which neighbourhoods stand out when multiple market indicators are considered together?
- Where do market characteristics suggest opportunities for further investigation?
- What additional evidence would be required before making a property investment decision?

## Important Limitations

This analysis is intended for exploratory market research and decision support.

- Advertised listing prices are not the same as realized nightly revenue.
- Listing availability is not a direct measure of occupancy because hosts may block dates or leave calendars unavailable.
- Review counts and recent review activity are imperfect proxies for booking activity and demand.
- License text patterns alone cannot establish legal compliance. Verification against authoritative records and applicable Chicago regulations is necessary.
- Missing-value imputation and outlier treatment can affect neighbourhood comparisons and derived metrics.
- Calculated opportunity indicators depend on their definitions, assumptions, and segmentation rules.
- Neighbourhood-level averages and medians may conceal substantial differences between individual properties.
- Profitability cannot be established without verified occupancy, expenses, fees, taxes, financing assumptions, and applicable regulatory requirements.

The dashboard should therefore be used to shortlist neighbourhoods for further investigation, not as a guarantee of demand, compliance, or investment returns.

## How to Explore the Project

1. Open `EDA.ipynb` to review the Python analysis and understand the data preparation and opportunity calculations.
2. Review `Clean_Listing_.csv` for the cleaned listing-level data.
3. Examine `neighbourhood_opportunity.csv` to understand the neighbourhood-level metrics used in the dashboard.
4. Open `airbnb.pbix` in Power BI Desktop to explore the report.
5. Review `airbnb.sql` to examine the SQL queries and analytical checks.

The notebook's input files and execution order may need to be adjusted to match the local environment. The generated CSV files should be refreshed after the underlying analysis changes.

## Project Outcome

This project demonstrates an end-to-end analytical approach to an Airbnb market research problem: preparing data, exploring market patterns, calculating neighbourhood-level indicators, querying data with SQL, and communicating findings through Power BI.

Its main emphasis is on **turning listing-level data into neighbourhood-level insights that support structured market comparison and informed follow-up research.**

---

*Disclaimer: This is an independent data analytics project. The findings are exploratory and should not be interpreted as official market statistics, legal advice, or financial advice.*
