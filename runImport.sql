-- a) Creacion de la tabla intermedia

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

-- b) Creacion de la tabla definitiva

-- Borrar tabla definitiva (por si quedo de run anterior)

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

-- c) Importacion de los datos

-- Import data

\copy intermedia from SalesbyRegion.csv header delimiter ',' csv;

CREATE OR REPLACE FUNCTION finsertaDefinitiva()
RETURNS TRIGGER AS 
$$
DECLARE
        month_format TEXT DEFAULT 'yy-Mon';
BEGIN
        INSERT INTO definitiva VALUES (TO_DATE(new.month, month_format), new.product_type, new.territory, new.sales_channel, new.customer_type, new.revenue, new.cost);
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER insertaDefinitiva
AFTER INSERT ON intermedia
FOR EACH ROW
EXECUTE PROCEDURE finsertaDefinitiva();

-- d) Calculo del Margen de venta promedio
