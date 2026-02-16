/* =========================================================================================
   CUSTOMER FINANCIAL BEHAVIOR, REVENUE CONTRIBUTION & FRAUD RISK ANALYTICS SYSTEM
   Enterprise-Grade SQL Implementation with Data Modeling, KPI Engineering & Advanced Insights
   ========================================================================================= */



/* =========================================================================================
   DATA DISCOVERY & STRUCTURAL VALIDATION
   Objective: Inspect raw dataset integrity before normalization.
   ========================================================================================= */

-- What does the raw transactional dataset look like?
SELECT * FROM bank_data;

-- How many unique customers (Account Numbers) exist?
SELECT COUNT(DISTINCT Account_Number) AS UniqueAccounts
FROM bank_data;

-- What is the schema structure of the imported raw table?
EXEC sp_help 'bank_data';



/* =========================================================================================
   DATA NORMALIZATION & RELATIONAL MODEL CREATION
   Objective: Split raw dataset into Dimension (Customers) and Fact (Transactions).
   ========================================================================================= */

--------------------------------------------
-- Creating Customer Dimension Table
--------------------------------------------

CREATE TABLE Bank_Customers
(
    AccountNumber VARCHAR(50) NOT NULL PRIMARY KEY,
    CustomerAge INT NOT NULL,
    CustomerGender VARCHAR(20) NOT NULL,
    CustomerOccupation VARCHAR(150) NOT NULL,
    CustomerIncome DECIMAL(18,2) NOT NULL,
    City VARCHAR(100) NOT NULL
);

