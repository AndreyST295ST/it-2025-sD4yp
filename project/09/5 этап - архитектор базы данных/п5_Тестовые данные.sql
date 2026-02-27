BEGIN;

-- 1. Добавляем рестораны (порядок заполнения 1)
INSERT INTO restaurants (name, address, phone, description, opening_hours) VALUES
('Итальянский дворик', 'ул. Пушкина, 10', '+79161234567', 'Ресторан итальянской кухни', '{"monday": "10:00-23:00", "tuesday": "10:00-23:00", "wednesday": "10:00-23:00", "thursday": "10:00-23:00", "friday": "10:00-00:00", "saturday": "11:00-00:00", "sunday": "11:00-22:00"}'),
('Суши Бар', 'пр. Ленина, 25', '+79162345678', 'Японская кухня и суши', '{"monday": "11:00-22:00", "tuesday": "11:00-22:00", "wednesday": "11:00-22:00", "thursday": "11:00-22:00", "friday": "11:00-23:00", "saturday": "12:00-23:00", "sunday": "12:00-21:00"}');

-- 2. Добавляем категории для ресторанов (порядок заполнения 2)
INSERT INTO categories (name, description, display_order, restaurant_id) VALUES
-- Ресторан 1
('Пицца', 'Итальянская пицца на тонком тесте', 1, 1),
('Паста', 'Свежая паста с различными соусами', 2, 1),
('Салаты', 'Свежие салаты', 3, 1),
('Напитки', 'Напитки и вина', 4, 1),
('Десерты', 'Итальянские десерты', 5, 1),
-- Ресторан 2
('Суши и роллы', 'Японские суши и роллы', 1, 2),
('Закуски', 'Японские закуски', 2, 2),
('Горячие блюда', 'Теппура и другие горячие блюда', 3, 2),
('Напитки', 'Напитки', 4, 2);

-- 3. Добавляем блюда в меню (порядок заполнения 3)
INSERT INTO dishes (category_id, name, description, price, ingredients, is_available, is_recommended) VALUES
-- Пиццы (ресторан 1)
(1, 'Маргарита', 'Классическая пицца с томатным соусом, моцареллой и базиликом', 450.00, 'Тесто, томатный соус, сыр моцарелла, свежий базилик', TRUE, TRUE),
(1, 'Пепперони', 'Пицца с острой салями пепперони и сыром', 550.00, 'Тесто, томатный соус, сыр моцарелла, пепперони', TRUE, TRUE),
-- Паста (ресторан 1)
(2, 'Карбонара', 'Спагетти с беконом, яйцом и пармезаном', 420.00, 'Спагетти, бекон, яйцо, пармезан', TRUE, FALSE),
-- Салаты (ресторан 1)
(3, 'Греческий', 'Салат с фетой, огурцами и оливками', 320.00, 'Помидоры, огурцы, сыр фета, оливки', TRUE, TRUE),
-- Суши (ресторан 2)
(6, 'Филадельфия', 'Ролл с лососем и сливочным сыром', 420.00, 'Рис, нори, лосось, сыр сливочный', TRUE, TRUE),
(6, 'Калифорния', 'Ролл с крабом и авокадо', 380.00, 'Рис, нори, краб, авокадо', TRUE, FALSE);

-- 4. Добавляем пользователей (порядок заполнения 4)
-- Сначала сотрудников
INSERT INTO users (phone, email, name, role, password_hash, is_phone_verified) VALUES
-- Сотрудник кухни
('+79163333333', 'chef@italian.com', 'Алексей Шеф', 'kitchen_staff', '$2a$10$N9qo8uLOickgx2ZMRZoMy.Mr8c6LwBW1z7X5bJX5Bq3C1O9Vp1J6a', TRUE),
-- Администратор меню
('+79164444444', 'admin@italian.com', 'Мария Админ', 'menu_admin', '$2a$10$N9qo8uLOickgx2ZMRZoMy.Mr8c6LwBW1z7X5bJX5Bq3C1O9Vp1J6a', TRUE),
-- Клиенты
('+79161111111', 'ivan@mail.com', 'Иван Иванов', 'customer', NULL, TRUE),
('+79162222222', 'petr@mail.com', 'Петр Петров', 'customer', NULL, TRUE),
-- Гость (пока не подтвердил телефон)
('+79165555555', NULL, NULL, 'customer', NULL, FALSE);

-- 5. Добавляем коды подтверждения (порядок заполнения 5)
INSERT INTO verification_codes (phone, code, purpose, expires_at) VALUES
('+79165555555', '123456', 'phone_verify', NOW() + INTERVAL '5 minutes'),
('+79161111111', '654321', 'password_reset', NOW() + INTERVAL '5 minutes');

