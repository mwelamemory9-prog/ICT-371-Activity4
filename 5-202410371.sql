-- Step 1: Create tables and insert initial records
DROP TABLE IF EXISTS tool_loans CASCADE;
DROP TABLE IF EXISTS tools CASCADE;

CREATE TABLE tools (
    tool_id SERIAL PRIMARY KEY,
    tool_name VARCHAR(100) NOT NULL,
    available_qty INT NOT NULL CHECK (available_qty >= 0)
);

CREATE TABLE tool_loans (
    loan_id SERIAL PRIMARY KEY,
    tool_id INT REFERENCES tools(tool_id),
    student_number VARCHAR(50) NOT NULL,
    quantity INT NOT NULL,
    status VARCHAR(20) NOT NULL
);

INSERT INTO tools (tool_name, available_qty) VALUES
('Digital Multimeter', 0),
('Torque Wrench', 2),
('Soldering Iron Kit', 10);

-- Step 2: IF ELSIF ELSE logic to report tool stock status
DO $$
DECLARE
    v_qty INT;
BEGIN
    SELECT available_qty INTO v_qty FROM tools WHERE tool_id = 2;
    IF v_qty = 0 THEN
        RAISE NOTICE 'Tool is UNAVAILABLE.';
    ELSIF v_qty <= 3 THEN
        RAISE NOTICE 'Tool is LOW ON STOCK (% units remaining).', v_qty;
    ELSE
        RAISE NOTICE 'Tool is READILY AVAILABLE (% units remaining).', v_qty;
    END IF;
END $$;

-- Step 3: WHILE loop and numeric FOR loop
DO $$
DECLARE
    v_rem INT := 1;
BEGIN
    -- WHILE loop for safety reminders
    WHILE v_rem <= 3 LOOP
        RAISE NOTICE 'Safety Reminder %: Wear safety glasses before operating power tools.', v_rem;
        v_rem := v_rem + 1;
    END LOOP;

    -- Numeric FOR loop for tool inspections
    FOR t IN 1..3 LOOP
        RAISE NOTICE 'Tool Inspection %: Calibration check completed.', t;
    END LOOP;
END $$;

-- Step 4: Create issue_tool procedure
CREATE OR REPLACE PROCEDURE issue_tool(
    p_tool_id INT,
    p_student_number VARCHAR,
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid loan quantity: %. Quantity must be greater than zero.', p_quantity;
    END IF;

    SELECT available_qty INTO v_stock FROM tools WHERE tool_id = p_tool_id;

    IF v_stock IS NULL THEN
        RAISE EXCEPTION 'Tool ID % does not exist.', p_tool_id;
    END IF;

    IF v_stock >= p_quantity THEN
        UPDATE tools 
        SET available_qty = available_qty - p_quantity 
        WHERE tool_id = p_tool_id;

        INSERT INTO tool_loans (tool_id, student_number, quantity, status)
        VALUES (p_tool_id, p_student_number, p_quantity, 'ISSUED');

        RAISE NOTICE 'Issued % unit(s) to student %.', p_quantity, p_student_number;
    ELSE
        RAISE NOTICE 'Loan failed for student %: Stock insufficient (Requested: %, Available: %).', p_student_number, p_quantity, v_stock;
    END IF;
END $$;

-- Step 5: Call issue_tool and query tables
CALL issue_tool(2, '20240101', 1); -- Valid loan
CALL issue_tool(3, '20240102', 3); -- Valid loan
CALL issue_tool(2, '20240103', 5); -- Request exceeding stock

SELECT * FROM tools;
SELECT * FROM tool_loans;

-- Step 6: Create return_tool procedure and test double call
CREATE OR REPLACE PROCEDURE return_tool(p_loan_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tool_id INT;
    v_qty INT;
    v_status VARCHAR;
BEGIN
    SELECT tool_id, quantity, status INTO v_tool_id, v_qty, v_status FROM tool_loans WHERE loan_id = p_loan_id;

    IF v_status IS NULL THEN
        RAISE NOTICE 'Loan ID % not found.', p_loan_id;
    ELSIF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan % is already RETURNED. No stock added.', p_loan_id;
    ELSE
        UPDATE tools 
        SET available_qty = available_qty + v_qty 
        WHERE tool_id = v_tool_id;

        UPDATE tool_loans 
        SET status = 'RETURNED' 
        WHERE loan_id = p_loan_id;

        RAISE NOTICE 'Tool loan % returned. Restored % unit(s) to inventory.', p_loan_id, v_qty;
    END IF;
END $$;

CALL return_tool(1); -- First call: restores stock
CALL return_tool(1); -- Second call: does not add stock again

-- Step 7: Explicit cursor to display tools with low availability
DO $$
DECLARE
    cur_low_tools CURSOR FOR 
        SELECT tool_name, available_qty 
        FROM tools 
        WHERE available_qty <= 3;
    v_rec RECORD;
BEGIN
    OPEN cur_low_tools;
    LOOP
        FETCH cur_low_tools INTO v_rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low Availability Tool: %, Stock: %', v_rec.tool_name, v_rec.available_qty;
    END LOOP;
    CLOSE cur_low_tools;
END $$;

-- Step 8: Handle zero quantity request with EXCEPTION block
DO $$
BEGIN
    CALL issue_tool(3, '20240104', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught Error: %', SQLERRM;
END $$;

-- Step 9: Query final state
SELECT * FROM tools;
SELECT * FROM tool_loans;