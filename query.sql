--Elizabeth Feliu - D326 Adv Data Mng

--Creating first and last name concatenation
CREATE OR REPLACE FUNCTION get_full_name(p_first_name VARCHAR, p_last_name VARCHAR)
RETURNS VARCHAR AS $$
BEGIN
RETURN p_first_name || ' ' || p_last_name;
END;
$$ LANGUAGE plpgsql;

--Creating detailed table
DROP TABLE IF EXISTS detailed_payment_report;
CREATE TABLE detailed_payment_report (
    postal_code VARCHAR(10),
    customer_name VARCHAR(100),
    amount DECIMAL (5, 2),
    payment_date DATE
);
--Crating summary table
DROP TABLE IF EXISTS summary_payment_report;
CREATE TABLE summary_payment_report (
    postal_code VARCHAR(10),
    total_amount DECIMAL(10, 2),
    number_of_payments INT
);

--verifying tables created
SELECT * FROM detailed_payment_report;
SELECT * FROM summary_payment_report;

--Inserting raw data into detailed table section
INSERT INTO detailed_payment_report (postal_code, customer_name, amount, payment_date)
    SELECT
        a.postal_code,
        get_full_name(c.first_name, c.last_name),
        p.amount,
        p.payment_date
    FROM payment p
    JOIN customer c ON p.customer_id = c.customer_id
    JOIN address a ON c.address_id = a.address_id;

--verifying data inserted
SELECT * FROM detailed_payment_report;

--Populating summary table
INSERT INTO summary_payment_report (postal_code, total_amount, number_of_payments)
    SELECT
        postal_code,
        SUM(amount) AS total_amount,
        COUNT(*) AS number_payments
    FROM
        detailed_payment_report
    GROUP BY
        postal_code;

SELECT * FROM summary_payment_report;

--Trigger function - when new rows are added to detailed table then trigger function
--will update data on summary table
CREATE OR REPLACE FUNCTION refresh_summary_table()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Delete existing records from the summary table
  DELETE FROM summary_payment_report;
 
  -- Repopulate the summary table based on the current state of the detailed table
  INSERT INTO summary_payment_report (postal_code, number_of_payments, total_amount)
  SELECT
    postal_code,
    COUNT(*) AS number_of_payments,
    SUM(amount) AS total_amount
  FROM
    detailed_payment_report
  GROUP BY
    postal_code;
   
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_summary_after_insert
AFTER INSERT
ON detailed_payment_report
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_summary_table();

--Procedure to refresh both detailed and summary tables
CREATE OR REPLACE PROCEDURE refresh_report_data()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Deleting existing tables
    DELETE FROM detailed_payment_report;
	DELETE FROM summary_payment_report;
   
    -- Repopulating the detailed_payment_report table
    INSERT INTO detailed_payment_report (postal_code, customer_name, amount, payment_date)
    SELECT
        a.postal_code,
        get_full_name(c.first_name, c.last_name),
        p.amount,
        p.payment_date
    FROM
        payment p
    JOIN customer c ON p.customer_id = c.customer_id
    JOIN address a ON c.address_id = a.address_id;
   
    -- Repopulating the summary_payment_report table based on the new detailed table
    INSERT INTO summary_payment_report (postal_code, total_amount, number_of_payments)
    SELECT
        postal_code,
	SUM(amount) AS total_amount,
        COUNT(*) AS number_of_payments
    FROM
        detailed_payment_report
    GROUP BY
        postal_code;
       
END;
$$;

SELECT * FROM summary_payment_report;

--test value
INSERT INTO detailed_payment_report VALUES (25414, 'Liz Feliu', 10.99, '2024-03-17');

--verifying new row in detailed table
SELECT * FROM detailed_payment_report WHERE postal_code = '25414';

--verifying trigger updated data in summary
SELECT * FROM summary_payment_report WHERE postal_code = '25414';

--calling refresh procedure
CALL refresh_report_data();

--verifying refresh / 25414 no longer in detailed table
SELECT * FROM detailed_payment_report WHERE postal_code ='25414';
SELECT * FROM summary_payment_report WHERE postal_code ='25414';
SELECT * FROM detailed_payment_report;
SELECT * FROM summary_payment_report;