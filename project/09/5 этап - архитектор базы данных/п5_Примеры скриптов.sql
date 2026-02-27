-- 1. ПОЛУЧЕНИЕ МЕНЮ РЕСТОРАНА
-- Для отображения меню на сайте/в приложении
SELECT 
    c.name as category_name,
    c.display_order,
    d.id as dish_id,
    d.name as dish_name,
    d.description,
    d.price,
    d.old_price,
    d.ingredients,
    d.is_available,
    d.is_recommended,
    d.is_spicy,
    d.image_url,
    d.preparation_time_min
FROM categories c
JOIN dishes d ON c.id = d.category_id
WHERE c.restaurant_id = 1  -- ID конкретного ресторана
    AND d.is_available = TRUE
ORDER BY c.display_order, d.name;

-- 2. СОЗДАНИЕ НОВОГО ЗАКАЗА С ПОЗИЦИЯМИ
-- Для процесса оформления заказа
WITH new_order AS (
    INSERT INTO orders (
        user_id,
        order_number,
        restaurant_id,
        status,
        delivery_type,
        table_number,
        total_amount,
        customer_phone,
        customer_name
    ) VALUES (
        (SELECT id FROM users WHERE phone = '+79161111111'),
        'ORD1-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || 
            LPAD((COALESCE((SELECT MAX(SUBSTRING(order_number FROM '\d+$')::INT) 
                           FROM orders 
                           WHERE order_number LIKE 'ORD1-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-%'), 0) + 1)::text, 3, '0'),
        1,
        'pending',
        'at_table',
        '10',
        0,  -- Временно 0
        '+79161111111',
        'Иван Иванов'
    )
    RETURNING id
)
INSERT INTO order_items (order_id, dish_id, quantity, unit_price, special_instructions)
SELECT 
    no.id,
    UNNEST(ARRAY[1, 4]) as dish_id,  -- ID блюд из корзины
    UNNEST(ARRAY[1, 2]) as quantity,
    UNNEST(ARRAY[450.00, 320.00]) as unit_price,
    UNNEST(ARRAY['', 'Без лука']) as special_instructions
FROM new_order no
RETURNING order_id;

-- 3. ОБНОВЛЕНИЕ СУММЫ ЗАКАЗА ПОСЛЕ ДОБАВЛЕНИЯ ПОЗИЦИЙ
UPDATE orders o
SET total_amount = (
    SELECT SUM(oi.quantity * oi.unit_price)
    FROM order_items oi
    WHERE oi.order_id = o.id
),
updated_at = CURRENT_TIMESTAMP
WHERE o.id = (SELECT MAX(id) FROM orders WHERE customer_phone = '+79161111111');

-- 4. ПОЛУЧЕНИЕ АКТИВНЫХ ЗАКАЗОВ ДЛЯ КУХНИ
-- Для отображения на кухонном терминале
SELECT 
    o.id,
    o.order_number,
    o.table_number,
    o.delivery_type,
    o.customer_name,
    o.special_instructions as order_notes,
    o.created_at,
    o.estimated_ready_at,
    json_agg(
        json_build_object(
            'dish_id', d.id,
            'dish_name', d.name,
            'quantity', oi.quantity,
            'special_instructions', oi.special_instructions
        ) ORDER BY oi.id
    ) as items
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
JOIN dishes d ON oi.dish_id = d.id
WHERE o.restaurant_id = 1
    AND o.status IN ('received', 'preparing')
    AND EXISTS (
        SELECT 1 FROM payments p 
        WHERE p.order_id = o.id 
        AND p.status = 'success'
    )
GROUP BY o.id, o.order_number, o.table_number, o.delivery_type,
         o.customer_name, o.special_instructions, o.created_at, 
         o.estimated_ready_at
ORDER BY o.created_at;

-- 5. ИЗМЕНЕНИЕ СТАТУСА ЗАКАЗА (БИЗНЕС-ПРАВИЛО)
-- Для сотрудников кухни и системы
BEGIN;

