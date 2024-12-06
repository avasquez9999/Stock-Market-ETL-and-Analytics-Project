install.packages("PerformanceAnalytics")
install.packages("PortfolioAnalytics")


#Perform ELT by extacting data from yahoo then loadinging it to a database then extracting from 
#database using r and performed analytics and eported to a csv table for further analysis
#USED R for transformation and analytics and wrote it to 
#Extract Data From PostGre data Base Table
#Manipulate, validate, and clean DAta 
# Calculate daily return, and monthly returns

#Perform Aadvanced analytics and data visualiztions
# Created a Non Convex optimizationa model that optimized return while minimizing risk

# Stock Market project in R
rm(list=ls(all=T)) # this just removes everything from memory

# Prepare a CSV file daily_prices_2015_2020.csv 
# in pgAdmin

# Load CSV Files ----------------------------------------------------------

# Load daily prices from CSV - no parameters needed
dp<-read.csv('C:/Users/avasq/OneDrive/Documents/daily_prices_2015_2020.csv') # no arguments

#Explore
head(dp) #first few rows
tail(dp) #last few rows
nrow(dp) #row count

ncol(dp) #column count

#remove the last row (because it was empty/errors)
dp<-head(dp,-1)

rm(dp) # remove from memory
# perform most of the transformation tasks in R

# Connect to PostgreSQL ---------------------------------------------------

# First I  created the reader role for the PostgreSQL database
# and granted that role SELECT rights to all tables




require(RPostgres) # did you install this package?
require(DBI)
conn <- dbConnect(RPostgres::Postgres()
                 ,user="stockmarketreader"
                 ,password="read123"
                 ,host="localhost"
                 ,port=5432
                 ,dbname="stockmarket"
)

#custom calendar
qry<-'SELECT * FROM custom_calendar ORDER by date'
ccal<-dbGetQuery(conn,qry)
#eod prices and indices
qry1="SELECT symbol,date,adj_close FROM eod_indices WHERE date BETWEEN '2014-12-31' AND '2020-12-31'"
qry2="SELECT ticker,date,adj_close FROM eod_quotes WHERE date BETWEEN '2014-12-31' AND '2020-12-31'"
eod<-dbGetQuery(conn,paste(qry1,'UNION',qry2))
dbDisconnect(conn)
rm(conn)

#Explore
head(ccal)
tail(ccal)
nrow(ccal)

head(eod)
tail(eod)
nrow(eod)

head(eod[which(eod$symbol=='SP500TR'),])

#For monthly we may need one more data item (for 2014-12-31)
#We can add it to the database (INSERT INTO) - but to practice:
eod_row<-data.frame(symbol='SP500TR',date=as.Date('2014-12-31'),adj_close=3769.44)
eod<-rbind(eod,eod_row)
tail(eod)

# Use Calendar --------------------------------------------------------

tdays<-ccal[which(ccal$trading==1),,drop=F]
head(tdays)
nrow(tdays)-1 # the reason why we minus one is because we cant to subtract total by one because 2014 days
#trading days between 2015 and 2020
# Completeness ----------------------------------------------------------
# Percentage of completeness
pct<-table(eod$symbol)# totall number of record for each ticker

pct<-table(eod$symbol)/(nrow(tdays)-1)
counteod$symbol
pct<-table(eod$symbol)/(nrow(tdays)-1)
bbb<- which(pct>.99)
selected_symbols_daily<-names(pct)[which(pct>=0.99)]
eod_complete<-eod[which(eod$symbol %in% selected_symbols_daily),,drop=F]

#check
head(eod_complete)
tail(eod_complete)
nrow(eod_complete)

#YOUR TURN: perform all these operations for monthly data
#Create eom and eom_complete
#Hint: which(ccal$trading==1 & ccal$eom==1)

# Transform (Pivot) -------------------------------------------------------

require(reshape2) #piviot table longer since excel cant piviot 6 million record
eod_pvt<-dcast(eod_complete, date ~ symbol,value.var='adj_close',fun.aggregate = mean, fill=NULL)
#check

eod_pvt[1:10,1:5] #first 10 rows and first 5 columns 
ncol(eod_pvt) # column count
nrow(eod_pvt)


# Merge with Calendar -----------------------------------------------------
eod_pvt_complete<-merge.data.frame(x=tdays[,'date',drop=F],y=eod_pvt,by='date',all.x=T)
head(eod_pvt_complete)
#check
eod_pvt_complete[1:10,1:5] #first 10 rows and first 5 columns 
ncol(eod_pvt_complete)
nrow(eod_pvt_complete)

#use dates as row names and remove the date column
rownames(eod_pvt_complete)<-eod_pvt_complete$date
eod_pvt_complete$date<-NULL #remove the "date" column

#re-check
eod_pvt_complete[1:10,1:5] #first 10 rows and first 5 columns 
ncol(eod_pvt_complete)
nrow(eod_pvt_complete)

# Missing Data Imputation -----------------------------------------------------
# We can replace a few missing (NA or NaN) data items with previous data
# fill in missing values with previous last recorded values for no more than 3 in a row...
require(zoo)
eod_pvt_complete<-na.locf(eod_pvt_complete,na.rm=F,fromLast=F,maxgap=3)
#re-check
eod_pvt_complete[1:10,1:5] #first 10 rows and first 5 columns 
ncol(eod_pvt_complete)
nrow(eod_pvt_complete)
tail(eod_pvt_complete)

