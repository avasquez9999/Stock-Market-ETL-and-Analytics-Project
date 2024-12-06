/*
ETL STOCK Market  Project



*/

-------------------------------------------------------------
-- check the stock market data we have --------
-------------------------------------------------------------

-- date range?
SELECT min(date),max(date) FROM eod_quotes;

-- How many companies have full data in each year?
SELECT date_part('year',date), COUNT(*)/252 FROM eod_quotes GROUP BY date_part('year',date);

SELECT ticker, date, adj_close FROM eod_quotes WHERE date BETWEEN '2015-01-01' AND '2020-12-31';

-- And create a (simple version of) view v_eod_quotes_2015_2020
/*
-- LIFELINE
-- DROP VIEW public.v_eod_quotes_2015_2020;

CREATE OR REPLACE VIEW public.v_eod_quotes_2015_2020 AS
 SELECT eod_quotes.ticker,
    eod_quotes.date,
    eod_quotes.adj_close
   FROM eod_quotes
  WHERE eod_quotes.date >= '2015-01-01'::date AND eod_quotes.date <= '2020-12-31'::date;

ALTER TABLE public.v_eod_quotes_2015_2020
    OWNER TO postgres;

*/

-- Check
SELECT min(date),max(date) FROM v_eod_quotes_2015_2020;



-------------------------------------------------------------------------
-- We have stock quotes but we could also use daily index data ----------
-------------------------------------------------------------------------

-- Let's download 2015-2020 of SP500TR from Yahoo https://finance.yahoo.com/quote/%5ESP500TR/history?p=^SP500TR

-- - changed to general formating and added sp500 tr ticker and added a volume colom


-- Import the (modified) CSV sp500tr to the data table eod_indices which reflects the original file's structure

/*

LIFELINE:

-- DROP TABLE public.eod_indices;

CREATE TABLE public.eod_indices
(
    symbol character varying(16) COLLATE pg_catalog."default" NOT NULL,
    date date NOT NULL,
    open real,
    high real,
    low real,
    close real,
    adj_close real,
    volume double precision,
    CONSTRAINT eod_indices_pkey PRIMARY KEY (symbol, date)
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE public.eod_indices
    OWNER to postgres;

*/

-- Check
SELECT * FROM eod_indices LIMIT 10;

-- Create a view analogous to our quotes view: v_eod_indices_2015_2020

/*
--LIFELINE
-- DROP VIEW public.v_eod_indices_2015_2020;

CREATE OR REPLACE VIEW public.v_eod_indices_2015_2020 AS
 SELECT eod_indices.symbol,
    eod_indices.date,
    eod_indices.adj_close
   FROM eod_indices
   WHERE eod_indices.date >= '2015-01-01'::date AND eod_indices.date <= '2020-12-31'::date;

   
ALTER TABLE public.v_eod_indices_2015_2020
    OWNER TO postgres;
*/

-- CHECK
SELECT MIN(date),MAX(date) FROM v_eod_indices_2015_2020;

-- We can combine the two views using UNION which help us later (this will take a while)
SELECT * FROM v_eod_quotes_2015_2020 
UNION 
SELECT * FROM v_eod_indices_2015_2020;




-------------------------------------------------------------------------
-- Next, let's prepare a custom calendar (using a spreadsheet) --------
-------------------------------------------------------------------------

-- We need a stock market calendar to check our data for completeness
-- https://www.nyse.com/markets/hours-calendars

-- Because it is faster, we will use Excel (we need market holidays to do that)

-- We will use NETWORKDAYS.INTL function

-- coloms date, y,m,d,dow,trading 

-- Save as custom_calendar.csv and import to a new table

/*
LIFELINE:
-- DROP TABLE public.custom_calendar;

CREATE TABLE public.custom_calendar
(
    date date NOT NULL,
    y integer,
    m integer,
    d integer,
    dow character varying(3) COLLATE pg_catalog."default",
    trading smallint,
    CONSTRAINT custom_calendar_pkey PRIMARY KEY (date)
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE public.custom_calendar
    OWNER to postgres;

*/

-- CHECK:
SELECT * FROM custom_calendar LIMIT 10;

