

-- Borrar tabla intermedia (por si quedo de run anterior)

DROP TABLE IF EXISTS intermedia;

-- Crear tabla intermedia
CREATE TABLE intermedia(
	Quarter TEXT NOT NULL,
	Month TEXT NOT NULL,
	Week TEXT NOT NULL,
	Product_Type TEXT NOT NULL,
	Territory TEXT NOT NULL,
	Sales_Channel TEXT NOT NULL,
	Customer_Type TEXT NOT NULL,
	Revenue FLOAT,
	Cost FLOAT
);

-- Import data

\copy intermedia from SalesbyRegion.csv header delimiter ',' csv;

-- Borrar tabla defiitiva (por si quedo de run anterior)

DROP TABLE IF EXISTS intermedia;

-- Crear tabla definitiva

CREATE TABLE definitiva(
        Sales_Date DATE NOT NULL,
        Product_Type TEXT NOT NULL,
        Territory TEXT NOT NULL,
        Sales_Channel TEXT NOT NULL,
        Customer_Type TEXT NOT NULL,
        Revenue FLOAT,
        Cost FLOAT
);

INSERT INTO definitiva
SELECT TO_DATE(month, 'yy-Mon') as sales_date, product_type, territory, sales_channel, customer_type, SUM(revenue) as revenue, cost
FROM intermedia
GROUP BY month, product_type, territory, sales_channel, customer_type, cost;

-- Seguir aca abajo