-- 6. Создаем заказы (порядок заполнения 6)
-- Сначала нужно создать пользователя-гостя для заказа
INSERT INTO users (phone, role, is_phone_verified) VALUES
('+79167777777', 'customer', TRUE)
ON CONFLICT (phone) DO NOTHING;

-- Получаем ID созданного пользователя
WITH new_user AS (
    SELECT id FROM users WHERE phone = '+79167777777'
)
INSERT INTO orders (user_id, order_number, restaurant_id, status, delivery_type, 
                   table_number, total_amount, customer_phone, customer_name) VALUES
-- Заказ 1: Иван Иванов
((SELECT id FROM users WHERE phone = '+79161111111'), 'ORD1-20241201-001', 1, 'completed', 'at_table', '5', 870.00, '+79161111111', 'Иван Иванов'),
-- Заказ 2: Петр Петров
((SELECT id FROM users WHERE phone = '+79162222222'), 'ORD1-20241201-002', 1, 'ready', 'pickup', NULL, 920.00, '+79162222222', 'Петр Петров'),
-- Заказ 3: Гость
((SELECT id FROM users WHERE phone = '+79167777777'), 'ORD1-20241201-003', 1, 'pending', 'at_table', '8', 450.00, '+79167777777', 'Гость');

-- 7. Добавляем позиции в заказы
INSERT INTO order_items (order_id, dish_id, quantity, unit_price) VALUES
-- Заказ 1
(1, 1, 1, 450.00),  -- Маргарита
(1, 4, 1, 320.00),  -- Греческий салат
(1, 3, 1, 420.00),  -- Карбонара (итого должно быть 1190, но в заказе указано 870 - исправим ниже)
-- Заказ 2
(2, 2, 1, 550.00),  -- Пепперони
(2, 1, 1, 450.00),  -- Маргарита (итого 1000, но указано 920)
-- Заказ 3
(3, 1, 1, 450.00);  -- Маргарита

-- Исправляем суммы заказов согласно позициям
UPDATE orders 
SET total_amount = (
    SELECT SUM(quantity * unit_price) 
    FROM order_items 
    WHERE order_id = orders.id
)
WHERE id IN (1, 2, 3);

-- 8. Добавляем оплаты (порядок заполнения 7)
INSERT INTO payments (order_id, payment_method, amount, status, transaction_id) VALUES
(1, 'card', 1190.00, 'success', 'txn_1234567890'),
(2, 'apple_pay', 1000.00, 'success', 'txn_2345678901'),
(3, 'card', 450.00, 'pending', NULL);

-- 9. Добавляем историю статусов (порядок заполнения 8)
INSERT INTO order_status_history (order_id, status, changed_by, notes) VALUES
(1, 'pending', NULL, 'Заказ создан'),
(1, 'received', (SELECT id FROM users WHERE phone = '+79163333333'), 'Оплата подтверждена'),
(1, 'preparing', (SELECT id FROM users WHERE phone = '+79163333333'), 'Начали готовить'),
(1, 'ready', (SELECT id FROM users WHERE phone = '+79163333333'), 'Заказ готов'),
(1, 'completed', NULL, 'Заказ выдан клиенту'),
(2, 'pending', NULL, 'Заказ создан'),
(2, 'received', (SELECT id FROM users WHERE phone = '+79163333333'), 'Оплата подтверждена'),
(2, 'preparing', (SELECT id FROM users WHERE phone = '+79163333333'), 'На кухне'),
(2, 'ready', (SELECT id FROM users WHERE phone = '+79163333333'), 'Готов к выдаче'),
(3, 'pending', NULL, 'Ожидание подтверждения телефона');

-- 10. Добавляем уведомления (порядок заполнения 9)
INSERT INTO notifications (user_id, phone, verification_code_id, order_id, 
                          type, channel, message, status, sent_at) VALUES
((SELECT id FROM users WHERE phone = '+79165555555'), '+79165555555', 
 (SELECT id FROM verification_codes WHERE phone = '+79165555555' ORDER BY id DESC LIMIT 1),
 NULL, 'verification', 'sms', 'Ваш код подтверждения: 123456', 'sent', NOW()),
((SELECT id FROM users WHERE phone = '+79161111111'), '+79161111111', 
 NULL, 1, 'order_status', 'in_app', 'Ваш заказ ORD1-20241201-001 готов!', 'read', NOW() - INTERVAL '30 minutes');

-- 11. Добавляем корзины (порядок заполнения 10)
INSERT INTO cart (user_id, items) VALUES
((SELECT id FROM users WHERE phone = '+79161111111'), 
 '[{"dish_id": 2, "quantity": 1, "special_instructions": "Без лука"}, {"dish_id": 5, "quantity": 2}]'),
((SELECT id FROM users WHERE phone = '+79162222222'), 
 '[{"dish_id": 6, "quantity": 1, "special_instructions": "Спайси соус отдельно"}]')
ON CONFLICT (user_id) DO NOTHING;

COMMIT;