-- Insert unique customers (Fix #1: DISTINCT added for safety)
INSERT INTO Bank_Customers
SELECT DISTINCT
    Account_Number,
    CAST(Customer_Age AS INT),
    Customer_Gender,
    Customer_Occupation,
    CAST(Customer_Income AS DECIMAL(18,2)),
    City
FROM bank_data;



select * from Bank_Customers;

--------------------------------------------
-- Creating Transaction Fact Table
--------------------------------------------

CREATE TABLE Bank_Transactions
(
    TransactionID VARCHAR(50) NOT NULL PRIMARY KEY,
    AccountNumber VARCHAR(50) NOT NULL,
    TransactionDate DATETIME NOT NULL,
    TransactionAmount DECIMAL(18,2) NOT NULL,
    TransactionType VARCHAR(50) NOT NULL,
    Category VARCHAR(100) NOT NULL,
    PaymentMethod VARCHAR(50) NOT NULL,
    TransactionStatus VARCHAR(20) NOT NULL,
    FraudFlag VARCHAR(10) NOT NULL,

    CONSTRAINT FK_Transactions_Customers
    FOREIGN KEY (AccountNumber)
    REFERENCES Bank_Customers(AccountNumber)
);

INSERT INTO Bank_Transactions
SELECT
    Transaction_ID,
    Account_Number,
    CAST(Transaction_Date AS DATETIME),
    CAST(Transaction_Amount AS DECIMAL(18,2)),
    Transaction_Type,
    Category,
    Payment_Method,
    Transaction_Status,
    Fraud_Flag
FROM bank_data;


select * from Bank_Transactions;


/* =========================================================================================
   ANALYTICAL CONSOLIDATION LAYER
   Objective: Create unified analytical table for easier reporting.
   ========================================================================================= */

-- How can we combine customer and transaction attributes for deep analysis?

SELECT
    t.TransactionID,
    t.AccountNumber,
    t.TransactionDate,
    t.TransactionAmount,
    t.TransactionType,
    t.Category,
    t.PaymentMethod,
    t.TransactionStatus,
    t.FraudFlag,
    c.CustomerAge,
    c.CustomerGender,
    c.CustomerOccupation,
    c.CustomerIncome,
    c.City
INTO Bank_Details
FROM Bank_Transactions t
INNER JOIN Bank_Customers c
ON t.AccountNumber = c.AccountNumber;


select * from Bank_Details;



/* =========================================================================================
   PERFORMANCE OPTIMIZATION STRATEGY
   Objective: Improve query performance using indexing.
   ========================================================================================= */

-- Which customers earn higher income? (Indexing income column)
CREATE NONCLUSTERED INDEX IX_BankCustomers_Income
ON Bank_Customers(CustomerIncome);

-- How can we speed up time-series analysis? (Indexing date column)
CREATE NONCLUSTERED INDEX IX_BankTransactions_Date
ON Bank_Transactions(TransactionDate);



/* =========================================================================================
   EXECUTIVE KPI VIEWS (Reusable Business Summaries)
   Objective: Create summarized reporting layers for management dashboards.
   ========================================================================================= */

--------------------------------------------
-- Customer Overview KPI
--------------------------------------------

CREATE OR ALTER VIEW vw_Customer_KPI AS
SELECT
    COUNT(*) AS TotalCustomers,
    AVG(CustomerAge) AS AvgCustomerAge,
    AVG(CustomerIncome) AS AvgCustomerIncome,
    SUM(CustomerIncome) AS TotalCustomerIncome,
    COUNT(DISTINCT City) AS TotalCities
FROM Bank_Customers;


select * from vw_Customer_KPI





--------------------------------------------
-- Transaction Performance KPI (Success Only)
--------------------------------------------

CREATE OR ALTER VIEW vw_Transaction_KPI AS
SELECT
    COUNT(*) AS TotalSuccessfulTransactions,
    SUM(TransactionAmount) AS TotalTransactionVolume,
    AVG(TransactionAmount) AS AvgTransactionAmount
FROM Bank_Transactions
WHERE TransactionStatus = 'Success';


select * from vw_Transaction_KPI


--------------------------------------------
-- Fraud Monitoring KPI
--------------------------------------------

CREATE OR ALTER VIEW vw_Fraud_KPI AS
SELECT
    COUNT(*) AS TotalTransactions,
    SUM(CASE WHEN FraudFlag = 'Yes' THEN 1 ELSE 0 END) AS FraudTransactions,
    CAST(
        SUM(CASE WHEN FraudFlag = 'Yes' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*) AS DECIMAL(5,2)
    ) AS FraudRatePercentage
FROM Bank_Transactions;


select * from vw_Fraud_KPI


/* =========================================================================================
   CORE CUSTOMER ANALYTICS
   Objective: Understand demographic and income distribution patterns.
   ========================================================================================= */

-- What is the average age and income of customers?
SELECT
    AVG(CustomerAge) AS AvgAge,
    AVG(CustomerIncome) AS AvgIncome
FROM Bank_Customers;


-- How are customers distributed across cities?
SELECT City, COUNT(*) AS TotalCustomers
FROM Bank_Customers
GROUP BY City
ORDER BY TotalCustomers DESC;


-- What are the most common occupations among customers?
SELECT CustomerOccupation, COUNT(*) AS TotalCustomers
FROM Bank_Customers
GROUP BY CustomerOccupation
ORDER BY TotalCustomers DESC;


-- Which top 3 occupations dominate the customer base?
WITH top_occu AS (
    SELECT CustomerOccupation, COUNT(AccountNumber) AS No_of_Customers
    FROM Bank_Customers
    GROUP BY CustomerOccupation
)
SELECT CustomerOccupation, No_of_Customers, rnk
FROM (
    SELECT *,
           DENSE_RANK() OVER (ORDER BY No_of_Customers DESC) AS rnk
    FROM top_occu
) t
WHERE rnk <= 3;


-- How are customers segmented by income category?
SELECT
    CASE
        WHEN CustomerIncome < 50000 THEN 'Low Income'
        WHEN CustomerIncome BETWEEN 50000 AND 100000 THEN 'Middle Income'
        ELSE 'High Income'
    END AS IncomeGroup,
    COUNT(*) AS CustomerCount
FROM Bank_Customers
GROUP BY
    CASE
        WHEN CustomerIncome < 50000 THEN 'Low Income'
        WHEN CustomerIncome BETWEEN 50000 AND 100000 THEN 'Middle Income'
        ELSE 'High Income'
    END
ORDER BY CustomerCount DESC;



/* =========================================================================================
   TRANSACTION PERFORMANCE ANALYTICS
   Objective: Measure financial activity and revenue behavior.
   ========================================================================================= */

-- What is the average transaction value per customer?
SELECT
    AccountNumber,
    AVG(TransactionAmount) AS AvgTransactionAmount
FROM Bank_Transactions
WHERE TransactionStatus = 'Success'
GROUP BY AccountNumber
ORDER BY AvgTransactionAmount DESC;


-- Who are the top 10 highest spending customers?
WITH top_10_Customer AS (
    SELECT AccountNumber,
           SUM(TransactionAmount) AS Total_Transaction_Amount
    FROM Bank_Transactions
    WHERE TransactionStatus = 'Success'
    GROUP BY AccountNumber
)
SELECT *
FROM (
    SELECT *,
           DENSE_RANK() OVER (ORDER BY Total_Transaction_Amount DESC) AS Rank
    FROM top_10_Customer
) t
WHERE Rank <= 10;


-- What is the monthly revenue trend?
SELECT
    YEAR(TransactionDate) AS Year,
    MONTH(TransactionDate) AS Month,
    SUM(TransactionAmount) AS MonthlyTotal
FROM Bank_Transactions
WHERE TransactionStatus = 'Success'
GROUP BY YEAR(TransactionDate), MONTH(TransactionDate)
ORDER BY Year, Month;


-- Which payment methods are used most frequently?
WITH most_used_payment_method AS (
    SELECT PaymentMethod,
           COUNT(*) AS Used
    FROM Bank_Transactions
    WHERE TransactionStatus = 'Success'
    GROUP BY PaymentMethod
)
SELECT *,
       RANK() OVER (ORDER BY Used DESC) AS Rank
FROM most_used_payment_method;


-- What is the overall transaction success rate?
SELECT
    SUM(CASE WHEN TransactionStatus='Success' THEN 1 ELSE 0 END) * 100.0
    / COUNT(*) AS SuccessRatePercentage
FROM Bank_Transactions;



/* =========================================================================================
   FRAUD & RISK ANALYTICS
   Objective: Identify suspicious patterns and high-risk groups.
   ========================================================================================= */

--Which payment methods show the highest fraud occurrence?
SELECT
    PaymentMethod,
    COUNT(*) AS TotalTransactions,
    SUM(CASE WHEN FraudFlag='Yes' THEN 1 ELSE 0 END) AS FraudCount
FROM Bank_Transactions
GROUP BY PaymentMethod
ORDER BY FraudCount DESC;

-- Which age groups are more prone to fraud?
SELECT
    CASE
        WHEN CustomerAge BETWEEN 18 AND 30 THEN '18-30'
        WHEN CustomerAge BETWEEN 31 AND 45 THEN '31-45'
        WHEN CustomerAge BETWEEN 46 AND 60 THEN '46-60'
        ELSE '60+'
    END AS Age_Group,
    COUNT(*) AS TotalTransactions,
    SUM(CASE WHEN FraudFlag='Yes' THEN 1 ELSE 0 END) AS FraudCount
FROM Bank_Details
GROUP BY
    CASE
        WHEN CustomerAge BETWEEN 18 AND 30 THEN '18-30'
        WHEN CustomerAge BETWEEN 31 AND 45 THEN '31-45'
        WHEN CustomerAge BETWEEN 46 AND 60 THEN '46-60'
        ELSE '60+'
    END
ORDER BY FraudCount DESC;

-- Which customers show high-risk financial behavior?
WITH CustomerTotals AS (
    SELECT AccountNumber,
           SUM(TransactionAmount) AS TotalSpending,
           SUM(CASE WHEN FraudFlag='Yes' THEN 1 ELSE 0 END) AS Fraud_Count
    FROM Bank_Details
    GROUP BY AccountNumber
)
SELECT *
FROM CustomerTotals
WHERE Fraud_Count >= 1
AND TotalSpending >
(
    SELECT AVG(TotalSpending)
    FROM CustomerTotals
);



/* =========================================================================================
   ADVANCED FINANCIAL INSIGHTS
   Objective: Apply window functions and contribution analysis.
   ========================================================================================= */

-- Which customers spend more than 20% of their income?
SELECT
    AccountNumber,
    SUM(TransactionAmount) AS TotalSpending,
    MAX(CustomerIncome) AS CustomerIncome,
    SUM(TransactionAmount) * 100.0 / MAX(CustomerIncome) AS SpendingIncomeRatio
FROM Bank_Details
WHERE TransactionStatus='Success'
GROUP BY AccountNumber
HAVING SUM(TransactionAmount) > MAX(CustomerIncome) * 0.20;

-- How much revenue is contributed by the top 20% customers?
WITH CustomerRevenue AS (
    SELECT AccountNumber,
           SUM(TransactionAmount) AS Revenue
    FROM Bank_Details
    WHERE TransactionStatus='Success'
    GROUP BY AccountNumber
)
SELECT
    SUM(Revenue) AS Top20Revenue,
    SUM(Revenue) * 100.0 /
    (SELECT SUM(Revenue) FROM CustomerRevenue) AS ContributionPercentage
FROM (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY Revenue DESC) AS rn,
           COUNT(*) OVER () AS total_customers
    FROM CustomerRevenue
) t
WHERE rn <= 0.20 * total_customers;


