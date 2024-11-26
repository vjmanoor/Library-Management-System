/* creating books table */

CREATE TABLE BOOKS (
	BOOK_ID VARCHAR(50) PRIMARY KEY,
	NAME VARCHAR(50) NOT NULL,
	AUTHOR VARCHAR(255),
	PUBLICATION_YEAR INT CHECK (PUBLICATION_YEAR > 0)
);
/* inserting data into books table */

COPY BOOKS (BOOK_ID, NAME, AUTHOR, PUBLICATION_YEAR)
FROM
	'C:/Users/jayka/OneDrive/Desktop/Brainwave Matrix Task 1/books.csv' DELIMITER ',' CSV HEADER;

SELECT
	*
FROM
	BOOKS;

/*Creating members table */

CREATE TABLE MEMBERS (
	MEMBER_ID VARCHAR(50) NOT NULL,
	NAME VARCHAR(255) NOT NULL,
	EMAIL_ID VARCHAR(255) UNIQUE NOT NULL,
	CONTACT BIGINT NOT NULL CHECK (
		CONTACT > 999999999
		AND CONTACT <= 9999999999
	)
);

COPY MEMBERS (MEMBER_ID, NAME, EMAIL_ID, CONTACT)
FROM
	'C:\Users\jayka\OneDrive\Desktop\Brainwave Matrix Task 1\members.csv' DELIMITER ',' CSV HEADER;

SELECT
	*
FROM	MEMBERS;

/* Now I am going to create a thrid table which contains all the records of 
borrowings */

CREATE TABLE BORROWINGS (
	BORROWING_ID SERIAL PRIMARY KEY,
	BOOK_ID VARCHAR(50) NOT NULL,
	MEMBER_ID VARCHAR(50) NOT NULL,
	DATE_OF_BORROWING DATE DEFAULT CURRENT_DATE,
	FINE INT DEFAULT 0 CHECK (FINE >= 0),
	FOREIGN KEY (BOOK_ID) REFERENCES BOOKS (BOOK_ID) ON DELETE CASCADE,
	FOREIGN KEY (MEMBER_ID) REFERENCES MEMBERS (MEMBER_ID) ON DELETE CASCADE
);

/* I ran through an error while creating the above table borrowigs
and I wasn't able to create the table because member_id foreign key was not referencing 
the member_id in the members table. So, I handled it as follows */

ALTER TABLE MEMBERS
ADD CONSTRAINT PK_MEMBERS PRIMARY KEY (MEMBER_ID); -- this hepled me to make member_id a primary key.


COPY BORROWINGS
FROM
	'C:\Users\jayka\OneDrive\Desktop\Brainwave Matrix Task 1\Borrowings.csv' DELIMITER ',' CSV HEADER; -- inserted the data using copy table and added sample data into the borrowings table.

/* Now I will create a staff table which contains the information of staff working the the library */

CREATE TABLE STAFF (
	STAFF_ID VARCHAR(50) PRIMARY KEY,
	NAME VARCHAR(255) NOT NULL,
	LOGIN_ID VARCHAR(255) UNIQUE NOT NULL,
	CONTACT BIGINT NOT NULL CHECK (
		CONTACT > 999999999
		AND CONTACT <= 9999999999
	)
);

COPY STAFF
FROM
	'C:\Users\jayka\OneDrive\Desktop\Brainwave Matrix Task 1\Staff.csv' DELIMITER ',' CSV HEADER;

SELECT
	*
FROM
	STAFF;

/* the above data is a rudimentary level of database design 
it contains no duplicates and can be scaled up as per the requirement */

/* in this part, we are going to write some indexes so that the system is fast and effecient */

CREATE INDEX IDX_MEMBER_ID ON BORROWINGS (MEMBER_ID);

CREATE INDEX IDX_BOOK_ID ON BORROWINGS (BOOK_ID);

CREATE INDEX IDX_BOOK_NAME ON BOOKS (NAME);

CREATE INDEX IDX_MEMBER_EMAIL ON MEMBERS (EMAIL_ID);

/* the above query has created the required index, now let us dive into the advanced sql queries 
so that we address the business problems in hand */

-- 1. most borrowed books

