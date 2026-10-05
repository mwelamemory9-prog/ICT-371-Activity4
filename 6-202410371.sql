-- Step 1: Create tables and insert initial records
DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS events CASCADE;

CREATE TABLE events (
    event_id SERIAL PRIMARY KEY,
    event_name VARCHAR(100) NOT NULL,
    available_seats INT NOT NULL CHECK (available_seats >= 0)
);

CREATE TABLE bookings (
    booking_id SERIAL PRIMARY KEY,
    event_id INT REFERENCES events(event_id),
    student_number VARCHAR(50) NOT NULL,
    num_seats INT NOT NULL,
    status VARCHAR(20) NOT NULL
);

INSERT INTO events (event_name, available_seats) VALUES
('Tech Innovation Summit', 0),
('Career Fair 2026', 8),
('Annual Cultural Night', 100);

-- Step 2: IF ELSIF ELSE logic to report event seat capacity
DO $$
DECLARE
    v_seats INT;
BEGIN
    SELECT available_seats INTO v_seats FROM events WHERE event_id = 2;
    IF v_seats = 0 THEN
        RAISE NOTICE 'Event is FULL.';
    ELSIF v_seats <= 10 THEN
        RAISE NOTICE 'Event is NEARLY FULL (% seats left).', v_seats;
    ELSE
        RAISE NOTICE 'Event HAS PLENTY OF SEATS (% seats left).', v_seats;
    END IF;
END $$;

-- Step 3: WHILE loop and numeric FOR loop
DO $$
DECLARE
    v_rem_day INT := 1;
BEGIN
    -- WHILE loop for booking reminder days
    WHILE v_rem_day <= 3 LOOP
        RAISE NOTICE 'Booking Reminder Day %: Early-bird ticket registrations open.', v_rem_day;
        v_rem_day := v_rem_day + 1;
    END LOOP;

    -- Numeric FOR loop for entrance checks
    FOR e IN 1..3 LOOP
        RAISE NOTICE 'Entrance Check %: Scanner station operational.', e;
    END LOOP;
END $$;

-- Step 4: Create book_seats procedure
CREATE OR REPLACE PROCEDURE book_seats(
    p_event_id INT,
    p_student_number VARCHAR,
    p_num_seats INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_seats INT;
BEGIN
    IF p_num_seats <= 0 THEN
        RAISE EXCEPTION 'Invalid booking seat count: %. Must be greater than zero.', p_num_seats;
    END IF;

    SELECT available_seats INTO v_seats FROM events WHERE event_id = p_event_id;

    IF v_seats IS NULL THEN
        RAISE EXCEPTION 'Event ID % does not exist.', p_event_id;
    END IF;

    IF v_seats >= p_num_seats THEN
        UPDATE events 
        SET available_seats = available_seats - p_num_seats 
        WHERE event_id = p_event_id;

        INSERT INTO bookings (event_id, student_number, num_seats, status)
        VALUES (p_event_id, p_student_number, p_num_seats, 'BOOKED');

        RAISE NOTICE 'Successfully booked % seat(s) for student %.', p_num_seats, p_student_number;
    ELSE
        RAISE NOTICE 'Booking failed for student %: Not enough seats (Requested: %, Available: %).', p_student_number, p_num_seats, v_seats;
    END IF;
END $$;

-- Step 5: Call book_seats and query tables[cite: 6]
CALL book_seats(2, '20250001', 3);  -- Valid booking
CALL book_seats(3, '20250002', 10); -- Valid booking
CALL book_seats(2, '20250003', 20); -- Exceeds available seats

SELECT * FROM events;
SELECT * FROM bookings;

-- Step 6: Create cancel_booking procedure and test double call
CREATE OR REPLACE PROCEDURE cancel_booking(p_booking_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_event_id INT;
    v_num INT;
    v_status VARCHAR;
BEGIN
    SELECT event_id, num_seats, status INTO v_event_id, v_num, v_status FROM bookings WHERE booking_id = p_booking_id;

    IF v_status IS NULL THEN
        RAISE NOTICE 'Booking ID % not found.', p_booking_id;
    ELSIF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Booking % is already CANCELLED. No seats released.', p_booking_id;
    ELSE
        UPDATE events 
        SET available_seats = available_seats + v_num 
        WHERE event_id = v_event_id;

        UPDATE bookings 
        SET status = 'CANCELLED' 
        WHERE booking_id = p_booking_id;

        RAISE NOTICE 'Booking % cancelled. % seat(s) released back to event.', p_booking_id, v_num;
    END IF;
END $$;

CALL cancel_booking(1); -- First call: releases seats
CALL cancel_booking(1); -- Second call: does not release seats again

-- Step 7: Explicit cursor to display full or nearly full events
DO $$
DECLARE
    cur_full_events CURSOR FOR 
        SELECT event_name, available_seats 
        FROM events 
        WHERE available_seats <= 10;
    v_rec RECORD;
BEGIN
    OPEN cur_full_events;
    LOOP
        FETCH cur_full_events INTO v_rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full/Nearly Full Event: %, Available Seats: %', v_rec.event_name, v_rec.available_seats;
    END LOOP;
    CLOSE cur_full_events;
END $$;

-- Step 8: Try to book zero seats with EXCEPTION block
DO $$
BEGIN
    CALL book_seats(3, '20250004', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught Error: %', SQLERRM;
END $$;

-- Step 9: Query final state[cite: 6]
SELECT * FROM events;
SELECT * FROM bookings;
