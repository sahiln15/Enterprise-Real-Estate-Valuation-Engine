-- Clean up any old tables before starting
DROP TABLE IF EXISTS Staging_Properties;
DROP TABLE IF EXISTS Fact_Properties;
DROP TABLE IF EXISTS Dim_Neighborhoods;
DROP TABLE IF EXISTS Dim_Quality_Tiers;

-- 1. CREATE DIMENSION TABLES
CREATE TABLE Dim_Neighborhoods (
    Neighborhood_ID SERIAL PRIMARY KEY,
    Neighborhood_Code VARCHAR(50) UNIQUE,
    Zoning_Classification VARCHAR(50)
);

CREATE TABLE Dim_Quality_Tiers (
    Quality_Score INT PRIMARY KEY,
    Quality_Tier_Label VARCHAR(50)
);

-- 2. CREATE MAIN FACT TABLE
CREATE TABLE Fact_Properties (
    Property_ID SERIAL PRIMARY KEY,
    Neighborhood_Code VARCHAR(50),
    Year_Built INT,
    Year_Remodelled INT,
    Overall_Quality INT,
    Overall_Condition INT,
    Total_Living_SqFt DECIMAL(10,2),
    Price_Per_SqFt DECIMAL(10,2),
    Sale_Price DECIMAL(12,2),
    FOREIGN KEY (Overall_Quality) REFERENCES Dim_Quality_Tiers(Quality_Score)
);

-- 3. FILL THE QUALITY LOOKUP METADATA
INSERT INTO Dim_Quality_Tiers (Quality_Score, Quality_Tier_Label) VALUES
(10, 'Ultra-Luxury Custom'),
(9, 'Luxury Premium'),
(8, 'High-End Executive'),
(7, 'Above Average Modern'),
(6, 'Standard Builder Grade'),
(5, 'Average / Typical'),
(4, 'Below Average'),
(3, 'Fair / Needs Work'),
(2, 'Poor / Severely Dated'),
(1, 'Salvage Condition');

-- 4. CREATE STAGING TABLE FOR THE RAW CSV DATA
-- Making everything TEXT to avoid formatting errors during import
CREATE TABLE Staging_Properties (
    Id TEXT, MSSubClass TEXT, MSZoning TEXT, LotFrontage TEXT, LotArea TEXT, Street TEXT, 
    Alley TEXT, LotShape TEXT, LandContour TEXT, Utilities TEXT, LotConfig TEXT, LandSlope TEXT, 
    Neighborhood TEXT, Condition1 TEXT, Condition2 TEXT, BldgType TEXT, HouseStyle TEXT, 
    OverallQual TEXT, OverallCond TEXT, YearBuilt TEXT, YearRemodAdd TEXT, RoofStyle TEXT, 
    RoofMatl TEXT, Exterior1st TEXT, Exterior2nd TEXT, MasVnrType TEXT, MasVnrArea TEXT, 
    ExterQual TEXT, ExterCond TEXT, Foundation TEXT, BsmtQual TEXT, BsmtCond TEXT, 
    BsmtExposure TEXT, BsmtFinType1 TEXT, BsmtFinSF1 TEXT, BsmtFinType2 TEXT, BsmtFinSF2 TEXT, 
    BsmtUnfSF TEXT, TotalBsmtSF TEXT, Heating TEXT, HeatingQC TEXT, CentralAir TEXT, 
    Electrical TEXT, "1stFlrSF" TEXT, "2ndFlrSF" TEXT, LowQualFinSF TEXT, GrLivArea TEXT, 
    BsmtFullBath TEXT, BsmtHalfBath TEXT, FullBath TEXT, HalfBath TEXT, BedroomAbvGr TEXT, 
    KitchenAbvGr TEXT, KitchenQual TEXT, TotRmsAbvGrd TEXT, Functional TEXT, Fireplaces TEXT, 
    FireplaceQu TEXT, GarageType TEXT, GarageYrBlt TEXT, GarageFinish TEXT, GarageCars TEXT, 
    GarageArea TEXT, GarageQual TEXT, GarageCond TEXT, PavedDrive TEXT, WoodDeckSF TEXT, 
    OpenPorchSF TEXT, EnclosedPorch TEXT, "3SsnPorch" TEXT, ScreenPorch TEXT, PoolArea TEXT, 
    PoolQC TEXT, Fence TEXT, MiscFeature TEXT, MiscVal TEXT, MoSold TEXT, YrSold TEXT, 
    SaleType TEXT, SaleCondition TEXT, SalePrice TEXT, Total_SqFt TEXT, Price_Per_SqFt TEXT
);

-- 5. LOAD CLEANED PYTHON CSV INTO STAGING
-- Generic relative name used for safety on GitHub
COPY Staging_Properties 
FROM 'Clean_Property_Data.csv' 
WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"');

-- 6. ETL TRANSFERS (MOVING DATA TO CORE TABLES)
-- Pulling out unique neighborhood codes
INSERT INTO Dim_Neighborhoods (Neighborhood_Code, Zoning_Classification)
SELECT DISTINCT Neighborhood, MSZoning 
FROM Staging_Properties
ON CONFLICT (Neighborhood_Code) DO NOTHING;

-- Moving data into the Fact table and casting data types properly
INSERT INTO Fact_Properties (
    Neighborhood_Code, Year_Built, Year_Remodelled, Overall_Quality, 
    Overall_Condition, Total_Living_SqFt, Price_Per_SqFt, Sale_Price
)
SELECT 
    Neighborhood, 
    NULLIF(YearBuilt, '')::INT, 
    NULLIF(YearRemodAdd, '')::INT, 
    NULLIF(OverallQual, '')::INT, 
    NULLIF(OverallCond, '')::INT, 
    NULLIF(Total_SqFt, '')::DECIMAL(10,2), 
    NULLIF(Price_Per_SqFt, '')::DECIMAL(10,2), 
    NULLIF(SalePrice, '')::DECIMAL(12,2)
FROM Staging_Properties;

-- Drop the staging table to keep the database clean
DROP TABLE Staging_Properties;

-- Quick check to verify all 1460 rows loaded successfully
SELECT COUNT(*) FROM Fact_Properties;

-- 7. ADVANCED DATA ANALYSIS QUERY
-- Ranking properties and calculating running averages using window functions
SELECT 
    Property_ID,
    Neighborhood_Code,
    Total_Living_SqFt,
    Sale_Price,
    Price_Per_SqFt,
    -- Rank houses inside each neighborhood by price per square foot
    DENSE_RANK() OVER(
        PARTITION BY Neighborhood_Code 
        ORDER BY Price_Per_SqFt DESC
    ) as neighborhood_value_rank,
    -- Find the average price per square foot for that specific neighborhood
    ROUND(
        AVG(Price_Per_SqFt) OVER(PARTITION BY Neighborhood_Code), 2
    ) as neighborhood_avg_price_per_sqft
FROM Fact_Properties
WHERE Overall_Quality >= 7
ORDER BY Neighborhood_Code ASC, neighborhood_value_rank ASC;