SELECT
	B.NAME AS BOOK_NAME,
	B.AUTHOR AS AUTHOR,
	COUNT(BR.BOOK_ID) AS BORROW_COUNT
FROM
	BORROWINGS BR
	JOIN BOOKS B ON B.BOOK_ID = BR.BOOK_ID
GROUP BY
	B.NAME,
	B.AUTHOR
ORDER BY
	BORROW_COUNT DESC
LIMIT
	10;

-- Most active members
SELECT
	M.NAME AS MEMBER_NAME,
	COUNT(BR.MEMBER_ID) AS BORROW_COUNT
FROM
	BORROWINGS BR
	JOIN MEMBERS M ON BR.MEMBER_ID = M.MEMBER_ID
GROUP BY
	M.NAME
ORDER BY
	BORROW_COUNT DESC LIMIT
	10;
-- books currently borrowed
SELECT
	B.NAME AS BOOK_NAME,
	M.NAME AS BORROWED_BY,
	BR.DATE_OF_BORROWING
FROM
	BORROWINGS BR
	JOIN BOOKS B ON BR.BOOK_ID = B.BOOK_ID
	JOIN MEMBERS M ON BR.MEMBER_ID = M.MEMBER_ID
WHERE
	CURRENT_DATE - BR.DATE_OF_BORROWING <= 30;

-- overdue books
SELECT
	M.NAME AS MEMBER_NAME,
	B.NAME AS BOOK_NAME,
	BR.DATE_OF_BORROWING,
	CURRENT_DATE - BR.DATE_OF_BORROWING AS DAYS_OVERDUE
FROM
	BORROWINGS BR
	JOIN BOOKS B ON BR.BOOK_ID = B.BOOK_ID
	JOIN MEMBERS M ON BR.MEMBER_ID = M.MEMBER_ID
WHERE
	CURRENT_DATE - BR.DATE_OF_BORROWING > 30;

-- total fines collected

SELECT
	SUM(FINE) AS TOTAL_FINES_COLLECTED
FROM
	BORROWINGS;

-- Borrowing trends by month

SELECT
	DATE_TRUNC('month', DATE_OF_BORROWING) AS MONTH,
	COUNT(*) AS BORROW_COUNT
FROM
	BORROWINGS
GROUP BY
	MONTH
ORDER BY
	MONTH;

-- Books never borrowed

SELECT
	B.NAME AS BOOK_NAME,
	B.AUTHOR
FROM
	BOOKS B
	LEFT JOIN BORROWINGS BR ON B.BOOK_ID = BR.BOOK_ID
WHERE
	BR.BOOK_ID ISNULL;

-- Members with outstanding fine

SELECT
	M.NAME AS MEMBER_NAME,
	SUM(BR.FINE) AS TOTAL_FINE
FROM
	BORROWINGS BR
	JOIN MEMBERS M ON BR.MEMBER_ID = M.MEMBER_ID
WHERE
	BR.FINE > 0
GROUP BY
	M.NAME
ORDER BY
	TOTAL_FINE DESC;

/* Now we are done with advance sql queries, additionally I want to add new set of data in 
books and borrowings table */

COPY BOOKS
FROM
	'C:\Users\jayka\OneDrive\Desktop\Brainwave Matrix Task 1\books_updated.csv' DELIMITER ',' CSV HEADER;

SELECT
	*
FROM
	BORROWINGS;

COPY BORROWINGS
FROM
	'C:\Users\jayka\OneDrive\Desktop\Brainwave Matrix Task 1\borrowings_updated_unique_ids.csv' DELIMITER ',' CSV HEADER;

/* I have done the coding for the most part, now I will write triggers.
This will allow a particular function to execute automatically when a certain event is performed */

CREATE OR REPLACE FUNCTION calculate_fine()
RETURNS TRIGGER AS $$
BEGIN
    -- Calculate overdue days as an integer
    IF (NEW.date_of_borrowing + INTERVAL '30 days' < CURRENT_DATE) THEN
        NEW.fine := EXTRACT(DAY FROM (CURRENT_DATE - (NEW.date_of_borrowing + INTERVAL '30 days'))) * 10;
    ELSE
        NEW.fine := 0;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


/* Lets create a trigger that will call the above function */

