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
                AND customer_type = new.customer_type;
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
		RAISE NOTICE 'Argumentos no pueden ser null' USING ERRCODE = 'RR222';
		RETURN NULL;
	END IF;

	IF (n <= 0) THEN
		RAISE NOTICE 'La cantidad de meses anteriores debe ser mayor a 0' USING ERRCODE = 'PP111';
		RETURN NULL;
	END IF;

	-- Argumentos correctos! Calculo el margen de ventas promedio
	RETURN (SELECT (SUM(Revenue - Cost)::decimal(10,2)/COUNT(Sales_Date))::decimal(10,2)
	       FROM definitiva
               WHERE Sales_Date >= (fecha - (n * '1 month'::INTERVAL)) AND Sales_Date <= fecha);	

END
$$ 
LANGUAGE plpgsql;

-- Test MargenMovil
--SELECT MargenMovil(to_date('2012-11-01','YYYY-MM-DD'), 2);

-- e) Reporte de Ventas Historico

CREATE OR REPLACE FUNCTION validDates(n INT)
RETURNS TABLE(
   Sales_Date DATE,
   Sales_Channel TEXT,
   Customer_Type TEXT,
   Revenue FLOAT,
   Cost FLOAT
) 
AS $$

DECLARE
        baseYear INT := EXTRACT(YEAR FROM (SELECT MIN(definitiva.Sales_Date) FROM definitiva))::INT;
BEGIN
        IF (n IS NULL) THEN
                RAISE EXCEPTION 'No pueden pasarse una cantidad de anios NULL' USING ERRCODE = 'QQ333';
        END IF;
        RETURN QUERY SELECT definitiva.Sales_Date, definitiva.Sales_Channel, definitiva.Customer_Type, definitiva.Revenue, definitiva.Cost
                     FROM definitiva
                     WHERE EXTRACT(YEAR FROM definitiva.Sales_Date)::INT >= baseYear AND EXTRACT(YEAR FROM definitiva.Sales_Date)::INT < (baseYear + n)::INT;                 
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION report(n INT)
RETURNS TABLE(
   year INT,
   category TEXT,
   category_desc TEXT,
   revenue INT,
   cost INT,
   margin INT
) 
AS $$
BEGIN
        RETURN QUERY SELECT aux.year, aux.category, aux.category_desc, SUM(aux.revenue)::INT as revenue, SUM(aux.cost)::INT as cost, SUM(aux.margin)::INT as margin
                FROM
                        ((SELECT EXTRACT(YEAR FROM T1.Sales_Date)::INT as year, 'Sales Channel' AS Category, T1.Sales_Channel AS Category_Desc, T1.revenue::INT, T1.cost::INT, (T1.revenue-T1.cost)::INT AS margin
                        FROM validDates(n) AS T1)
                        
                        UNION
                        (SELECT EXTRACT(YEAR FROM T2.Sales_Date)::INT, 'Customer Type' AS Category, T2.Customer_Type AS Category_Desc, T2.revenue::INT, T2.cost::INT, (T2.revenue-T2.cost)::INT AS margin
                        FROM validDates(n) AS T2)
                ) AS AUX
                GROUP BY aux.year, aux.category, aux.category_desc
                ORDER BY aux.year, aux.category DESC, aux.category_desc ASC;               
END;
$$
LANGUAGE plpgsql;

DROP TYPE IF EXISTS definitiva_lens CASCADE;
CREATE TYPE definitiva_lens AS (year_len INT, cat_len INT, rev_len INT, cost_len INT, margin_len INT);

CREATE OR REPLACE FUNCTION make_report_line(year TEXT, category TEXT, revenue TEXT, cost TEXT, margin TEXT, lens definitiva_lens)
RETURNS TEXT
AS $$
DECLARE
        separator TEXT DEFAULT ' ';
