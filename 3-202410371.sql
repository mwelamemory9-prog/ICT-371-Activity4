
DROP TABLE IF EXISTS allocations CASCADE;
DROP TABLE IF EXISTS hostel_rooms CASCADE;

CREATE TABLE hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(20) NOT NULL,
    available_spaces INT NOT NULL CHECK (available_spaces >= 0)
);

CREATE TABLE allocations (
    allocation_id SERIAL PRIMARY KEY,
    room_id INT REFERENCES hostel_rooms(room_id),
    student_number VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL
);

INSERT INTO hostel_rooms (room_number, available_spaces) VALUES
('Block A-101', 0),
('Block A-102', 1),
('Block B-201', 4);

-- Step 2: IF ELSIF ELSE logic to report room space
DO $$
DECLARE
    v_spaces I-- Step 1: Create tables and insert initial records[cite: 4]
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
SELECT * FROM reservations;NT;
BEGIN
    SELECT available_spaces INTO v_spaces FROM hostel_rooms WHERE room_id = 2;
    IF v_spaces = 0 THEN
        RAISE NOTICE 'Room is FULL.';
    ELSIF v_spaces = 1 THEN
        RAISE NOTICE 'Room HAS ONE SPACE LEFT.';
    ELSE
        RAISE NOTICE 'Room HAS SEVERAL SPACES (% spaces).', v_spaces;
    END IF;
END $$;

-- Step 3: WHILE loop and numeric FOR loop
DO $$
DECLARE
    v_day INT := 1;
BEGIN
    -- WHILE loop for inspection days
    WHILE v_day <= 3 LOOP
        RAISE NOTICE 'Hostel Inspection Day %: Completed morning walk-through.', v_day;
        v_day := v_day + 1;
    END LOOP;

    -- Numeric FOR loop for room checks
    FOR r IN 1..3 LOOP
        RAISE NOTICE 'Room Check %: Keys and occupancy verified.', r;
    END LOOP;
END $$;

-- Step 4: Create allocate_room procedure
CREATE OR REPLACE PROCEDURE allocate_room(
    p_room_id INT,
    p_student_number VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_spaces INT;
BEGIN
    IF p_student_number IS NULL OR TRIM(p_student_number) = '' THEN
        RAISE EXCEPTION 'Student number cannot be blank.';
    END IF;

    SELECT available_spaces INTO v_spaces FROM hostel_rooms WHERE room_id = p_room_id;

    IF v_spaces IS NULL THEN
        RAISE EXCEPTION 'Room ID % does not exist.', p_room_id;
    END IF;

    IF v_spaces > 0 THEN
        UPDATE hostel_rooms 
        SET available_spaces = available_spaces - 1 
        WHERE room_id = p_room_id;

        INSERT INTO allocations (room_id, student_number, status)
        VALUES (p_room_id, p_student_number, 'ALLOCATED');

        RAISE NOTICE 'Room allocated successfully to student %.', p_student_number;
    ELSE
        RAISE NOTICE 'Allocation failed for student %: Room % is FULL.', p_student_number, p_room_id;
    END IF;
END $$;

-- Step 5: Call allocate_room and query tables
CALL allocate_room(2, '20230001'); -- Valid allocation
CALL allocate_room(3, '20230002'); -- Valid allocation
CALL allocate_room(1, '20230003'); -- Allocation to full room

SELECT * FROM hostel_rooms;
SELECT * FROM allocations;

-- Step 6: Create check_out procedure and test double call
CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_room_id INT;
    v_status VARCHAR;
BEGIN
    SELECT room_id, status INTO v_room_id, v_status FROM allocations WHERE allocation_id = p_allocation_id;

    IF v_status IS NULL THEN
        RAISE NOTICE 'Allocation ID % not found.', p_allocation_id;
    ELSIF v_status = 'COMPLETED' THEN
        RAISE NOTICE 'Allocation % is already COMPLETED. No space freed.', p_allocation_id;
    ELSE
        UPDATE hostel_rooms 
        SET available_spaces = available_spaces + 1 
        WHERE room_id = v_room_id;

        UPDATE allocations 
        SET status = 'COMPLETED' 
        WHERE allocation_id = p_allocation_id;

        RAISE NOTICE 'Student checked out. Bed space restored for room %.', v_room_id;
    END IF;
END $$;

CALL check_out(1); -- First call: restores space
CALL check_out(1); -- Second call: does not restore space again

-- Step 7: Explicit cursor to display full or nearly full rooms
DO $$
DECLARE
    cur_full_rooms CURSOR FOR 
        SELECT room_number, available_spaces 
        FROM hostel_rooms 
        WHERE available_spaces <= 1;
    v_rec RECORD;
BEGIN
    OPEN cur_full_rooms;
    LOOP
        FETCH cur_full_rooms INTO v_rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full/Nearly Full Room: %, Available Spaces: %', v_rec.room_number, v_rec.available_spaces;
    END LOOP;
    CLOSE cur_full_rooms;
END $$;

-- Step 8: Handle blank student number with EXCEPTION block
DO $$
BEGIN
    CALL allocate_room(3, '');
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught Error: %', SQLERRM;
END $$;

-- Step 9: Query final state
SELECT * FROM hostel_rooms;
SELECT * FROM allocations;