CREATE TRIGGER TRIGGER_CALCULATE_FINE BEFORE 
INSERT OR
UPDATE ON BORROWINGS FOR EACH ROW
EXECUTE FUNCTION CALCULATE_FINE ();

/* I have modified the trigger as it was not returning the desired result */

DROP TRIGGER IF EXISTS trigger_calculate_fine ON Borrowings;

CREATE TRIGGER trigger_calculate_fine
BEFORE INSERT OR UPDATE ON Borrowings
FOR EACH ROW
EXECUTE FUNCTION calculate_fine();


/* This will allow us to dynamically calculate fines upon CRUD operations.
This will trigger the already created function calculate_function */

-- to test the above function, let us try to insert some data

INSERT INTO
	BORROWINGS (
		BORROWING_ID,
		BOOK_ID,
		MEMBER_ID,
		DATE_OF_BORROWING,
		FINE
	)
VALUES
	('177', 'B001', 'M001', '2023-09-01', 0);

INSERT INTO
	BORROWINGS (
		BORROWING_ID,
		BOOK_ID,
		MEMBER_ID,
		DATE_OF_BORROWING,
		FINE
	)
VALUES
	('180', 'B022', 'M011', '2022-09-01', 15);

INSERT INTO
	BORROWINGS (
		BORROWING_ID,
		BOOK_ID,
		MEMBER_ID,
		DATE_OF_BORROWING,
		FINE
	)
VALUES
	('182', 'B042', 'M016', '2022-09-01', 0);

INSERT INTO
	BORROWINGS (
		BORROWING_ID,
		BOOK_ID,
		MEMBER_ID,
		DATE_OF_BORROWING,
		FINE
	)
VALUES
	('175', 'B055', 'M020', '2023-09-01', 0);

SELECT
	*
FROM
	BORROWINGS
WHERE
	BORROWING_ID = '182';

SELECT
	*
FROM
	BORROWINGS
WHERE
	BORROWING_ID = '180';

SELECT
	*
FROM
	BORROWINGS
WHERE
	BORROWING_ID = '175';

SELECT
	*
FROM
	BORROWINGS
WHERE
	BORROWING_ID = '177';

UPDATE BORROWINGS
SET
	FINE = '0'
WHERE
	BORROWING_ID = '180';

SELECT
	*
FROM
	BORROWINGS
WHERE
	BORROWING_ID = '180';

/* as we can see the fine column is automatically updated upon insert or update 
by this we can conclude that there is a significant change in execution time on the database*/

/* let us go ahead and create stored procedures, this will help us in encapsulating the
sql logic and make robust front-end */
DROP PROCEDURE IF EXISTS RETURN_BOOK (int);

CREATE OR REPLACE PROCEDURE return_book(p_borrowing_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    fine_amount INTEGER;
BEGIN
    -- Check if borrowing ID exists
    IF NOT EXISTS (SELECT 1 FROM borrowings WHERE borrowing_id = p_borrowing_id) THEN
        RAISE EXCEPTION 'Borrowing ID % does not exist', p_borrowing_id;
    END IF;

    -- Fetch and log fine details
    SELECT fine INTO fine_amount FROM borrowings WHERE borrowing_id = p_borrowing_id;
    INSERT INTO logs(action, timestamp, details)
    VALUES (
        'Return Book',
        CURRENT_TIMESTAMP,
        CONCAT('Borrowing ID: ', p_borrowing_id, ', Fine: ', fine_amount)
    );

    -- Mark book as returned and clear fine
    DELETE FROM borrowings WHERE borrowing_id = p_borrowing_id;

    -- Notify success
    RAISE NOTICE 'Book successfully returned. Fine of % cleared.', fine_amount;
END;
$$;



SELECT borrowing_id, fine FROM borrowings
where borrowing_id = 134;

call return_book(134);

/* Creating to procedure for borrowing books */

drop procedure if exists borrow_book()

CREATE OR REPLACE PROCEDURE borrow_book(p_book_id VARCHAR, p_member_id VARCHAR)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check if the book exists and is available
    IF NOT EXISTS (
        SELECT 1
        FROM books
        WHERE book_id = p_book_id
    ) THEN
        RAISE EXCEPTION 'Book with ID % does not exist.', p_book_id;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM borrowings
        WHERE book_id = p_book_id AND date_of_borrowing IS NULL
    ) THEN
        RAISE EXCEPTION 'Book with ID % is already borrowed.', p_book_id;
    END IF;

    -- Check if the member exists
    IF NOT EXISTS (
        SELECT 1
        FROM members
        WHERE member_id = p_member_id
    ) THEN
        RAISE EXCEPTION 'Member with ID % does not exist.', p_member_id;
    END IF;

    -- Insert the borrowing record
    INSERT INTO borrowings (book_id, member_id, date_of_borrowing, fine)
    VALUES (p_book_id, p_member_id, CURRENT_DATE, 0);

    -- Optional: Log the action (if you have a logs table)
    INSERT INTO logs(action, timestamp, details)
    VALUES ('Borrow Book', CURRENT_TIMESTAMP, CONCAT('Book ID: ', p_book_id, ', Member ID: ', p_member_id));

    RAISE NOTICE 'Book % successfully borrowed by member %.', p_book_id, p_member_id;