-- Let's add some columns to be used later: eom (end-of-month) and prev_trading_day

/*

ALTER TABLE public.custom_calendar
    ADD COLUMN eom smallint;

ALTER TABLE public.custom_calendar
    ADD COLUMN prev_trading_day date;
*/

-- CHECK:
SELECT * FROM custom_calendar LIMIT 10;

-- populate these columns

-- Identify trading days
SELECT * FROM custom_calendar WHERE trading=1;
-- Identify previous trading days via a nested query
SELECT date, (SELECT MAX(CC.date) FROM custom_calendar CC 
			  WHERE CC.trading=1 AND CC.date<custom_calendar.date) ptd 
			  FROM custom_calendar;
-- Update the table with new data 
UPDATE custom_calendar
SET prev_trading_day = PTD.ptd
FROM (SELECT date, (SELECT MAX(CC.date) FROM custom_calendar CC WHERE CC.trading=1 AND CC.date<custom_calendar.date) ptd FROM custom_calendar) PTD
WHERE custom_calendar.date = PTD.date;
-- CHECK
SELECT * FROM custom_calendar ORDER BY date;
-- we need the last day of 2014 to caulate monthly return
INSERT INTO custom_calendar VALUES('2014-12-31',2014,12,31,'Wed',1,1,NULL);
-- Re-run the update
-- CHECK again
SELECT * FROM custom_calendar ORDER BY date;

SELECT DATE_TRUNC('month', date) + INTERVAL '1 MONTH - 1 DAY' AS last_day_of_month
FROM custom_calendar;

-- Identify the end of the month
SELECT CC.date,CASE WHEN EOM.y IS NULL 
THEN 0 ELSE 1 END endofm FROM custom_calendar CC 
LEFT JOIN (SELECT y,m,MAX(d) lastd FROM custom_calendar
		   WHERE trading=1 GROUP by y,m) EOM
ON CC.y=EOM.y AND CC.m=EOM.m AND CC.d=EOM.lastd;
-- Update the table with new data
UPDATE custom_calendar
SET eom = EOMI.endofm
FROM (SELECT CC.date,CASE WHEN EOM.y IS NULL THEN 0 ELSE 1 END endofm FROM custom_calendar CC LEFT JOIN
(SELECT y,m,MAX(d) lastd FROM custom_calendar WHERE trading=1 GROUP by y,m) EOM
ON CC.y=EOM.y AND CC.m=EOM.m AND CC.d=EOM.lastd) EOMI
WHERE custom_calendar.date = EOMI.date;
-- CHECK
SELECT * FROM custom_calendar ORDER BY date;
SELECT * FROM custom_calendar WHERE eom=1 ORDER BY date;

--------------------------------
----- End of Part 3a -----------
--------------------------------

/*
******** RESTORE POINT stockmarket3
In order to continue learning, you need to have all the previous steps completed
If you would like to review later (and you need to know how to complete these steps).
However, in the interest of time, I have created a backup of the current progress and 
will now demonstrate how to restore it.

IMPORTANT: remove the current database and recreate it to restore from backup
DO NOT RESTORE THE BACKUP TO THE postgres database!
*/

--------------------------------
----- Begin Part 3b -----------
--------------------------------

------------------------------------------------------------------
-- We can now use the calendar to query prices and indexes -------
------------------------------------------------------------------

-- Calculate stock price (or index value) statistics

-- min, average, max and volatility (st.dev) of prices/index values for each month
SELECT symbol, y,m,min(adj_close) as min_adj_close,avg(adj_close) as avg_adj_close, max(adj_close) as max_adj_close,stddev_samp(adj_close) as std_adj_close 
FROM custom_calendar CC INNER JOIN v_eod_indices_2015_2020 II ON CC.date=II.date
GROUP BY symbol,y,m
ORDER BY symbol,y,m;
-- YOUR TURN: Change v_eod_indices_2015_2020 TO (SELECT * FROM v_eod_indices_2015_2020 UNION SELECT * FROM v_eod_quotes_2015_2020 WHERE ticker='AAPL')