-- What is the month-over-month revenue growth trend?
WITH Monthly_Trend AS (
    SELECT YEAR(TransactionDate) AS Year,
           MONTH(TransactionDate) AS Month,
           SUM(TransactionAmount) AS TotalTransactionAmount
    FROM Bank_Transactions
    WHERE TransactionStatus='Success'
    GROUP BY YEAR(TransactionDate), MONTH(TransactionDate)
)
SELECT *,
       LAG(TotalTransactionAmount,1,0)
       OVER (ORDER BY Year, Month) AS PreviousMonthAmount,
       TotalTransactionAmount -
       LAG(TotalTransactionAmount,1,0)
       OVER (ORDER BY Year, Month) AS Difference
FROM Monthly_Trend;



/* =========================================================================================
   REUSABLE BUSINESS STORED PROCEDURE
   Objective: Create reusable logic for top customer retrieval.
   ========================================================================================= */

CREATE OR ALTER PROCEDURE GetTopCustomers
AS
BEGIN
    SELECT TOP 10
        AccountNumber,
        SUM(TransactionAmount) AS TotalSpending
    FROM Bank_Transactions
    WHERE TransactionStatus='Success'
    GROUP BY AccountNumber
    ORDER BY TotalSpending DESC;
END;


Exec GetTopCustomers



/* 
   Note: Section structuring and presentation formatting were assisted by AI tools.
   All data modeling, SQL queries, analytical logic, and implementation were completed by the author.
*/