-- Проверяем, что оплата успешна
DO $$
DECLARE
    payment_status text;
BEGIN
    SELECT status INTO payment_status 
    FROM payments 
    WHERE order_id = 1 
    ORDER BY created_at DESC 
    LIMIT 1;
    
    IF payment_status != 'success' THEN
        RAISE EXCEPTION 'Заказ не оплачен';
    END IF;
END $$;

-- Обновляем статус заказа
UPDATE orders 
SET status = 'preparing',
    updated_at = CURRENT_TIMESTAMP
WHERE id = 1 AND status = 'received';

-- Записываем в историю
INSERT INTO order_status_history (order_id, status, changed_by, notes)
VALUES (1, 'preparing', (SELECT id FROM users WHERE phone = '+79163333333'), 
        'Начали готовить');

-- Отправляем уведомление
INSERT INTO notifications (user_id, phone, order_id, type, channel, 
                          message, status)
SELECT 
    user_id,
    customer_phone,
    id,
    'order_status',
    'sms',
    'Ваш заказ ' || order_number || ' начали готовить',
    'pending'
FROM orders WHERE id = 1;

COMMIT;

-- 6. ПРОВЕРКА И ПОДТВЕРЖДЕНИЕ ТЕЛЕФОНА
-- Для процесса верификации
WITH valid_code AS (
    SELECT id, phone
    FROM verification_codes
    WHERE phone = '+79165555555'
        AND code = '123456'
        AND purpose = 'phone_verify'
        AND is_used = FALSE
        AND expires_at > CURRENT_TIMESTAMP
    LIMIT 1
)
UPDATE verification_codes vc
SET is_used = TRUE
FROM valid_code v
WHERE vc.id = v.id
RETURNING vc.id, vc.phone;

-- Обновляем статус пользователя
UPDATE users 
SET is_phone_verified = TRUE,
    name = 'Новый Пользователь'  -- Можно запросить у пользователя
WHERE phone = '+79165555555';

-- 7. ПОЛУЧЕНИЕ ИСТОРИИ ЗАКАЗОВ ПОЛЬЗОВАТЕЛЯ
SELECT 
    o.order_number,
    o.status,
    r.name as restaurant_name,
    o.total_amount,
    o.created_at,
    o.delivery_type,
    o.table_number,
    (
        SELECT json_agg(
            json_build_object(
                'status', osh.status,
                'changed_at', osh.created_at,
                'changed_by', u.name,
                'notes', osh.notes
            ) ORDER BY osh.created_at
        )
        FROM order_status_history osh
        LEFT JOIN users u ON osh.changed_by = u.id
        WHERE osh.order_id = o.id
    ) as status_history,
    (
        SELECT json_agg(
            json_build_object(
                'dish_name', d.name,
                'quantity', oi.quantity,
                'unit_price', oi.unit_price,
                'special_instructions', oi.special_instructions
            )
        )
        FROM order_items oi
        JOIN dishes d ON oi.dish_id = d.id
        WHERE oi.order_id = o.id
    ) as items
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.id
WHERE o.user_id = (SELECT id FROM users WHERE phone = '+79161111111')
ORDER BY o.created_at DESC;

-- 8. ОПЛАТА ЗАКАЗА (БИЗНЕС-ПРАВИЛО)
-- При успешной оплате
BEGIN;

-- Создаем запись об оплате
INSERT INTO payments (order_id, payment_method, amount, status, 
                     transaction_id, payment_gateway)
VALUES (1, 'card', 1190.00, 'success', 'txn_' || gen_random_uuid(), 'stripe');

-- Обновляем статус заказа
UPDATE orders 
SET status = 'received',
    updated_at = CURRENT_TIMESTAMP
WHERE id = 1 AND status = 'pending';

-- Записываем в историю
INSERT INTO order_status_history (order_id, status, notes)
VALUES (1, 'received', 'Оплата успешно завершена');