-- Identify end-of-month prices/values for stock or index
SELECT II.*
FROM custom_calendar CC INNER JOIN v_eod_indices_2015_2020 II ON CC.date=II.date
WHERE CC.eom=1
ORDER BY II.date;
-- YOUR TURN: Identify end-of-month prices for v_eod_quotes_2015_2020

------------------------------------------------------------------
-- Determine the completeness of price or index data -------------
------------------------------------------------------------------


-- First, let's see how many trading days were there between 2015 and 2020
SELECT COUNT(*) 
FROM custom_calendar 
WHERE trading=1 AND date BETWEEN '2015-01-01' AND '2020-12-31';

-- Now, let us check how many price items we have for each stock in the same date range
SELECT ticker,min(date) as min_date, max(date) as max_date, count(*) as price_count
FROM v_eod_quotes_2015_2020
GROUP BY ticker
ORDER BY price_count DESC;

-- Let's calculate the percentage of complete trading day prices for each stock and identify 99%+ complete
SELECT ticker
, count(*)::real/(SELECT COUNT(*) FROM custom_calendar WHERE trading=1 AND date BETWEEN '2015-01-01' AND '2020-12-31')::real as pct_complete
FROM v_eod_quotes_2015_2020
GROUP BY ticker
HAVING count(*)::real/(SELECT COUNT(*) FROM custom_calendar WHERE trading=1 AND date BETWEEN '2015-01-01' AND '2020-12-31')::real>=0.99
ORDER BY pct_complete DESC;


-- Let's store the excluded tickers (less than 99% complete in a table)
SELECT ticker, 'More than 1% missing' as reason
INTO exclusions_2015_2020
FROM v_eod_quotes_2015_2020
GROUP BY ticker
HAVING count(*)::real/(SELECT COUNT(*) FROM custom_calendar WHERE trading=1 AND date BETWEEN '2015-01-01' AND '2020-12-31')::real<0.99;

-- define the PK constraint for exclusions_2015_2020
/*

ALTER TABLE public.exclusions_2015_2020
    ADD CONSTRAINT exclusions_2015_2020_pkey PRIMARY KEY (ticker);

*/

-- YOUR TURN: apply the same procedure for the indices and store exclusions (if any) in the same table: exclusions_2015_2020

-- CHECK
SELECT * FROM exclusions_2015_2020;


-- Let combine everything we have (it will take some time to execute)
SELECT * FROM v_eod_indices_2015_2020 WHERE symbol NOT IN  (SELECT DISTINCT ticker FROM exclusions_2015_2020)
UNION
SELECT * FROM v_eod_quotes_2015_2020 WHERE ticker NOT IN  (SELECT DISTINCT ticker FROM exclusions_2015_2020);

--  store it as a new view v_eod_2015_2020

/*
-- LIFELINE:
-- DROP VIEW public.v_eod_2015_2020;

CREATE OR REPLACE VIEW public.v_eod_2015_2020 AS
 SELECT v_eod_indices_2015_2020.symbol,
    v_eod_indices_2015_2020.date,
    v_eod_indices_2015_2020.adj_close
   FROM v_eod_indices_2015_2020
  WHERE NOT (v_eod_indices_2015_2020.symbol::text IN ( SELECT DISTINCT exclusions_2015_2020.ticker
           FROM exclusions_2015_2020))
UNION
 SELECT v_eod_quotes_2015_2020.ticker AS symbol,
    v_eod_quotes_2015_2020.date,
    v_eod_quotes_2015_2020.adj_close
   FROM v_eod_quotes_2015_2020
  WHERE NOT (v_eod_quotes_2015_2020.ticker::text IN ( SELECT DISTINCT exclusions_2015_2020.ticker
           FROM exclusions_2015_2020));

ALTER TABLE public.v_eod_2015_2020
    OWNER TO postgres;

*/

-- CHECK:
SELECT * FROM v_eod_2015_2020; -- slow
SELECT DISTINCT symbol FROM v_eod_2015_2020;

-- create a materialized view mv_eod_2015_2020

