-- Практична робота 15. Створення індексів та аналіз ефективності запитів
-- Варіант 1: Бібліотека. Базова БД — результат Практики 14.
-- Структура таблиць і дані не змінюються; створюються лише індекси.
-- Увага: скрипт розрахований на запуск у lab_work_14.db (або її копії).
PRAGMA foreign_keys = ON;

-- Перевірка початкового стану індексів:
SELECT name, sql FROM sqlite_master WHERE type='index' ORDER BY name;

-- Завдання 1. Індекс для пошуку позик за book_id.
-- План ДО індексу:
-- 2 | 0 | 0 | SCAN loans
EXPLAIN QUERY PLAN
SELECT id, book_id, reader_id, loan_date FROM loans WHERE book_id = 1;

CREATE INDEX idx_loans_book_id ON loans(book_id);

-- План ПІСЛЯ індексу:
-- 3 | 0 | 0 | SEARCH loans USING INDEX idx_loans_book_id (book_id=?)
EXPLAIN QUERY PLAN
SELECT id, book_id, reader_id, loan_date FROM loans WHERE book_id = 1;

-- Завдання 2. Індекс для зовнішнього ключа reader_id.
-- План ДО індексу:
-- 2 | 0 | 0 | SCAN loans
EXPLAIN QUERY PLAN
SELECT id, book_id, loan_date FROM loans WHERE reader_id = 2;

CREATE INDEX idx_loans_reader_id ON loans(reader_id);

-- План ПІСЛЯ індексу:
-- 3 | 0 | 0 | SEARCH loans USING INDEX idx_loans_reader_id (reader_id=?)
EXPLAIN QUERY PLAN
SELECT id, book_id, loan_date FROM loans WHERE reader_id = 2;

-- Завдання 3. Складений індекс для двох умов одночасно.
-- План до складеного індексу (після окремих індексів):
-- 3 | 0 | 0 | SEARCH loans USING INDEX idx_loans_reader_id (reader_id=?)
EXPLAIN QUERY PLAN
SELECT id, book_id, reader_id FROM loans WHERE book_id = 1 AND reader_id = 2;

CREATE INDEX idx_loans_book_reader ON loans(book_id, reader_id);

-- План ПІСЛЯ складеного індексу:
-- 2 | 0 | 0 | SEARCH loans USING COVERING INDEX idx_loans_book_reader (book_id=? AND reader_id=?)
EXPLAIN QUERY PLAN
SELECT id, book_id, reader_id FROM loans WHERE book_id = 1 AND reader_id = 2;

-- Завдання 4. Індекс для сортування за loan_date.
-- План ДО індексу:
-- 3 | 0 | 0 | SCAN loans
-- 11 | 0 | 0 | USE TEMP B-TREE FOR ORDER BY
EXPLAIN QUERY PLAN
SELECT id, book_id, loan_date FROM loans ORDER BY loan_date DESC;

CREATE INDEX idx_loans_loan_date ON loans(loan_date);

-- План ПІСЛЯ індексу:
-- 4 | 0 | 0 | SCAN loans USING INDEX idx_loans_loan_date
EXPLAIN QUERY PLAN
SELECT id, book_id, loan_date FROM loans ORDER BY loan_date DESC;

-- Завдання 5. Видаляємо індекс дати й перевіряємо, що він зник.
DROP INDEX idx_loans_loan_date;

SELECT name, sql FROM sqlite_master
WHERE type='index' AND name NOT LIKE 'sqlite_autoindex_%'
ORDER BY name;

-- План після DROP INDEX (повторний запит перевіряється після перепідключення):
-- 3 | 0 | 0 | SCAN loans
-- 11 | 0 | 0 | USE TEMP B-TREE FOR ORDER BY
EXPLAIN QUERY PLAN
SELECT id, book_id, loan_date FROM loans ORDER BY loan_date DESC;

-- Фінальний перелік усіх індексів:
SELECT name, sql FROM sqlite_master WHERE type='index' ORDER BY name;
