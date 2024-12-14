## SQL ELT Project with Analysis on Stock Market Data

**Description:**
This project involved developing an R script to automate the process of obtaining electricity load data from the New York Independent System Operator (NYISO) website. The script periodically scrapes the website, cleans and formats the extracted data, and then loads it into a designated table within a PostgreSQL database. Prior to data insertion, a database was created, and a user role with appropriate reader-writer privileges was established to facilitate seamless communication and data transfer between R and the PostgreSQL server. The requested cleaned and formatted data within the database is the foundation for building a predictive electricity load forecasting model using the Fable Package in R.


**Data Extraction:** Extracted financial data from diverse sources.

**Data Loading:** Loaded the extracted data into a PostgreSQL database for efficient storage and retrieval.

**Data Cleaning** and Transformation: Cleaned and preprocessed the data, including handling missing values, outliers, and inconsistencies.

**Data Integration:** Integrated a custom trading day calendar to ensure data completeness and facilitate time-based aggregations.

**Data Analysis:** Performed various financial analyses, such as calculating returns, risk metrics, and correlations.

**Portfolio Optimization:** Implemented a Markowitz portfolio optimization model to construct efficient portfolios.

**Visualization:** Created visualizations to understand and communicate the results, including charts and graphs.

**Report Generation:** Exported the analysis results to a CSV file for further analysis and reporting.

## Key Technologies:


**PostgreSQL:** Used as a data warehouse for efficient data storage and retrieval.

**R:** Used for data analysis, visualization, and portfolio optimization. By leveraging this robust data pipeline and advanced analytical techniques, we were able to effectively extract, transform, analyze, and visualize financial data to support informed investment decisions.

**Excel:** custom trading day calendar to ensure data completeness and facilitate time-based aggregations.

**Fable** Used Rob Hyndman Forecasting package using r



