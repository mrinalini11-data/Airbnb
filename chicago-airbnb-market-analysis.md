# Chicago Airbnb: Where Is There Room for More Listings?

I wanted to answer one question: **which Chicago neighborhoods could take more Airbnb supply, and which ones are already full?**

I used 8,704 cleaned listings across 77 neighborhoods. Python (pandas, seaborn, matplotlib) did the cleaning and scoring, SQL Server holds the deeper queries, and Power BI has the dashboard.

## The short version

- **Best bets:** South Lawndale, Englewood, Lincoln Square, Armour Square and East Garfield Park. Few listings, plenty of recent reviews, and prices below the city median.
- **Weakest bets:** Near North Side, Loop and Near West Side. They have the most listings in the city (1,083, 617 and 608) and their review activity is at or below the middle.
- **Don't rush:** a group of low-supply neighborhoods with weak engagement, like Dunning, Hermosa and Norwood Park. Few listings there may just mean few guests.

## How I judged each neighborhood

I only scored the 44 neighborhoods with at least 30 listings. The other 33 have too few listings to say anything reliable about them.

For each one I looked at three things:

| What | Measure | Why this one |
|---|---|---|
| Supply | Number of listings | Simplest way to see how big the market is |
| Engagement | Average reviews in the last 12 months per listing | Lifetime reviews favor old listings, so I avoided them |
| Price | Median nightly price | One $9,501 listing in East Garfield Park says nothing about a typical stay, so no max or mean |

I split neighborhoods at the median for supply (116 listings) and engagement (13.6 reviews per listing). That gives four groups:

| Group | Meaning | Count |
|---|---|---|
| Opportunity | Low supply, strong engagement | 8 |
| Established | High supply, strong engagement | 14 |
| Saturated | High supply, weak engagement | 8 |
| Watch | Low supply, weak engagement | 14 |

I also built a 0-100 opportunity score: 35% low supply, 45% engagement, 20% affordable price. Each part is a percentile rank. The weights sit at the top of the script if you want to change them.

## Where opportunity is high

These eight have fewer than 116 listings but more than 13.6 reviews per listing.

| Rank | Neighborhood | Listings | Reviews LTM / listing | Median price | Score |
|---|---|---|---|---|---|
| 1 | South Lawndale | 51 | 20.6 | $151 | 83 |
| 2 | Englewood | 50 | 13.8 | $70 | 71 |
| 3 | Lincoln Square | 113 | 26.0 | $197 | 71 |
| 4 | Armour Square | 85 | 17.1 | $142 | 70 |
| 5 | East Garfield Park | 104 | 16.9 | $144 | 67 |
| 6 | Jefferson Park | 59 | 16.7 | $175 | 67 |
| 7 | Portage Park | 113 | 16.8 | $159 | 62 |
| 8 | Albany Park | 81 | 16.1 | $170 | 62 |

South Lawndale is the clearest pick. Lincoln Square has the highest engagement of the group (26.0) at a median of $197, which is still below the city median of $240.

Englewood needs a caveat. Its engagement is only just above the cut-off (13.8 vs 13.6), so it sits there more on cheap prices ($70) than on strong demand.

**How firm is this ranking?** I tried 71 different weight combinations. South Lawndale came first in 64 of them and Englewood in the other 7. The order of ranks 4 and 5 changes a lot, though, so I trust "these neighborhoods are good candidates" more than "this exact order."

## Where it's weak

**Saturated (lots of listings, weak engagement)**

| Neighborhood | Listings | Reviews LTM / listing |
|---|---|---|
| Near North Side | 1,083 | 13.3 |
| Loop | 617 | 12.7 |
| Near West Side | 608 | 10.6 |
| Woodlawn | 237 | 6.9 |
| Grand Boulevard | 173 | 9.1 |
| South Shore | 118 | 5.4 |

Near North Side is only 0.3 reviews under the cut-off, so it's a narrow miss, not a collapse. Near West Side (10.6) and South Shore (5.4) are clearly weaker.

**Watch (few listings, weak engagement)**

Dunning, Hermosa, Norwood Park, McKinley Park, Washington Park, New City, South Chicago, North Lawndale, Kenwood, Auburn Gresham, West Ridge, Belmont Cragin, Greater Grand Crossing and Austin. South Chicago (3.1) and Greater Grand Crossing (3.9) are the weakest on engagement.

Some of these score fairly high (Dunning is 61), because low supply and low price both help the score. I wouldn't read that as a green light.

## What I'd do

1. **Start recruiting hosts in the eight Opportunity neighborhoods**, beginning with South Lawndale, Lincoln Square and Armour Square.
2. **Hold off on growth in Near North Side, Loop and Near West Side** unless occupancy data says otherwise.
3. **Look closer at the Watch group before adding supply.** Low supply plus weak engagement may just be weak demand.
4. **Use median price, not maximum,** for any pricing or targeting decision.
5. **Treat shared rooms as a small pilot at most.** Only 32 listings exist, they average 6.6 reviews LTM, and the dataset has nothing on guest interests or satisfaction.

## Other things I found

- Supply is concentrated. The five biggest neighborhoods (Near North Side, West Town, Loop, Near West Side, Lake View) hold 41.5% of all listings. Among the 44 neighborhoods I scored, the top five hold 43.5%.
- Pricier neighborhoods tend to have more listings, not fewer (Spearman +0.62 for median price vs supply). Price also moves with engagement (+0.41), and supply with engagement (+0.43). So "expensive means under-supplied" doesn't hold. My opportunity score does favor cheaper areas, which I set on purpose, but it's only 20% of the score.
- Entire homes are 76.6% of listings (6,663), with a median of $257. Private rooms are 1,939 listings at $89.
- 33.8% of listings have no license (2,938). Another 29 have an invalid one.
- Loop, Near North Side and Lincoln Park have the highest average prices (about $414, $409 and $389).

## What this can't tell you

- Reviews are my stand-in for demand. They aren't bookings or occupancy.
- There are no star ratings, so "strong engagement" means review volume, not guest satisfaction.
- 1,059 prices (12.2%) were missing and I filled them with the median for the same room type. I haven't re-run the ranking without them yet. A rough check, dropping rows priced exactly at their room-type median, kept South Lawndale first and four of the top five.
- The North/South/East/West/Center zones come from my own latitude and longitude cut-offs, not official boundaries. East Garfield Park, for example, has 56 listings in "West" and 48 in "Center." The neighborhood results don't use the zones.
- The revenue and occupancy numbers in the SQL assume a 50% review rate and a minimum stay of at least 3 nights. Treat them as rough estimates.
- It's one snapshot, so there's no seasonality or trend behind any of this.

## Files

```
├── CleanListing_.csv      # cleaned data (8,704 rows, 20 columns)
├── EDA.ipynb              # cleaning, exploration, opportunity matrix
├── SQLQuery1.sql          # views and queries: demand index, ADR, occupancy, segments
├── airbnb.pbix            # Power BI dashboard
└── README.md
```

The SQL builds a view called `vw_Listing` and uses it for price vs demand, supply concentration (including HHI), inactive listings, seasonality, ADR and estimated occupancy, a host lifetime value proxy, and a demand-vs-price segmentation.