COMMIT;

-- 9. ДОБАВЛЕНИЕ В КОРЗИНУ
-- Для авторизованных пользователей
INSERT INTO cart (user_id, items, updated_at)
VALUES (
    (SELECT id FROM users WHERE phone = '+79161111111'),
    '[{"dish_id": 1, "quantity": 2}, {"dish_id": 3, "quantity": 1}]'::jsonb,
    CURRENT_TIMESTAMP
)
ON CONFLICT (user_id) 
DO UPDATE SET 
    items = EXCLUDED.items,
    updated_at = EXCLUDED.updated_at;

-- 10. СТАТИСТИКА ПО ЗАКАЗАМ (ДЛЯ АДМИНИСТРАЦИИ)
SELECT 
    DATE(o.created_at) as date,
    COUNT(*) as total_orders,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_order_value,
    COUNT(DISTINCT o.user_id) as unique_customers,
    SUM(CASE WHEN o.status = 'completed' THEN 1 ELSE 0 END) as completed_orders,
    SUM(CASE WHEN o.status = 'cancelled' THEN 1 ELSE 0 END) as cancelled_orders
FROM orders o
WHERE o.restaurant_id = 1
    AND o.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(o.created_at)
ORDER BY date DESC;

-- 11. ПОИСК ПОПУЛЯРНЫХ БЛЮД
SELECT 
    d.id,
    d.name,
    c.name as category,
    d.price,
    COUNT(oi.id) as times_ordered,
    SUM(oi.quantity) as total_quantity,
    RANK() OVER (ORDER BY COUNT(oi.id) DESC) as popularity_rank
FROM dishes d
JOIN categories c ON d.category_id = c.id
LEFT JOIN order_items oi ON d.id = oi.dish_id
LEFT JOIN orders o ON oi.order_id = o.id
WHERE c.restaurant_id = 1
    AND o.created_at >= CURRENT_DATE - INTERVAL '30 days'
    AND o.status = 'completed'
GROUP BY d.id, d.name, c.name, d.price
ORDER BY times_ordered DESC
LIMIT 10;

-- 12. ПРОВЕРКА ДОСТУПНОСТИ БЛЮД ПЕРЕД СОЗДАНИЕМ ЗАКАЗА
SELECT 
    d.id,
    d.name,
    d.is_available,
    CASE 
        WHEN d.is_available = FALSE THEN 'Блюдо недоступно для заказа'
        ELSE 'Доступно'
    END as status_message
FROM dishes d
WHERE d.id IN (1, 2, 3, 4)  -- ID блюд из корзины
ORDER BY d.is_available DESC;

-- 13. ОЧИСТКА СТАРЫХ ДАННЫХ (АВТОМАТИЗАЦИЯ)
-- Удаление использованных кодов подтверждения старше 1 дня
DELETE FROM verification_codes 
WHERE is_used = TRUE 
    AND created_at < CURRENT_TIMESTAMP - INTERVAL '1 day';

-- Удаление неиспользованных кодов с истекшим сроком
DELETE FROM verification_codes 
WHERE is_used = FALSE 
    AND expires_at < CURRENT_TIMESTAMP;

-- 14. ГЕНЕРАЦИЯ НОМЕРА ЗАКАЗА (ФУНКЦИЯ)
CREATE OR REPLACE FUNCTION generate_order_number(restaurant_id INTEGER)
RETURNS VARCHAR(50) AS $$
DECLARE
    restaurant_prefix VARCHAR(10);
    date_part VARCHAR(8);
    sequence_num INTEGER;
    new_order_number VARCHAR(50);
