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