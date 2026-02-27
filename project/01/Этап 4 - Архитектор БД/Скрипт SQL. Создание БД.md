```sql
-- =========================
-- Создание ENUM типов
-- =========================
CREATE TYPE board_format AS ENUM ('status', 'custom');
CREATE TYPE user_role AS ENUM ('creator', 'admin', 'member', 'viewer');

-- =========================
-- Пользователи (users)
-- =========================
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- =========================
-- Доски (boards)
-- =========================
CREATE TABLE boards (
    board_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    format board_format DEFAULT 'status',
    owner_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- =========================
-- Участники досок (board_members)
-- =========================
CREATE TABLE board_members (
    board_member_id SERIAL PRIMARY KEY,
    board_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    role user_role DEFAULT 'member',
    UNIQUE(board_id, user_id),
    FOREIGN KEY (board_id) REFERENCES boards(board_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- =========================
-- Колонки (columns)
-- =========================
CREATE TABLE columns (
    column_id SERIAL PRIMARY KEY,
    board_id INTEGER NOT NULL,
    name VARCHAR(50) NOT NULL,
    position INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (board_id) REFERENCES boards(board_id) ON DELETE CASCADE
);

-- =========================
-- Карточки (cards)
-- =========================
CREATE TABLE cards (
    card_id SERIAL PRIMARY KEY,
    column_id INTEGER NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    created_by INTEGER NOT NULL,
    position INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (column_id) REFERENCES columns(column_id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE RESTRICT
);

-- =========================
-- Ответственные за карточки (card_assignees)
-- =========================
CREATE TABLE card_assignees (
    card_assignee_id SERIAL PRIMARY KEY,
    card_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    UNIQUE(card_id, user_id),
    FOREIGN KEY (card_id) REFERENCES cards(card_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- =========================
-- Теги (tags)
-- =========================
CREATE TABLE tags (
    tag_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    color VARCHAR(7) DEFAULT '#1976D2',
    board_id INTEGER NOT NULL,
    FOREIGN KEY (board_id) REFERENCES boards(board_id) ON DELETE CASCADE
);

-- =========================
-- Теги карточек (card_tags)
-- =========================
CREATE TABLE card_tags (
    card_tag_id SERIAL PRIMARY KEY,
    card_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    UNIQUE(card_id, tag_id),
    FOREIGN KEY (card_id) REFERENCES cards(card_id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(tag_id) ON DELETE CASCADE
);

-- =========================
-- Индексы для оптимизации
-- =========================
CREATE INDEX idx_boards_owner ON boards(owner_id);
CREATE INDEX idx_board_members_user ON board_members(user_id);
CREATE INDEX idx_board_members_board ON board_members(board_id);
CREATE INDEX idx_columns_board ON columns(board_id);
CREATE INDEX idx_cards_column ON cards(column_id);
CREATE INDEX idx_cards_created_by ON cards(created_by);
CREATE INDEX idx_card_assignees_card ON card_assignees(card_id);
CREATE INDEX idx_card_assignees_user ON card_assignees(user_id);
CREATE INDEX idx_tags_board ON tags(board_id);
CREATE INDEX idx_card_tags_card ON card_tags(card_id);
CREATE INDEX idx_card_tags_tag ON card_tags(tag_id);