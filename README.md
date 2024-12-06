## SQL ELT Project with Analysis on Stock Market Data


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

**R:** Used for data analysis, visualization, and portfolio optimization.By leveraging this robust data pipeline and advanced analytical techniques, we were able to effectively extract, transform, analyze, and visualize financial data to support informed investment decisions.

**Excel:** custom trading day calendar to ensure data completeness and facilitate time-based aggregations.

##Instructions

To effectively follow these steps, you'll need:

pgAdmin 4: A powerful database management tool to create and manage PostgreSQL databases.

PostgreSQL Database: A database server installed on your local machine or a cloud-based provider.

R and RStudio: A statistical computing environment for data analysis and visualization.

The provided database restore file: This file contains the schema and data for your stock market analysis.

Steps to Follow:

Install pgAdmin 4: Download and install pgAdmin 4 from the official website.

Create a New Database:

Open pgAdmin 4 and create a new database named "stockMarket".

Restore the Database: Use the provided restore file to restore the database.  The specific steps may vary depending on your database server configuration. Consult the pgAdmin 4 documentation for detailed instructions.

Connect to the Database from R:

Use the DBI package to connect to the PostgreSQL database:

Query data using DBI package in r

Run analysis using my r file