# Calculating Returns -----------------------------------------------------
require(PerformanceAnalytics)
eod_ret<-CalculateReturns(eod_pvt_complete)
tail(eod_ret)
#check
eod_ret[1:10,1:3] #first 10 rows and first 3 columns 
ncol(eod_ret)
nrow(eod_ret)

#remove the first row
eod_ret<-tail(eod_ret,-1) #use tail with a negative value
#check
eod_ret[1:10,1:3] #first 10 rows and first 3 columns 
ncol(eod_ret)
nrow(eod_ret)

#monthly returns

library(dplyr)

# Assuming max_daily_ret is a named vector
max_selected_symbols_daily <- names(max_daily_ret)[max_daily_ret <= 1.00]


# There is colSums, colMeans but no colMax so we need to create it
colMax <- function(data) sapply(data, max, na.rm = TRUE)
# Apply it
max_daily_ret<-colMax(eod_ret)
max_daily_ret[1:10] #first 10 max returns
# And proceed just like we did with percentage (completeness)
selected_symbols_daily<-names(max_daily_ret)[which(max_daily_ret<=1.00)]
length(selected_symbols_daily)

#subset eod_ret
eod_ret<-eod_ret[,which(colnames(eod_ret) %in% selected_symbols_daily),drop=F]
str(eod_ret)
#check
eod_ret[1:10,1:3] #first 10 rows and first 3 columns 
ncol(eod_ret)
nrow(eod_ret)


# Export data from R to CSV -----------------------------------------------
write.csv(eod_ret,'C:/Temp/eod_ret.csv')

# You can actually open this file in Excel!


# Tabular Return Data Analytics -------------------------------------------

# We will select 'SP500TR' and 12 RANDOM TICKERS
set.seed(100) # seed can be any number, it will ensure repeatability
random12 <- sample(colnames(eod_ret),12)
# We need to convert data frames to xts (extensible time series)
Ra<-as.xts(eod_ret[,random12,drop=F])
Rb<-as.xts(eod_ret[,'SP500TR',drop=F]) #benchmark

head(Ra)
head(Rb)

# And now we can use the analytical package...

# Stats
table.Stats(Ra)

# Distributions
table.Distributions(Ra)

# Returns
table.AnnualizedReturns(cbind(Rb,Ra),scale=252) # note for monthly use scale=12

# Accumulate Returns
acc_Ra<-Return.cumulative(Ra)
acc_Rb<-Return.cumulative(Rb)

# Capital Assets Pricing Model
table.CAPM(Ra,Rb)


# Graphical Return Data Analytics -----------------------------------------

# Cumulative returns chart
chart.CumReturns(Ra,legend.loc = 'topleft')
chart.CumReturns(Rb,legend.loc = 'topleft')

#Box plots
chart.Boxplot(cbind(Rb,Ra))

chart.Drawdown(Ra,legend.loc = 'bottomleft')
chart.Boxplot(cbind(Rb,Ra))


chart.TimeSeries(cbind(Rb,Ra))
chart.TimeSeries(Rb)

chart.RelativePerformance(Ra,Rb,legend.loc = 'topleft')# YOUR TURN: try other charts

# MV Portfolio Optimization -----------------------------------------------

# withhold the last 253 trading days
Ra_training<-head(Ra,-253)
Rb_training<-head(Rb,-253)

head(Ra)
tail(Ra)
# use the last 253 trading days for testing
Ra_testing<-tail(Ra,253)
Rb_testing<-tail(Rb,253)

#optimize the MV (Markowitz 1950s) portfolio weights based on training
table.AnnualizedReturns(Rb_training)
mar<-mean(Rb_training) #we need daily minimum acceptable return

require(PortfolioAnalytics)
require(ROI) # make sure to install it
require(ROI.plugin.quadprog)  # make sure to install it
pspec<-portfolio.spec(assets=colnames(Ra_training))
pspec<-add.objective(portfolio=pspec,type="risk",name='StdDev')
pspec<-add.constraint(portfolio=pspec,type="full_investment")
pspec<-add.constraint(portfolio=pspec,type="return",return_target=mar)
#pspec <- add.constraint(portfolio = pspec, type = "box", min = 0, max = 1) # No short-selling


#optimize portfolio
opt_p<-optimize.portfolio(R=Ra_training,portfolio=pspec,optimize_method = 'ROI')

#extract weights (negative weights means shorting)
opt_w<-opt_p$weights


# View the optimal portfolio weights
opt_weights <- extractWeights(opt_portfolio)

#apply weights to test returns
Rp<-Rb_testing # easier to apply the existing structure
#define new column that is the dot product of the two vectors
Rp$ptf<-Ra_testing %*% opt_w

#check
head(Rp)
tail(Rp)

#Compare basic metrics
table.AnnualizedReturns(Ra_training,)
table.AnnualizedReturns(Rp)

# Chart Hypothetical Portfolio Returns ------------------------------------

chart.CumReturns(Rp,legend.loc = 'bottomright')

####Our optimized portfolio, constructed from 12 randomly selected stocks,
#achieved an annualized return that was approximately 80% lower than the 
#S&P 500. However, the portfolio exhibited similar risk levels as measured by standard deviation."
#                          SP500TR    ptf
#Annualized Return          0.1832 0.1012
#Annualized Std Dev         0.3443 0.3472
#Annualized Sharpe (Rf=0%)  0.5320 0.2914

