

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


select * from intermedia;
