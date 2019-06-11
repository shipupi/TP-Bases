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

\copy intermedia from SalesbyRegion.csv header delimiter ',' csv;

CREATE OR REPLACE FUNCTION finsertaDefinitiva()
RETURNS TRIGGER AS 
$$
DECLARE
        month_format TEXT DEFAULT 'yy-Mon'; 
BEGIN
        INSERT INTO definitiva VALUES (TO_DATE(new.month, month_format), new.product_type, new.territory, new.sales_channel, new.customer_type, new.revenue, new.cost);
        RETURN new;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER insertaDefinitiva
AFTER INSERT ON intermedia
FOR EACH ROW
EXECUTE PROCEDURE finsertaDefinitiva();

-- d) Calculo del Margen de venta promedio

CREATE OR REPLACE FUNCTION MargenMovil(fecha DATE, n INT)
RETURNS definitiva.Revenue%TYPE;
AS $$
DECLARE 
	sum definitiva.Revenue%TYPE;
	count INT;
	auxiMargen definitiva.Revenue%TYPE;
	myCursor CURSOR FOR 
		SELECT Sales_Date, Revenue - Cost 
		FROM definitiva
		WHEN Sales_Date >= (fecha - (n * '1 month'::INTERVAL)) AND Sales_Date <= fecha;

BEGIN
	sum := 0;
	count := 0;

	-- VALIDACIONES: Raise exception si alguno de los argumentos es invalido
	IF (fecha IS NULL OR n IS NULL) THEN
		Raise exception 'Argumentos no pueden ser null' USING ERRCODE = 'RR222'
	END IF

	IF (n <= 0) THEN
		Raise exception 'La cantidad de meses anteriores debe ser mayor a 0' USING ERRCODE = 'PP111';
	END IF

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
	IF (count == 0) THEN
		RETURN 0.0;
	END IF;

	-- Return the average
	RETURN sum/count;	
END;
$$ LANGUAGE plpgsql

SELECT EXTRACT(YEAR FROM sales_date)::INT FROM definitiva
GROUP BY EXTRACT(YEAR FROM sales_date)
ORDER BY EXTRACT(YEAR FROM sales_date) ASC

DO $$BEGIN
        PERFORM DBMS_OUTPUT.DISABLE();
        PERFORM DBMS_OUTPUT.ENABLE();
        PERFORM DBMS_OUTPUT.SERVEROUTPUT ('t');
        PERFORM DBMS_OUTPUT.PUT_LINE ('HISTORIC SALES REPORT');
        PERFORM DBMS_OUTPUT.PUT_LINE ('Hola');
END; $$

SELECT sales_date, SUM(revenue) as revenue, SUM(cost) as cost FROM definitiva 
GROUP BY sales_date;

CREATE OR REPLACE FUNCTION output_report(title TEXT)
RETURNS void
AS $$
DECLARE records
        CURSOR FOR
                SELECT sales_date, SUM(revenue) as revenue, SUM(cost) as cost 
                FROM definitiva 
                GROUP BY sales_date;
        record RECORD;
BEGIN
        PERFORM DBMS_OUTPUT.DISABLE();
        PERFORM DBMS_OUTPUT.ENABLE();
        PERFORM DBMS_OUTPUT.SERVEROUTPUT ('t');
        PERFORM DBMS_OUTPUT.PUT_LINE ('HISTORIC SALES REPORT');
        OPEN curse;
        LOOP
                FETCH records INTO record;
                EXIT WHEN NOT FOUND;
                PERFORM DBMS_OUTPUT.PUT_LINE (record.revenue || ' , ' || record.cost);
        END LOOP;
        CLOSE curse;
END;
$$ LANGUAGE plpgsql;

SELECT output_report('HISTORIC SALES REPORT')

SELECT * FROM definitiva;

DO $$
DECLARE
	rta definitiva.Revenue%TYPE
BEGIN
	rta := MargenMovil(TO_DATE('2012-11-01', 'YYYY-MM-DD'), 3);
	raise notice '%', rta;
EXCEPTION
	WHEN SQLSTATE 'PP111' THEN
		raise notice '% %', SQLSTATE, SQLERRM;
END