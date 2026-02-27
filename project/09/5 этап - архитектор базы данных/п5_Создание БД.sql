-- Создание базы данных
CREATE DATABASE restaurant_order_system
    ENCODING 'UTF8'
    LC_COLLATE 'ru_RU.UTF-8'
    LC_CTYPE 'ru_RU.UTF-8'
    TEMPLATE template0;

COMMENT ON DATABASE restaurant_order_system IS 'Система заказа еды в ресторанах';

-- Таблица users (пользователи)
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    phone VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(255),
    name VARCHAR(100),
    birth_date DATE,
    password_hash VARCHAR(255),
    role VARCHAR(30) NOT NULL DEFAULT 'customer' 
        CHECK (role IN ('customer', 'kitchen_staff', 'menu_admin', 'manager')),
    is_phone_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE users IS 'Пользователи системы';
COMMENT ON COLUMN users.role IS 'Роль: customer, kitchen_staff, menu_admin, manager';

-- Индексы для таблицы users
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_role ON users(role);

-- Таблица verification_codes (коды подтверждения)
CREATE TABLE verification_codes (
    id SERIAL PRIMARY KEY,
    phone VARCHAR(20) NOT NULL,
    code VARCHAR(6) NOT NULL,
    purpose VARCHAR(30) NOT NULL DEFAULT 'phone_verify'
        CHECK (purpose IN ('phone_verify', 'password_reset')),
    is_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL DEFAULT (CURRENT_TIMESTAMP + INTERVAL '5 minutes')
);

COMMENT ON TABLE verification_codes IS 'Коды подтверждения для телефона';

-- Индексы для таблицы verification_codes
CREATE INDEX idx_verification_phone_code ON verification_codes(phone, code);
CREATE INDEX idx_verification_expires ON verification_codes(expires_at);

-- Таблица restaurants (рестораны)
CREATE TABLE restaurants (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    address VARCHAR(500) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    logo_url VARCHAR(500),
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    opening_hours JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE restaurants IS 'Рестораны в системе';

-- Таблица categories (категории блюд)
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    display_order INTEGER DEFAULT 0,
    icon_name VARCHAR(50),
    restaurant_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_categories_restaurant 
        FOREIGN KEY (restaurant_id) 
        REFERENCES restaurants(id) 
        ON DELETE CASCADE
);

COMMENT ON TABLE categories IS 'Категории блюд';

-- Индексы для таблицы categories
CREATE INDEX idx_categories_restaurant ON categories(restaurant_id, display_order);

-- Таблица dishes (блюда)
CREATE TABLE dishes (
    id SERIAL PRIMARY KEY,
    category_id INTEGER NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    old_price DECIMAL(10,2) CHECK (old_price >= 0 OR old_price IS NULL),
    ingredients TEXT,
    nutrition_info JSONB,
    weight_grams INTEGER,
    is_available BOOLEAN DEFAULT TRUE,
    is_recommended BOOLEAN DEFAULT FALSE,
    is_spicy BOOLEAN DEFAULT FALSE,
    popularity_score INTEGER DEFAULT 0,
    image_url VARCHAR(500),
    preparation_time_min INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_dishes_category 
        FOREIGN KEY (category_id) 
        REFERENCES categories(id) 
        ON DELETE CASCADE
);

COMMENT ON TABLE dishes IS 'Блюда в меню ресторана';

-- Индексы для таблицы dishes
CREATE INDEX idx_dishes_category ON dishes(category_id);
CREATE INDEX idx_dishes_available ON dishes(is_available);
CREATE INDEX idx_dishes_popularity ON dishes(popularity_score);

-- Функция для обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Триггер для dishes
CREATE TRIGGER update_dishes_modtime 
    BEFORE UPDATE ON dishes 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Таблица orders (заказы) - ОБНОВЛЕНО: user_id NOT NULL
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    order_number VARCHAR(50) NOT NULL UNIQUE,
    restaurant_id INTEGER NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'received', 'preparing', 'ready', 'completed', 'cancelled')),
    delivery_type VARCHAR(20) NOT NULL DEFAULT 'at_table'
        CHECK (delivery_type IN ('at_table', 'pickup')), -- ОБНОВЛЕНО: убран takeaway
    table_number VARCHAR(20),
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    customer_phone VARCHAR(20) NOT NULL,
    customer_name VARCHAR(100),
    special_instructions TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estimated_ready_at TIMESTAMP,
    
    CONSTRAINT fk_orders_user 
        FOREIGN KEY (user_id) 
        REFERENCES users(id),
        
    CONSTRAINT fk_orders_restaurant 
        FOREIGN KEY (restaurant_id) 
        REFERENCES restaurants(id) 
        ON DELETE CASCADE
);