BEGIN
        IF (year IS NULL) THEN
                year := '';
        END IF;
        IF (category IS NULL) THEN
                category := '';
        END IF;
        IF (revenue IS NULL) THEN
                revenue := '';
        END IF;
        IF (cost IS NULL) THEN
                cost := '';
        END IF;
        IF (margin IS NULL) THEN
                margin := '';
        END IF;
        RETURN (rpad(year, lens.year_len, separator) || separator 
                || rpad(category, lens.cat_len, separator) || separator 
                || rpad(revenue, lens.rev_len, separator) || separator 
                || rpad(cost, lens.cost_len, separator) || separator
                || rpad(margin, lens.margin_len, separator));               
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ReporteVenta(n INT)
RETURNS void
AS $$
DECLARE 
        separator TEXT DEFAULT ' ';
        cat_separator TEXT DEFAULT ': ';
        records CURSOR FOR
                SELECT * FROM report(n);
        record RECORD;
        title TEXT DEFAULT 'HISTORIC SALES REPORT';
        prev_year INT DEFAULT NULL;
        curr_year TEXT;
        total_revenue INT DEFAULT 0;
        total_cost INT DEFAULT 0;
        total_margin INT DEFAULT 0;
        lens definitiva_lens;
BEGIN
        SELECT MAX(LENGTH(report.year::TEXT)) AS year_len, 
                        MAX((LENGTH(report.category)+LENGTH(cat_separator)+LENGTH(report.category_desc))) AS cat_len
        INTO lens.year_len, lens.cat_len
        FROM report(n) AS report;
        SELECT MAX(revenue) as revenue, MAX(cost) as cost, MAX(margin) as margin
        INTO lens.rev_len, lens.cost_len, lens.margin_len
        FROM
                (SELECT LENGTH(SUM(revenue)::TEXT) as revenue, LENGTH(SUM(cost)::TEXT) as cost, LENGTH(SUM(revenue-cost)::TEXT) as margin
                FROM definitiva
                GROUP BY EXTRACT(YEAR FROM Sales_Date)) as len_by_year;
        PERFORM DBMS_OUTPUT.DISABLE();
        PERFORM DBMS_OUTPUT.ENABLE();
        PERFORM DBMS_OUTPUT.SERVEROUTPUT ('t');
        OPEN records;
        LOOP
                FETCH records INTO record;
                EXIT WHEN NOT FOUND;
                IF (prev_year IS NULL OR prev_year <> record.year) THEN
                        IF (prev_year IS NOT NULL) THEN
                                PERFORM DBMS_OUTPUT.PUT_LINE (make_report_line('', 'Total:', total_revenue::TEXT, total_cost::TEXT, total_margin::TEXT, lens));
                        ELSE
                                PERFORM DBMS_OUTPUT.PUT_LINE (title);
                                PERFORM DBMS_OUTPUT.PUT_LINE (make_report_line('YEAR', 'CATEGORY', 'REVENUE', 'COST', 'MARGIN', lens));
                        END IF;
                        SELECT SUM(revenue) as revenue, SUM(cost) as cost, SUM(revenue-cost) as margin
                                INTO total_revenue, total_cost, total_margin
                                FROM definitiva
                                WHERE EXTRACT(YEAR FROM Sales_Date) = record.year;
                        curr_year := record.year::TEXT;
                        prev_year := record.year;
                ELSE
                        curr_year := rpad('', LENGTH(record.year::TEXT), ' ');
                END IF;
                PERFORM DBMS_OUTPUT.PUT_LINE (make_report_line(curr_year, record.category || ': ' || separator || record.category_desc, record.revenue::TEXT, record.cost::TEXT, record.margin::TEXT, lens));
        END LOOP;
        
        CLOSE records;
        PERFORM DBMS_OUTPUT.PUT_LINE (make_report_line('', 'Total:', total_revenue::TEXT, total_cost::TEXT, total_margin::TEXT, lens));
END;
$$ LANGUAGE plpgsql;


--Test ReporteVenta
--
-- SELECT * FROM report(2);