/*
--LIFELINE

-- DROP MATERIALIZED VIEW public.mv_eod_2015_2020;

CREATE MATERIALIZED VIEW public.mv_eod_2015_2020
TABLESPACE pg_default
AS
 SELECT v_eod_indices_2015_2020.symbol,
    v_eod_indices_2015_2020.date,
    v_eod_indices_2015_2020.adj_close
   FROM v_eod_indices_2015_2020
  WHERE NOT (v_eod_indices_2015_2020.symbol::text IN ( SELECT DISTINCT exclusions_2015_2020.ticker
           FROM exclusions_2015_2020))
UNION
 SELECT v_eod_quotes_2015_2020.ticker AS symbol,
    v_eod_quotes_2015_2020.date,
    v_eod_quotes_2015_2020.adj_close
   FROM v_eod_quotes_2015_2020
  WHERE NOT (v_eod_quotes_2015_2020.ticker::text IN ( SELECT DISTINCT exclusions_2015_2020.ticker
           FROM exclusions_2015_2020))
WITH NO DATA;

ALTER TABLE public.mv_eod_2015_2020
    OWNER TO postgres;
*/
-- must do
REFRESH MATERIALIZED VIEW mv_eod_2015_2020 WITH DATA;

-- CHECK
SELECT * FROM mv_eod_2015_2020; -- faster
SELECT DISTINCT symbol FROM mv_eod_2015_2020; -- fast
SELECT * FROM mv_eod_2015_2020 WHERE symbol='AAPL' ORDER BY date;
SELECT * FROM mv_eod_2015_2020 WHERE symbol='SP500TR' ORDER BY date;

-- We can even add a couple of indexes to our materialized view if we want to speed up access some more

--------------------------------------------------------
-- Calculate daily returns or changes ------------------
--------------------------------------------------------

--  daily return equation R_1=(P_1-P_0)/P_0=P_1/P_0-1.0 (P:price, i.e., adj_close)

-- join the calendar with the prices (and indices)

SELECT EOD.*, CC.* 
FROM mv_eod_2015_2020 EOD INNER JOIN custom_calendar CC ON EOD.date=CC.date;

-- Next, let us use the prev_trading_day in a join to determine prev_adj_close (this will take some time)
SELECT EOD.symbol,EOD.date,EOD.adj_close,PREV_EOD.date AS prev_date,PREV_EOD.adj_close AS prev_adj_close
FROM mv_eod_2015_2020 EOD INNER JOIN custom_calendar CC ON EOD.date=CC.date
INNER JOIN mv_eod_2015_2020 PREV_EOD ON PREV_EOD.symbol=EOD.symbol AND PREV_EOD.date=CC.prev_trading_day;

-- Change the columns in the select clause to return (ret) and create another materialized view mv_ret_2015_2020
SELECT EOD.symbol,EOD.date,EOD.adj_close/PREV_EOD.adj_close-1.0 AS ret
FROM mv_eod_2015_2020 EOD INNER JOIN custom_calendar CC ON EOD.date=CC.date
INNER JOIN mv_eod_2015_2020 PREV_EOD ON PREV_EOD.symbol=EOD.symbol AND PREV_EOD.date=CC.prev_trading_day;

-- Let's make another materialized view - this time with the returns

/*


-- DROP MATERIALIZED VIEW public.mv_ret_2015_2020;

CREATE MATERIALIZED VIEW public.mv_ret_2015_2020
TABLESPACE pg_default
AS
 SELECT eod.symbol,
    eod.date,
    eod.adj_close / prev_eod.adj_close - 1.0::double precision AS ret
   FROM mv_eod_2015_2020 eod
     JOIN custom_calendar cc ON eod.date = cc.date
     JOIN mv_eod_2015_2020 prev_eod ON prev_eod.symbol::text = eod.symbol::text AND prev_eod.date = cc.prev_trading_day
WITH NO DATA;

ALTER TABLE public.mv_ret_2015_2020
    OWNER TO postgres;
*/

-- We must refresh it (it will take time but it is one-time or infrequent)
REFRESH MATERIALIZED VIEW mv_ret_2015_2020 WITH DATA;

-- CHECK
SELECT * FROM mv_ret_2015_2020;
SELECT * FROM mv_ret_2015_2020 WHERE symbol='AAPL' ORDER BY date;
SELECT * FROM mv_ret_2015_2020 WHERE symbol='SP500TR' ORDER BY date;

