# Практична робота 15. Створення індексів та аналіз ефективності запитів

**Варіант:** 1 — Бібліотека  
**Базова база даних:** `lab_work_14.db`  
**Таблиця для аналізу:** `loans`

## Мета
Створити індекси для полів, за якими виконується пошук, фільтрація та сортування, порівняти плани виконання через `EXPLAIN QUERY PLAN`, а також перевірити видалення індексу. Структура таблиць і записи не змінюються.

## Завдання 1. Індекс за `book_id`

Запит:
```sql
SELECT id, book_id, reader_id, loan_date FROM loans WHERE book_id = 1;
```

**До створення індексу:**
```text
2 | 0 | 0 | SCAN loans
```
SQLite виконував повне сканування таблиці (`SCAN loans`): перевіряв рядки, щоб знайти потрібний `book_id`.

Створено:
```sql
CREATE INDEX idx_loans_book_id ON loans(book_id);
```

**Після створення індексу:**
```text
3 | 0 | 0 | SEARCH loans USING INDEX idx_loans_book_id (book_id=?)
```
План змінився на `SEARCH ... USING INDEX`: SQLite може звернутися до індексу й знайти записи за значенням `book_id`, не переглядаючи всю таблицю.

## Завдання 2. Індекс для зовнішнього ключа `reader_id`

Для пошуку всіх позик конкретного читача використано:
```sql
SELECT id, book_id, loan_date FROM loans WHERE reader_id = 2;
```

**До створення індексу:**
```text
2 | 0 | 0 | SCAN loans
```
План показує повне сканування `loans`, оскільки індексу за `reader_id` ще немає.

Створено:
```sql
CREATE INDEX idx_loans_reader_id ON loans(reader_id);
```

**Після створення індексу:**
```text
3 | 0 | 0 | SEARCH loans USING INDEX idx_loans_reader_id (reader_id=?)
```
Тепер використовується `idx_loans_reader_id`. Індекс за зовнішнім ключем корисний не лише для пошуку позик читача, а й може пришвидшити перевірки та операції з батьківськими записами, які зачіпають зовнішній ключ.

## Завдання 3. Складений індекс

Запит одночасно фільтрує за книгою та читачем:
```sql
SELECT id, book_id, reader_id FROM loans
WHERE book_id = 1 AND reader_id = 2;
```

**До складеного індексу** (окремі індекси `book_id` і `reader_id` вже існують):
```text
3 | 0 | 0 | SEARCH loans USING INDEX idx_loans_reader_id (reader_id=?)
```
План використовує окремий індекс `idx_loans_reader_id` для пошуку за `reader_id`; умова за `book_id` перевіряється додатково.

Створено:
```sql
CREATE INDEX idx_loans_book_reader ON loans(book_id, reader_id);
```

**Після створення складеного індексу:**
```text
2 | 0 | 0 | SEARCH loans USING COVERING INDEX idx_loans_book_reader (book_id=? AND reader_id=?)
```
План використовує `COVERING INDEX idx_loans_book_reader` з обома умовами пошуку. Індекс містить обидва стовпці в заданому порядку, тому SQLite може ефективно звузити пошук за парою значень. Для такого запиту складений індекс доречніший, ніж два незалежні індекси.

## Завдання 4. Індекс для `ORDER BY loan_date`

Запит:
```sql
SELECT id, book_id, loan_date FROM loans ORDER BY loan_date DESC;
```

**До індексу дати:**
```text
3 | 0 | 0 | SCAN loans
11 | 0 | 0 | USE TEMP B-TREE FOR ORDER BY
```
План містить `SCAN loans` і `USE TEMP B-TREE FOR ORDER BY`: таблицю потрібно переглянути, а для сортування створити тимчасову структуру.

Створено:
```sql
CREATE INDEX idx_loans_loan_date ON loans(loan_date);
```

**Після створення індексу:**
```text
4 | 0 | 0 | SCAN loans USING INDEX idx_loans_loan_date
```
SQLite проходить індекс `idx_loans_loan_date` у потрібному порядку; окрема тимчасова B-tree структура для сортування більше не потрібна.

## Завдання 5. Видалення індексу

Виконано:
```sql
DROP INDEX idx_loans_loan_date;
```

Після видалення у `sqlite_master` залишаються створені індекси:
```text
idx_loans_book_id | CREATE INDEX idx_loans_book_id ON loans(book_id)
idx_loans_book_reader | CREATE INDEX idx_loans_book_reader ON loans(book_id, reader_id)
idx_loans_reader_id | CREATE INDEX idx_loans_reader_id ON loans(reader_id)
```
Індекс `idx_loans_loan_date` відсутній. Повторний план запиту сортування:
```text
3 | 0 | 0 | SCAN loans
11 | 0 | 0 | USE TEMP B-TREE FOR ORDER BY
```
Знову з'являється `USE TEMP B-TREE FOR ORDER BY`, отже видалення індексу повернуло необхідність окремого сортування. Індекси `idx_loans_book_id`, `idx_loans_reader_id` та `idx_loans_book_reader` залишено в базі.

## Контрольні питання

**1. Що показує `EXPLAIN QUERY PLAN` і як зрозуміти, що індекс використовується?**  
Команда показує обраний SQLite план доступу до даних, а не фактичний час виконання. `SCAN` означає перегляд таблиці або індексу, `SEARCH ... USING INDEX` — пошук за індексом. `USING COVERING INDEX` означає, що потрібні для запиту стовпці доступні без додаткового читання рядків таблиці. Для сортування показник `USE TEMP B-TREE FOR ORDER BY` свідчить, що SQLite створює тимчасову структуру.

**2. Чим складений індекс відрізняється від двох окремих і чому важливий порядок стовпців?**  
Складений індекс зберігає ключі як комбінацію стовпців і може обслуговувати запит, що фільтрує за кількома полями одночасно. Порядок має значення: індекс `(book_id, reader_id)` найкраще підходить для умов за `book_id` або за обома стовпцями, але зазвичай не є рівноцінною заміною індексу лише на `reader_id`. Тому склад індексу слід обирати відповідно до реальних умов `WHERE`, `JOIN` і `ORDER BY`.

**3. Яку ціну мають індекси? Чому не варто індексувати всі стовпці?**  
Індекси займають додаткове місце на диску та потребують оновлення під час `INSERT`, `UPDATE` і `DELETE`, що може сповільнювати зміну даних. Надмірна кількість індексів збільшує витрати зберігання й обслуговування, а оптимізатор не обов'язково використає кожен з них. Створювати варто індекси під часті та важливі запити, а їхню користь перевіряти планом виконання й вимірюваннями.

## Перевірка фінальної бази

- `PRAGMA integrity_check` → `ok`.
- `PRAGMA foreign_key_check` → порожній результат.
- Кількість рядків у `loans` залишилася **9**.
- Створені індекси: `idx_loans_book_id`, `idx_loans_reader_id`, `idx_loans_book_reader`.
- `idx_loans_loan_date` видалений, як вимагає експеримент.
- Схема таблиць і дані Практики 14 не змінені.
