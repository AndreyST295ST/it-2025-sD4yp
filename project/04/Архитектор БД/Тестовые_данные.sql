BEGIN;

-- Пользователи (добавлен администратор)
INSERT INTO users (id, name, email, phone, password_hash, is_admin) VALUES
(1, 'Иван Петров',      'ivan@securehome.ru',  '+7-900-111-22-33', 'hash_ivan',  FALSE),
(2, 'Анна Смирнова',    'anna@securehome.ru',  '+7-900-444-55-66', 'hash_anna',  FALSE),
(3, 'Администратор',    'admin@securehome.ru', '+7-900-000-00-00', 'hash_admin', TRUE);

-- Категории товаров
INSERT INTO product_categories (id, name, description) VALUES
(1, 'Видеонаблюдение', 'Камеры, регистраторы, ПО'),
(2, 'Сигнализации',    'Централи, сирены, комплекты'),
(3, 'Датчики и периферия', 'Датчики, БП, кабели');

-- Товары
INSERT INTO products (id, sku, name, product_type, price, availability_status, category_id) VALUES
(1, 'CAM-DS2',      'IP-камера Hikvision DS-2CD2043',   'Камера',           6990.00,  'in_stock', 1),
(2, 'NVR-8CH',      '8-канальный NVR Hikvision',        'Видеорегистратор', 12990.00, 'in_stock', 1),
(3, 'ALR-AJAX-KIT', 'Ajax StarterKit (Hub2, датчики)',  'Комплект',         25990.00, 'in_stock', 2),
(4, 'SENS-MAG',     'Магнитный датчик двери',           'Датчик',           990.00,   'in_stock', 3),
(5, 'SIREN-EXT',    'Уличная сирена AJAX StreetSiren',  'Сирена',           3990.00,  'preorder', 2),
(6, 'UPS-12V-3A',   'Источник питания 12В 3А',          'Блок питания',     1490.00,  'in_stock', 3);

-- Адреса
INSERT INTO addresses (id, city, street, house, apartment, comment) VALUES
(1, 'Москва', 'Тверская', '10', '15',  'Квартира клиента'),
(2, 'Москва', 'Ленина',   '5',  '203', 'Офис клиента'),
(3, 'Москва', 'Новая',    '12', '7',   'Адрес доставки заказа 1'),
(4, 'Москва', 'Мира',     '45', '120', 'Адрес доставки заказа 2');

-- Объекты сервиса
INSERT INTO service_objects (id, name, object_type, area, address_id) VALUES
(1, 'Квартира Петровых', 'Квартира', 56.0, 1),
(2, 'Офис WebProtect',   'Офис',     180.0, 2);

-- Сервисные заявки
INSERT INTO service_requests (id, number, type, status, description, service_object_id) VALUES
(1, 'SR-0001', 'Установка', 'Новая',     'Монтаж комплекта сигнализации Ajax', 1),
(2, 'SR-0002', 'Ремонт',    'В работе',  'Неисправность IP-камеры в серверной', 2);

-- Специализации заявок
INSERT INTO install_requests (id, service_request_id, date) VALUES
(1, 1, '2025-12-15');

INSERT INTO repair_requests (id, service_request_id, date) VALUES
(1, 2, '2025-12-18');

-- Сметы
INSERT INTO estimates (id, service_request_id, labor_cost, material_cost, status) VALUES
(1, 1, 8000.00, 3500.00, 'Согласована'),
(2, 2, 4500.00, 2000.00, 'Ожидает согласования');

-- Уведомления
INSERT INTO notifications (id, service_request_id, text, sent_at) VALUES
(1, 1, 'Заявка принята в работу',               '2025-12-10 10:05:00'),
(2, 2, 'Мастер назначен на 18.12',              '2025-12-11 14:20:00'),
(3, 1, 'Выезд мастера запланирован на 15.12',   '2025-12-12 09:00:00');

-- Корзины
INSERT INTO carts (id, user_id, created_at) VALUES
(1, 1, '2025-12-10 09:30:00'),
(2, 2, '2025-12-10 10:00:00');

-- Позиции корзин
INSERT INTO cart_items (id, cart_id, product_id, quantity, price) VALUES
(1, 1, 3, 1, 25990.00),
(2, 1, 4, 2,   990.00),
(3, 1, 1, 1,  6990.00);

-- Заказы (привязаны к сервисным заявкам)
INSERT INTO orders (id, number, created_at, status, total_amount, service_request_id, address_id) VALUES
(1, 'ORD-0001', '2025-12-12 11:00:00', 'Оплачен частично', 11500.00, 1, 3),
(2, 'ORD-0002', '2025-12-12 11:30:00', 'Ожидает оплаты',     6500.00, 2, 4);

-- Доставки
INSERT INTO deliveries (id, order_id, address_id, type, cost, eta) VALUES
(1, 1, 3, 'Курьер',    600.00, '2025-12-14 18:00:00'),
(2, 2, 4, 'Самовывоз',   0.00, '2025-12-19 12:00:00');

-- Платежи
INSERT INTO payments (id, order_id, method, amount, status, paid_at) VALUES
(1, 1, 'Карта',  5000.00, 'Зачислено', '2025-12-12 12:10:00'),
(2, 1, 'Онлайн', 6500.00, 'Зачислено', '2025-12-15 19:45:00'),
(3, 2, 'Карта',  1000.00, 'Ожидает',   NULL);

COMMIT;