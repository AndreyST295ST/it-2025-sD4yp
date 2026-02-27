-- Эти запросы работают корректно только после установки secureshop.user_id
-- и предполагают, что пользователь уже аутентифицирован.
-- Предполагается наличие RLS-политик и функции `current_user_id()`.

-- 1. Профиль клиента (выполняется от лица клиента, user_id = 1)
SET secureshop.user_id = '1';
SELECT
    u.name  AS "Name",
    u.email AS "Email",
    u.phone AS "Phone",
    (
      SELECT COUNT(*)
      FROM cart_items ci
      JOIN carts c ON ci.cart_id = c.id
      WHERE c.user_id = current_user_id()
    ) AS "Cart items",
    (
      SELECT COALESCE(SUM(ci.quantity * ci.price), 0)
      FROM cart_items ci
      JOIN carts c ON ci.cart_id = c.id
      WHERE c.user_id = current_user_id()
    ) AS "Cart total",
    (SELECT COUNT(*) FROM orders) AS "Orders count"  -- RLS вернёт только заказы текущего пользователя
FROM users u
WHERE u.id = current_user_id();

-- 2. Моя корзина (только свои позиции)
SELECT
    p.sku,
    p.name,
    ci.quantity,
    ci.price AS unit_price,
    ci.quantity * ci.price AS line_total
FROM carts c
JOIN cart_items ci ON ci.cart_id = c.id
JOIN products p    ON p.id = ci.product_id
WHERE c.user_id = current_user_id()
ORDER BY p.name;

-- 3. История заказов (только свои)
SET secureshop.user_id = '1';
SELECT
    o.number,
    o.status,
    o.total_amount,
    o.created_at
FROM orders o
ORDER BY o.created_at DESC
LIMIT 10;  -- RLS вернёт только записи текущего пользователя

-- 4. Детали последнего заказа: оплата и доставка (только свои)
SET secureshop.user_id = '1';
WITH last_order AS (
  SELECT id, number, status, total_amount, created_at
  FROM orders
  ORDER BY created_at DESC
  LIMIT 1  -- RLS ограничит к "своему" последнему заказу
)
SELECT
  lo.number,
  lo.status,
  lo.total_amount,
  COALESCE(SUM(p.amount) FILTER (WHERE p.status = 'Зачислено'), 0) AS paid_amount,
  lo.total_amount - COALESCE(SUM(p.amount) FILTER (WHERE p.status = 'Зачислено'), 0) AS balance_due,
  d.type  AS delivery_type,
  d.cost  AS delivery_cost,
  d.eta   AS delivery_eta,
  a.city || ', ' || a.street || ' ' || a.house ||
    COALESCE(' кв. ' || a.apartment, '') AS delivery_address
FROM last_order lo
LEFT JOIN payments   p ON p.order_id = lo.id
LEFT JOIN deliveries d ON d.order_id = lo.id
LEFT JOIN addresses  a ON a.id = COALESCE(d.address_id, NULL)  -- если у доставки не указан адрес, RLS адрес будет недоступен
GROUP BY lo.number, lo.status, lo.total_amount, d.type, d.cost, d.eta, a.city, a.street, a.house, a.apartment;

-- 5. Мои сервисные заявки (только свои объекты)
SET secureshop.user_id = '1';
SELECT
  sr.number,
  sr.type,
  sr.status,
  so.name        AS service_object,
  sr.description AS details
FROM service_requests sr
JOIN service_objects so ON so.id = sr.service_object_id
ORDER BY sr.id DESC;  -- RLS вернёт только заявки текущего пользователя

-- 6. Уведомления по сервисным заявкам (только свои)
SET secureshop.user_id = '1';
SELECT
  sr.number AS request_number,
  n.text    AS message,
  n.sent_at
FROM notifications n
JOIN service_requests sr ON sr.id = n.service_request_id
WHERE n.sent_at >= now() - interval '30 days'
ORDER BY n.sent_at DESC;  -- RLS ограничит до заявок пользователя

-- 7. Сводка по сметам (только свои заявки)
SET secureshop.user_id = '1';
SELECT
  sr.number AS request_number,
  e.status,
  e.labor_cost,
  e.material_cost,
  (e.labor_cost + e.material_cost) AS estimate_total
FROM estimates e
JOIN service_requests sr ON sr.id = e.service_request_id
ORDER BY e.id DESC;  -- RLS ограничит до своих заявок

-- 8. Поиск по каталогу товаров (доступно всем аутентифицированным)
SET secureshop.user_id = '1';
SELECT
  p.sku,
  p.name,
  p.price,
  p.availability_status,
  pc.name AS category
FROM products p
JOIN product_categories pc ON pc.id = p.category_id
WHERE p.availability_status IN ('in_stock', 'preorder')
  AND (p.name ILIKE '%Ajax%' OR p.sku ILIKE '%AJAX%')
ORDER BY p.price ASC
LIMIT 10;

-- 9. Метрики для менеджера/админа (user_id = 3)
SET secureshop.user_id = '3';
-- Продажи за 7 дней: количество заказов, выручка (зачисленные платежи), средний чек
SELECT
  COUNT(DISTINCT o.id) AS orders_count,
  COALESCE(SUM(p.amount) FILTER (WHERE p.status = 'Зачислено'), 0) AS revenue_received,
  ROUND(AVG(o.total_amount), 2) AS avg_order_amount
FROM orders o
LEFT JOIN payments p ON p.order_id = o.id
WHERE o.created_at >= now() - interval '7 days';  -- RLS разрешит только администратору/менеджеру

-- 10. Управление каталогом (только администратор может добавлять/удалять товары)
SET secureshop.user_id = '3';
-- Добавить товар
INSERT INTO products (sku, name, product_type, price, availability_status, category_id)
VALUES ('KIT-LITE', 'Базовый комплект охраны', 'Комплект', 15990.00, 'in_stock', 2);

-- Изменить цену
UPDATE products
SET price = price * 0.95
WHERE sku = 'KIT-LITE';

-- Удалить товар
DELETE FROM products
WHERE sku = 'KIT-LITE';  -- RLS пропустит только если текущий пользователь админ (users.is_admin = TRUE)