BEGIN
    -- Префикс ресторана
    restaurant_prefix := 'ORD' || restaurant_id;
    
    -- Дата в формате YYYYMMDD
    date_part := TO_CHAR(CURRENT_DATE, 'YYYYMMDD');
    
    -- Получаем следующий номер последовательности
    SELECT COALESCE(
        MAX(CAST(SUBSTRING(order_number FROM '^ORD\d+-(\d+)-(\d+)$') AS INTEGER)), 
        0
    ) + 1
    INTO sequence_num
    FROM orders
    WHERE order_number LIKE restaurant_prefix || '-' || date_part || '-%';
    
    -- Формируем номер заказа
    new_order_number := restaurant_prefix || '-' || date_part || '-' || 
                       LPAD(sequence_num::text, 3, '0');
    
    RETURN new_order_number;
END;
$$ LANGUAGE plpgsql;

-- 15. ПРОЦЕДУРА ОФОРМЛЕНИЯ ЗАКАЗА ОТ ГОСТЯ
CREATE OR REPLACE PROCEDURE create_guest_order(
    p_phone VARCHAR(20),
    p_code VARCHAR(6),
    p_restaurant_id INTEGER,
    p_delivery_type VARCHAR(20),
    p_table_number VARCHAR(20),
    p_customer_name VARCHAR(100),
    p_dish_items JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INTEGER;
    v_order_id INTEGER;
    v_order_number VARCHAR(50);
    v_code_valid BOOLEAN;
    v_total_amount DECIMAL(10,2) := 0;
    dish_item JSONB;
BEGIN
    -- Проверяем код подтверждения
    SELECT EXISTS (
        SELECT 1 FROM verification_codes 
        WHERE phone = p_phone 
            AND code = p_code 
            AND purpose = 'phone_verify'
            AND is_used = FALSE 
            AND expires_at > CURRENT_TIMESTAMP
    ) INTO v_code_valid;
    
    IF NOT v_code_valid THEN
        RAISE EXCEPTION 'Неверный или просроченный код подтверждения';
    END IF;
    
    -- Помечаем код как использованный
    UPDATE verification_codes 
    SET is_used = TRUE 
    WHERE phone = p_phone 
        AND code = p_code 
        AND is_used = FALSE;
    
    -- Создаем/получаем пользователя
    INSERT INTO users (phone, role, is_phone_verified)
    VALUES (p_phone, 'customer', TRUE)
    ON CONFLICT (phone) 
    DO UPDATE SET is_phone_verified = TRUE
    RETURNING id INTO v_user_id;
    
    -- Обновляем имя если предоставлено
    IF p_customer_name IS NOT NULL THEN
        UPDATE users 
        SET name = p_customer_name 
        WHERE id = v_user_id;
    END IF;
    
    -- Генерируем номер заказа
    v_order_number := generate_order_number(p_restaurant_id);
    
    -- Рассчитываем общую сумму
    FOR dish_item IN SELECT * FROM jsonb_array_elements(p_dish_items)
    LOOP
        v_total_amount := v_total_amount + 
            (dish_item->>'quantity')::INTEGER * 
            (SELECT price FROM dishes WHERE id = (dish_item->>'dish_id')::INTEGER);
    END LOOP;
    
    -- Создаем заказ
    INSERT INTO orders (
        user_id, order_number, restaurant_id, status, 
        delivery_type, table_number, total_amount, 
        customer_phone, customer_name
    ) VALUES (
        v_user_id, v_order_number, p_restaurant_id, 'pending',
        p_delivery_type, p_table_number, v_total_amount,
        p_phone, p_customer_name
    )
    RETURNING id INTO v_order_id;
    
    -- Добавляем позиции заказа
    INSERT INTO order_items (order_id, dish_id, quantity, unit_price, special_instructions)
    SELECT 
        v_order_id,
        (dish_item->>'dish_id')::INTEGER,
        (dish_item->>'quantity')::INTEGER,
        (SELECT price FROM dishes WHERE id = (dish_item->>'dish_id')::INTEGER),
        COALESCE(dish_item->>'special_instructions', '')
    FROM jsonb_array_elements(p_dish_items) as dish_item;
    
    -- Возвращаем номер заказа
    RAISE NOTICE 'Заказ создан: %', v_order_number;
END;
$$;