END;
$$;


call borrow_book('B001', 'M001');

/* this takes input borrowing_id as input parameter, checks if borrowing_id exists, delete the borrowing 
record when the book is returned and gives a feedback in 'Notice' */



SELECT
	*
FROM
	BORROWINGS
WHERE
	BORROWING_ID = '151';

/* Now let us write a procedure for handling overdue books */

CREATE TABLE IF NOT EXISTS logs (
    log_id SERIAL PRIMARY KEY,
    action VARCHAR(255) NOT NULL,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    details TEXT
);


/*DROP PROCEDURE IF EXISTS handle_overdue_books(VARCHAR);*/


CREATE OR REPLACE PROCEDURE handle_overdue_books(p_member_id VARCHAR DEFAULT NULL)
LANGUAGE plpgsql
AS $$
DECLARE
    overdue_record RECORD;
    fine_per_day INTEGER := 5; -- Adjust as necessary
BEGIN
    -- Loop through overdue books
    FOR overdue_record IN 
        SELECT borrowing_id, book_id, member_id, date_of_borrowing
        FROM borrowings
        WHERE CURRENT_DATE - date_of_borrowing > 14 -- Overdue threshold
          AND (p_member_id IS NULL OR member_id = p_member_id)
    LOOP
        -- Calculate fine
        UPDATE borrowings
        SET fine = fine_per_day * (CURRENT_DATE - date_of_borrowing - 14)
        WHERE borrowing_id = overdue_record.borrowing_id;

        -- Log the action
        INSERT INTO logs(action, timestamp, details)
        VALUES (
            'Handle Overdue Book',
            CURRENT_TIMESTAMP,
            CONCAT('Borrowing ID: ', overdue_record.borrowing_id, ', Fine Applied')
        );
    END LOOP;
END;
$$;

CALL handle_overdue_books();

SELECT borrowing_id, fine FROM borrowings WHERE fine > 0;

SELECT * FROM logs ORDER BY timestamp DESC LIMIT 10;



/* to log the details of overdue books we can write a procedure as follows */

CREATE
OR REPLACE FUNCTION GET_OVERDUE_BOOKS () RETURNS TABLE (
	BORROWING_ID INT,
	BOOK_ID VARCHAR,
	MEMBER_ID VARCHAR,
	DATE_OF_BORROWING DATE,
	FINE INT
) LANGUAGE SQL AS $$
	select borrowing_id, book_id, member_id, date_of_borrowing, fine
	from borrowings
	where fine > 0;
$$;

CALL HANDLE_OVERDUE_BOOKS ();

SELECT
	*
FROM
	GET_OVERDUE_BOOKS ()
WHERE
	BORROWING_ID = 139;

CALL RETURN_BOOK (180);

/* the above procedures ensures to check for overdue and promptly remove that returned book */

/* Now we are approaching the end of the project, here we will vacuum the database. Vacuuming helps us
to manage data in a more effecient way by reclaiming space occupied by deleted or updated tuples */

vacuum full;

/* Checking for Dead Tuples */

select relname, n_dead_tup
from pg_stat_user_tables
where n_dead_tup > 0

/* 5 tuples from staff and 3 tuples from borrowings have benefited from vacuuming */

SELECT * FROM pg_catalog.pg_user;

