```sql
-- Создание доски
INSERT INTO boards (name, owner_id, format)
VALUES ('Проектная доска', 1, 'status');

-- Добавление пользователя к доске
INSERT INTO board_members (board_id, user_id, role)
VALUES (1, 2, 'member');

-- Получить все доски пользователя
SELECT b.*
FROM boards b
JOIN board_members bu ON b.board_id = bu.board_id
WHERE bu.user_id = 1;

-- Получить колонки доски
SELECT *
FROM columns
WHERE board_id = 1
ORDER BY position;

-- Получить карточки в колонке
SELECT *
FROM cards
WHERE column_id = 1
ORDER BY position;

-- Получить теги карточки
SELECT t.*
FROM tags t
JOIN card_tags ct ON t.tag_id = ct.tag_id
WHERE ct.card_id = 3;