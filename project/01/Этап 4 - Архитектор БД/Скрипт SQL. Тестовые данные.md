```sql
-- Пользователи (users)
INSERT INTO users (email, full_name, password_hash)
VALUES
('admin@kanban.ru', 'Администратор', 'hash1'),
('user@kanban.ru', 'Пользователь', 'hash2');

-- Доска (boards)
INSERT INTO boards (name, owner_id, format)
VALUES ('Учебный проект', 1, 'status');

-- Участники доски (board_members)
INSERT INTO board_members (board_id, user_id, role)
VALUES
(1, 1, 'creator'),  -- создатель доски
(1, 2, 'member');   -- обычный участник

-- Колонки (columns)
INSERT INTO columns (board_id, name, position)
VALUES
(1, 'К выполнению', 1),
(1, 'В работе', 2),
(1, 'Готово', 3);

-- Карточки (cards)
INSERT INTO cards (column_id, title, description, created_by, position)
VALUES
(1, 'Собрать требования', 'Описание требований', 1, 1),
(2, 'Реализовать БД', 'Создание структуры БД', 1, 1);

-- Теги (tags)
INSERT INTO tags (name, color, board_id)
VALUES
('Важно', '#FF4444', 1),  -- красный
('Срочно', '#FF8800', 1); -- оранжевый

-- Привязка тегов к карточкам (card_tags)
INSERT INTO card_tags (card_id, tag_id)
VALUES
(1, 1),
(2, 2);

-- Ответственные за карточки (card_assignees)
INSERT INTO card_assignees (card_id, user_id)
VALUES
(1, 1),  -- админ ответственный за первую карточку
(2, 2);  -- пользователь ответственный за вторую карточку