------------------------------------------------------------------
-- Identify potential errors and expand the exlusions list --------
------------------------------------------------------------------

-- Let's explore first
SELECT min(ret),avg(ret),max(ret) from mv_ret_2015_2020;
SELECT * FROM mv_ret_2015_2020 ORDER BY ret DESC;

-- Made an arbitrary decision how much daily return is too much (e.g. 100%), identify such symbols
-- and add them to exclusions_2015_2020
INSERT INTO exclusions_2015_2020
SELECT DISTINCT symbol, 'Return higher than 100%' as reason FROM mv_ret_2015_2020 WHERE ret>1.0;

-- CHECK:
SELECT * FROM exclusions_2015_2020 WHERE reason LIKE 'Return%';
-- They should be excluded BUT THEY ARE NOT!
SELECT * FROM mv_eod_2015_2020 WHERE symbol='GWPH';
SELECT * FROM mv_ret_2015_2020 WHERE symbol='GWPH' ORDER BY ret DESC;
-- IMPORTANT: we have stored (materialized) views, we need to refresh them IN A SEQUENCE!
REFRESH MATERIALIZED VIEW mv_eod_2015_2020 WITH DATA;
-- CHECK:
SELECT * FROM mv_eod_2015_2020 WHERE symbol='GWPH'; -- excluded

REFRESH MATERIALIZED VIEW mv_ret_2015_2020 WITH DATA;
-- CHECK:
SELECT * FROM mv_ret_2015_2020 WHERE symbol='GWPH'; -- excluded

---------------------------------------------------------------------------
-- Format price and return data for export to the analytical tool  --------
---------------------------------------------------------------------------

-- In order to export all data had to left-join custom_calendar with materialized views
-- This way i will not miss a trading day even if there is not a single record available

--  need to write data to (temporary) tables so that we can export them to CSV
-- Or we can select the query and use "Download as CSV (F8)" in PgAdmin

-- Daily prices export
SELECT PR.* 
INTO export_daily_prices_2015_2020
FROM custom_calendar CC LEFT JOIN mv_eod_2015_2020 PR ON CC.date=PR.date
WHERE CC.trading=1;

-- Monthly (eom) prices export
SELECT PR.* 
INTO export_monthly_prices_2015_2020
FROM custom_calendar CC LEFT JOIN mv_eod_2015_2020 PR ON CC.date=PR.date
WHERE CC.trading=1 AND CC.eom=1;

-- Daily returns export
SELECT PR.* 
INTO export_daily_returns_2015_2020
FROM custom_calendar CC LEFT JOIN mv_ret_2015_2020 PR ON CC.date=PR.date
WHERE CC.trading=1;



CREATE EXTENSION IF NOT EXISTS tablefunc;

-- crosstab is not going to work because crosstab requires pre-specyfying types for all columns
SELECT * 
FROM crosstab('SELECT date, symbol, adj_close from mv_eod_2015_2020 ORDER BY 1,2','SELECT DISTINCT symbol FROM mv_eod_2015_2020 ORDER BY 1') 
AS ct(dte date, A real);
-- Technically i could code a custom return type but it would be very tedious and one-time
-- The problem here is that we need to manually define return types for all 2000+ stock tickers
--  you cant work-around because of 1600 columns limit
-- So, i will deal with pivoting in R (Excel will not take 6M+ rows)

-------------------------------------------
-- Create a role for the database so can quiry with r --------
-------------------------------------------
-- rolename: stockmarketreader
-- password: read123

-- LIFELINE:
-- REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM stockmarketreader;
-- DROP USER stockmarketreader;

CREATE USER stockmarketreader WITH
	LOGIN
	NOSUPERUSER
	NOCREATEDB
	NOCREATEROLE
	INHERIT
	NOREPLICATION
	CONNECTION LIMIT -1
	PASSWORD 'read123';

-- Grant read rights (on existing tables and views)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO stockmarketreader;

-- Grant read rights (for future tables and views)
ALTER DEFAULT PRIVILEGES IN SCHEMA public
   GRANT SELECT ON TABLES TO stockmarketreader;

