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

DROP TABLE IF EXISTS definitiva;

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

CREATE OR REPLACE FUNCTION finsertaDefinitiva()
RETURNS TRIGGER AS 
$$
DECLARE
        month_format TEXT DEFAULT 'yy-Mon'; 
BEGIN
        INSERT INTO definitiva VALUES (TO_DATE(new.month, month_format), new.product_type, new.territory, new.sales_channel, new.customer_type, new.revenue, new.cost);
        RETURN NULL;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER insertaDefinitiva
AFTER INSERT ON intermedia
FOR EACH ROW
EXECUTE PROCEDURE finsertaDefinitiva();

\copy intermedia from SalesbyRegion.csv header delimiter ',' csv;


-- d) Calculo del Margen de venta promedio

CREATE OR REPLACE FUNCTION MargenMovil(fecha DATE, n INT)
RETURNS definitiva.Revenue%TYPE AS 
$$
DECLARE 
	sum definitiva.Revenue%TYPE;
	count INT;
	auxiMargen definitiva.Revenue%TYPE;
	myCursor CURSOR FOR 
		SELECT Revenue - Cost 
		FROM definitiva
		WHERE Sales_Date >= (fecha - (n * '1 month'::INTERVAL)) AND Sales_Date <= fecha;

BEGIN
	sum := 0.0;
	count := 0;

	-- VALIDACIONES: Raise exception si alguno de los argumentos es invalido
	IF (fecha IS NULL OR n IS NULL) THEN
		Raise exception 'Argumentos no pueden ser null' USING ERRCODE = 'RR222';
	END IF;

	IF (n <= 0) THEN
		Raise exception 'La cantidad de meses anteriores debe ser mayor a 0' USING ERRCODE = 'PP111';
	END IF;

	-- Argumentos correctos! Calculo el margen de ventas promedio
	OPEN myCursor;

	LOOP
		FETCH myCursor INTO auxiMargen;
		EXIT WHEN NOT FOUND;

		sum := sum + auxiMargen;
		count := count + 1;
	END LOOP;

	CLOSE myCursor;

	-- Me evita la excepcion de division por 0
	IF (count = 0) THEN
		RETURN 0.0;
	END IF;

	-- Return the average
	RETURN sum/count;	
END
$$ 
LANGUAGE plpgsql;


/*
DO $$
DECLARE
	rta definitiva.Revenue%TYPE;
BEGIN
	rta := MargenMovil(TO_DATE('2012-11-01', 'YYYY-MM-DD'), 3);
	raise notice '%', rta;
EXCEPTION
	WHEN SQLSTATE 'PP111' THEN
		raise notice '% %', SQLSTATE, SQLERRM;
END;
$$
*/

-- CREANDO LA TABLA PARA EL PUNTO E

DROP FUNCTION IF EXISTS ReporteVenta(integer);
DROP FUNCTION IF EXISTS validDates(integer);

CREATE OR REPLACE FUNCTION ReporteVenta(n INT) 
RETURNS TABLE (
        Year INT,
        Category TEXT,
        Revenue INT,
        Cost INT,
        Margin INT         
)
AS $$
      
BEGIN
        IF (n = 0) THEN
                Raise exception 'Cantidad de años debe ser mayor a 0' USING ERRCODE = 'RR000';
        END IF;
        
        RETURN QUERY SELECT 
                aux.year, aux.category, SUM(aux.revenue)::INT, SUM(aux.cost)::INT, SUM(aux.margin)::INT
            FROM 
                ((SELECT EXTRACT(YEAR FROM T1.Sales_Date)::INT as year, 'Sales Channel: ' || T1.Sales_Channel AS Category, T1.revenue::INT, T1.cost::INT, (T1.revenue-T1.cost)::INT AS margin
                  FROM validDates(n) AS T1)   
                     
                UNION        
                
                (SELECT EXTRACT(YEAR FROM T2.Sales_Date)::INT, 'Customer Type: ' || T2.Customer_Type AS Category, T2.revenue::INT, T2.cost::INT, (T2.revenue-T2.cost)::INT AS margin
                 FROM validDates(n) AS T2)
            ) AS AUX
            GROUP BY aux.year, aux.category
            ORDER BY aux.year, aux.category DESC; 
                                
END;
$$
LANGUAGE plpgsql;


-- AUXILIARY FUNCTION TO CREATE A TABLE WITH THE DATES TO ANALIZE
CREATE OR REPLACE FUNCTION validDates(n INT)
RETURNS TABLE(
   Sales_Date DATE,
   Sales_Channel TEXT,
   Customer_Type TEXT,
   Revenue FLOAT,
   COST FLOAT
) 
AS $$

DECLARE
        baseYear INT := EXTRACT(YEAR FROM (SELECT MIN(definitiva.Sales_Date) FROM definitiva))::INT;
BEGIN
        RETURN QUERY SELECT definitiva.Sales_Date, definitiva.Sales_Channel, definitiva.Customer_Type, definitiva.Revenue, definitiva.Cost
                     FROM definitiva
                     WHERE EXTRACT(YEAR FROM definitiva.Sales_Date)::INT >= baseYear AND EXTRACT(YEAR FROM definitiva.Sales_Date)::INT < (baseYear + n)::INT;                 
END;
$$
LANGUAGE plpgsql;

-- Con esto se llama
--SELECT * FROM ReporteVenta(1) AS rta;