COMMENT ON TABLE orders IS 'Заказы клиентов';

-- Триггер для orders
CREATE TRIGGER update_orders_modtime 
    BEFORE UPDATE ON orders 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Индексы для таблицы orders
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_restaurant ON orders(restaurant_id);
CREATE INDEX idx_orders_created ON orders(created_at);
CREATE INDEX idx_orders_number ON orders(order_number);

-- Таблица order_items (позиции заказа)
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    dish_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    special_instructions TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_order_items_order 
        FOREIGN KEY (order_id) 
        REFERENCES orders(id) 
        ON DELETE CASCADE,
        
    CONSTRAINT fk_order_items_dish 
        FOREIGN KEY (dish_id) 
        REFERENCES dishes(id)
);

COMMENT ON TABLE order_items IS 'Позиции (блюда) в заказе';

-- Индексы для таблицы order_items
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_dish ON order_items(dish_id);

-- Таблица order_status_history (история статусов заказа)
CREATE TABLE order_status_history (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    status VARCHAR(30) NOT NULL,
    changed_by INTEGER,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_status_history_order 
        FOREIGN KEY (order_id) 
        REFERENCES orders(id) 
        ON DELETE CASCADE,
        
    CONSTRAINT fk_status_history_changed_by 
        FOREIGN KEY (changed_by) 
        REFERENCES users(id)
);

COMMENT ON TABLE order_status_history IS 'История изменения статусов заказа';

-- Индексы для таблицы order_status_history
CREATE INDEX idx_status_history_order ON order_status_history(order_id, created_at);

-- Таблица payments (оплата)
CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    payment_method VARCHAR(30) NOT NULL DEFAULT 'card'
        CHECK (payment_method IN ('card', 'apple_pay', 'google_pay', 'cash')),
    amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
    status VARCHAR(30) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'processing', 'success', 'failed', 'refunded')),
    transaction_id VARCHAR(255) UNIQUE,
    payment_gateway VARCHAR(50),
    gateway_response JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_payments_order 
        FOREIGN KEY (order_id) 
        REFERENCES orders(id) 
        ON DELETE CASCADE
);

COMMENT ON TABLE payments IS 'Информация об оплате заказа';

-- Триггер для payments
CREATE TRIGGER update_payments_modtime 
    BEFORE UPDATE ON payments 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Индексы для таблицы payments
CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_transaction ON payments(transaction_id);

-- Таблица notifications (уведомления)
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    phone VARCHAR(20),
    verification_code_id INTEGER,
    order_id INTEGER,
    type VARCHAR(30) NOT NULL
        CHECK (type IN ('order_status', 'payment', 'verification', 'promotion', 'system')),
    channel VARCHAR(20) NOT NULL
        CHECK (channel IN ('sms', 'email', 'push', 'in_app')),
    title VARCHAR(200),
    message TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'sent', 'delivered', 'failed', 'read')),
    sent_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_notifications_user 
        FOREIGN KEY (user_id) 
        REFERENCES users(id),
        
    CONSTRAINT fk_notifications_verification_code 
        FOREIGN KEY (verification_code_id) 
        REFERENCES verification_codes(id),
        
    CONSTRAINT fk_notifications_order 
        FOREIGN KEY (order_id) 
        REFERENCES orders(id)
);

COMMENT ON TABLE notifications IS 'Уведомления для пользователей';

-- Индексы для таблицы notifications
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_phone ON notifications(phone);
CREATE INDEX idx_notifications_status ON notifications(status);

-- Таблица cart (корзина)
CREATE TABLE cart (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE,
    items JSONB NOT NULL DEFAULT '[]'::jsonb,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_cart_user 
        FOREIGN KEY (user_id) 
        REFERENCES users(id)
);

COMMENT ON TABLE cart IS 'Корзина пользователя';

-- Индексы для таблицы cart
CREATE INDEX idx_cart_user ON cart(user_id);
