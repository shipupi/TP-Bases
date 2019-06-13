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
        Cost FLOAT,
        CONSTRAINT PK_Definitiva PRIMARY KEY (Sales_Date, Product_Type, Territory, Sales_Channel, Customer_Type)
);

-- c) Importacion de los datos

-- Import data

CREATE OR REPLACE FUNCTION finsertaDefinitiva()
RETURNS TRIGGER AS 
$$
DECLARE
        month_format TEXT DEFAULT 'yy-Mon'; 
        month DATE DEFAULT TO_DATE(new.month, month_format);
BEGIN
        UPDATE definitiva 
        SET revenue = (revenue + new.revenue), cost = (cost + new.cost) 
        WHERE sales_date = month 
                AND product_type = new.product_type 
                AND territory = new.territory 
                AND sales_channel = new.sales_channel 
                AND customer_type = new.customer_type 
                AND revenue = new.revenue;
        IF NOT FOUND THEN
                INSERT INTO definitiva 
                VALUES (month, new.product_type, new.territory, new.sales_channel, new.customer_type, new.revenue, new.cost);
        END IF;
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
BEGIN
	-- VALIDACIONES: Raise exception si alguno de los argumentos es invalido
	IF (fecha IS NULL OR n IS NULL) THEN
		RAISE EXCEPTION 'Argumentos no pueden ser null' USING ERRCODE = 'RR222';
	END IF;

	IF (n <= 0) THEN
		RAISE EXCEPTION 'La cantidad de meses anteriores debe ser mayor a 0' USING ERRCODE = 'PP111';
	END IF;

	-- Argumentos correctos! Calculo el margen de ventas promedio
	RETURN (SELECT SUM(Revenue - Cost)/COUNT(*)
	       FROM definitiva
               WHERE Sales_Date >= (fecha - (n * '1 month'::INTERVAL)) AND Sales_Date <= fecha);	

END
$$ 
LANGUAGE plpgsql;

-- Test MargenMovil
-- SELECT MargenMovil(to_date('2012-11-01','YYYY-MM-DD'), 2);

-- e) Reporte de Ventas Historico

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

CREATE OR REPLACE FUNCTION ReporteVenta(n INT)
RETURNS void
AS $$
DECLARE 
        records CURSOR FOR
                SELECT aux.year, aux.category, aux.category_desc, SUM(aux.revenue)::INT as revenue, SUM(aux.cost)::INT as cost, SUM(aux.margin)::INT as margin
                FROM
                        ((SELECT EXTRACT(YEAR FROM T1.Sales_Date)::INT as year, 'Sales Channel' AS Category, T1.Sales_Channel AS Category_Desc, T1.revenue::INT, T1.cost::INT, (T1.revenue-T1.cost)::INT AS margin
                        FROM validDates(n) AS T1)
                        
                        UNION
                        (SELECT EXTRACT(YEAR FROM T2.Sales_Date)::INT, 'Customer Type' AS Category, T2.Customer_Type AS Category_Desc, T2.revenue::INT, T2.cost::INT, (T2.revenue-T2.cost)::INT AS margin
                        FROM validDates(n) AS T2)
                ) AS AUX
                GROUP BY aux.year, aux.category, aux.category_desc
                ORDER BY aux.year, aux.category DESC, aux.category_desc DESC; 
        record RECORD;
        title TEXT DEFAULT 'HISTORIC SALES REPORT';
        separator TEXT DEFAULT ' ';
        prev_year INT DEFAULT NULL;
        curr_year TEXT;
        total_revenue INT DEFAULT 0;
        total_cost INT DEFAULT 0;
        total_margin INT DEFAULT 0;
        category_len INT DEFAULT 35;
BEGIN
        PERFORM DBMS_OUTPUT.DISABLE();
        PERFORM DBMS_OUTPUT.ENABLE();
        PERFORM DBMS_OUTPUT.SERVEROUTPUT ('t');
        PERFORM DBMS_OUTPUT.PUT_LINE (title);
        PERFORM DBMS_OUTPUT.PUT_LINE ('YEAR' || separator || rpad('CATEGORY', category_len, ' ') || separator || 'REVENUE' || separator || 'COST' || separator || 'MARGIN');
        OPEN records;
        LOOP
                FETCH records INTO record;
                EXIT WHEN NOT FOUND;
                IF (prev_year IS NULL OR prev_year <> record.year) THEN
                        PERFORM DBMS_OUTPUT.PUT_LINE (rpad('', LENGTH(curr_year::TEXT), ' ') || separator || rpad('Total:', category_len, ' ') || separator || total_revenue || separator || total_cost || separator || total_margin);
                        total_revenue := 0;
                        total_cost := 0;
                        total_margin := 0;
                        curr_year := record.year::TEXT;
                        prev_year := record.year;
                ELSE
                        curr_year := rpad('', LENGTH(record.year::TEXT), ' ');
                END IF;
                total_revenue := total_revenue + record.revenue;
                total_cost := total_cost + record.cost;
                total_margin := total_margin + record.margin;
                PERFORM DBMS_OUTPUT.PUT_LINE (curr_year || separator || rpad(record.category || ': ' || separator || record.category_desc, category_len, ' ') || separator || record.revenue || separator || record.cost || separator || record.margin);
        END LOOP;
        CLOSE records;
        PERFORM DBMS_OUTPUT.PUT_LINE (rpad('', LENGTH(curr_year::TEXT), ' ') || separator || rpad('Total:', category_len, ' ') || separator || total_revenue || separator || total_cost || separator || total_margin);
        
END;
$$ LANGUAGE plpgsql;

--Test ReporteVenta
SELECT ReporteVenta(2);