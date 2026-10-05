-- Step 1: Create tables and insert initial records[cite: 4]
DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS lab_sessions CASCADE;

CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100) NOT NULL,
    available_workstations INT NOT NULL CHECK (available_workstations >= 0)
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INT REFERENCES lab_sessions(session_id),
    lecturer VARCHAR(100) NOT NULL,
    num_workstations INT NOT NULL,
    status VARCHAR(20) NOT NULL
);

INSERT INTO lab_sessions (session_name, available_workstations) VALUES
('CS101 Lab', 0),
('ICT371 Practical', 4),
('NET201 Workshop', 25);

-- Step 2: IF ELSIF ELSE logic to report workstation capacity[cite: 4]
DO $$
DECLARE
    v_avail INT;
BEGIN
    SELECT available_workstations INTO v_avail FROM lab_sessions WHERE session_id = 2;
    IF v_avail = 0 THEN
        RAISE NOTICE 'Session is FULL.';
    ELSIF v_avail <= 5 THEN
        RAISE NOTICE 'Session is NEARLY FULL (% workstations left).', v_avail;
    ELSE
        RAISE NOTICE 'Session HAS ENOUGH workstations (% workstations left).', v_avail;
    END IF;
END $$;

-- Step 3: WHILE loop and numeric FOR loop[cite: 4]
DO $$
DECLARE
    v_counter INT := 1;
BEGIN
    -- WHILE loop for session preparation reminders
    WHILE v_counter <= 3 LOOP
        RAISE NOTICE 'Preparation Reminder %: Ensure lab equipment is powered on.', v_counter;
        v_counter := v_counter + 1;
    END LOOP;

    -- Numeric FOR loop for workstation checks
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Workstation Check %: Verified hardware status.', i;
    END LOOP;
END $$;

-- Step 4: Create reserve_workstations procedure[cite: 4]
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INT,
    p_lecturer VARCHAR,
    p_num_workstations INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_avail INT;
BEGIN
    IF p_num_workstations <= 0 THEN
        RAISE EXCEPTION 'Invalid workstation count: %. Must be greater than 0.', p_num_workstations;
    END IF;

    SELECT available_workstations INTO v_avail FROM lab_sessions WHERE session_id = p_session_id;

    IF v_avail IS NULL THEN
        RAISE EXCEPTION 'Session ID % does not exist.', p_session_id;
    END IF;

    IF v_avail >= p_num_workstations THEN
        UPDATE lab_sessions 
        SET available_workstations = available_workstations - p_num_workstations 
        WHERE session_id = p_session_id;

        INSERT INTO reservations (session_id, lecturer, num_workstations, status)
        VALUES (p_session_id, p_lecturer, p_num_workstations, 'RESERVED');
        
        RAISE NOTICE 'Reservation successful for %.', p_lecturer;
    ELSE
        RAISE NOTICE 'Reservation failed for %: Exceeds capacity (Requested: %, Available: %).', p_lecturer, p_num_workstations, v_avail;
    END IF;
END $$;

-- Step 5: Call reserve_workstations procedure and query tables
CALL reserve_workstations(2, 'Dr. Smith', 2);   -- Valid reservation
CALL reserve_workstations(3, 'Prof. Mwamba', 10); -- Valid reservation
CALL reserve_workstations(2, 'Dr. Jones', 10);   -- Exceeds capacity

SELECT * FROM lab_sessions;
SELECT * FROM reservations;

-- Step 6: Create cancel_reservation procedure and test double call[cite: 5]
CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_id INT;
    v_num INT;
    v_status VARCHAR;
BEGIN
    SELECT session_id, num_workstations, status 
    INTO v_session_id, v_num, v_status 
    FROM reservations 
    WHERE reservation_id = p_reservation_id;

    IF v_status IS NULL THEN
        RAISE NOTICE 'Reservation ID % not found.', p_reservation_id;
    ELSIF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation % is already CANCELLED. No workstations released.', p_reservation_id;
    ELSE
        UPDATE lab_sessions 
        SET available_workstations = available_workstations + v_num 
        WHERE session_id = v_session_id;

        UPDATE reservations 
        SET status = 'CANCELLED' 
        WHERE reservation_id = p_reservation_id;

        RAISE NOTICE 'Reservation % cancelled and % workstations released.', p_reservation_id, v_num;
    END IF;
END $$;

CALL cancel_reservation(1); -- First call: releases workstations
CALL cancel_reservation(1); -- Second call: does not release workstations again

-- Step 7: Explicit cursor to display sessions with few workstations remaining[cite: 5]
DO $$
DECLARE
    cur_low_capacity CURSOR FOR 
        SELECT session_name, available_workstations 
        FROM lab_sessions 
        WHERE available_workstations <= 5;
    v_rec RECORD;
BEGIN
    OPEN cur_low_capacity;
    LOOP
        FETCH cur_low_capacity INTO v_rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low Workstation Session: %, Remaining: %', v_rec.session_name, v_rec.available_workstations;
    END LOOP;
    CLOSE cur_low_capacity;
END $$;

-- Step 8: Handle invalid quantity with EXCEPTION block[cite: 5]
DO $$
BEGIN
    CALL reserve_workstations(3, 'Dr. Bandas', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught Error: %', SQLERRM;
END $$;

-- Step 9: Query final state[cite: 5]
SELECT * FROM lab_sessions;
SELECT * FROM reservations;