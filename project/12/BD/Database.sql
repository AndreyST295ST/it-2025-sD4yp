-- ============================================================================
-- БАЗА ДАННЫХ: СЕРВИС АРЕНДЫ АВТОМОБИЛЕЙ
-- СУБД: PostgreSQL 14+
-- ============================================================================

-- Включение расширений
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. СПРАВОЧНИКИ
-- ============================================================================

-- Таблица ролей пользователей
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 2. ПОЛЬЗОВАТЕЛИ
-- ============================================================================

-- Таблица пользователей
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    middle_name VARCHAR(50),
    date_of_birth DATE,
    registration_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    role_id INTEGER NOT NULL REFERENCES roles(id),
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_phone_format CHECK (phone ~* '^\+?[0-9]{10,15}$')
);

-- Индексы для users
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_role_id ON users(role_id);
CREATE INDEX idx_users_deleted_at ON users(deleted_at);
CREATE INDEX idx_users_is_active ON users(is_active);

-- Таблица водительских прав
CREATE TABLE driver_licenses (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    license_number VARCHAR(20) NOT NULL,
    issue_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    categories VARCHAR(10) NOT NULL,
    issuing_country VARCHAR(2) DEFAULT 'RU',
    photo_front VARCHAR(255),
    photo_back VARCHAR(255),
    verification_status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected
    verified_at TIMESTAMP WITH TIME ZONE,
    verified_by INTEGER REFERENCES users(id),
    rejection_reason TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_expiry_date CHECK (expiry_date > issue_date)
);

CREATE INDEX idx_driver_licenses_user_id ON driver_licenses(user_id);
CREATE INDEX idx_driver_licenses_number ON driver_licenses(license_number);
CREATE INDEX idx_driver_licenses_expiry ON driver_licenses(expiry_date);
CREATE UNIQUE INDEX idx_unique_active_license_per_user 
    ON driver_licenses(user_id) 
    WHERE is_active = TRUE AND verification_status = 'approved';

-- Таблица способов оплаты
CREATE TABLE payment_methods (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    card_token VARCHAR(255) NOT NULL,
    last_four_digits VARCHAR(4) NOT NULL,
    card_holder VARCHAR(100) NOT NULL,
    expiry_month INTEGER NOT NULL,
    expiry_year INTEGER NOT NULL,
    card_brand VARCHAR(20), -- visa, mastercard, mir
    is_primary BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_expiry_month CHECK (expiry_month BETWEEN 1 AND 12),
    CONSTRAINT chk_expiry_year CHECK (expiry_year >= EXTRACT(YEAR FROM CURRENT_DATE))
);

CREATE INDEX idx_payment_methods_user_id ON payment_methods(user_id);
CREATE INDEX idx_payment_methods_is_primary ON payment_methods(is_primary);
CREATE UNIQUE INDEX idx_unique_primary_payment_per_user 
    ON payment_methods(user_id) 
    WHERE is_primary = TRUE AND is_active = TRUE;

-- ============================================================================
-- 3. АВТОПАРК И АВТОМОБИЛИ
-- ============================================================================

-- Таблица автопарков (для мульти-тенантности)
CREATE TABLE car_fleets (
    id SERIAL PRIMARY KEY,
    owner_id INTEGER NOT NULL REFERENCES users(id),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    car_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_car_fleets_owner_id ON car_fleets(owner_id);
CREATE INDEX idx_car_fleets_is_active ON car_fleets(is_active);

-- Таблица автомобилей
CREATE TABLE cars (
    id SERIAL PRIMARY KEY,
    fleet_id INTEGER NOT NULL REFERENCES car_fleets(id),
    vin VARCHAR(17) NOT NULL UNIQUE,
    license_plate VARCHAR(15) NOT NULL,
    brand VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    year INTEGER NOT NULL,
    color VARCHAR(30),
    transmission VARCHAR(20) NOT NULL, -- manual, automatic
    fuel_type VARCHAR(20) NOT NULL, -- gasoline, diesel, electric, hybrid
    seats_count INTEGER NOT NULL,
    price_per_day DECIMAL(10,2) NOT NULL,
    price_per_hour DECIMAL(10,2),
    deposit_amount DECIMAL(10,2) NOT NULL,
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    status VARCHAR(20) DEFAULT 'available', -- available, booked, maintenance, retired
    photos TEXT[], -- массив URL фотографий
    osago_policy_number VARCHAR(20),
    osago_expiry_date DATE,
    casco_policy_number VARCHAR(20),
    casco_expiry_date DATE,
    mileage INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_year CHECK (year BETWEEN 1900 AND EXTRACT(YEAR FROM CURRENT_DATE) + 1),
    CONSTRAINT chk_seats CHECK (seats_count > 0),
    CONSTRAINT chk_price CHECK (price_per_day >= 0),
    CONSTRAINT chk_vin_format CHECK (vin ~* '^[A-HJ-NPR-Z0-9]{17}$')
);

CREATE INDEX idx_cars_fleet_id ON cars(fleet_id);
CREATE INDEX idx_cars_vin ON cars(vin);
CREATE INDEX idx_cars_license_plate ON cars(license_plate);
CREATE INDEX idx_cars_status ON cars(status);
CREATE INDEX idx_cars_location ON cars(latitude, longitude);
CREATE INDEX idx_cars_brand_model ON cars(brand, model);
CREATE INDEX idx_cars_price ON cars(price_per_day);
CREATE INDEX idx_cars_deleted_at ON cars(deleted_at);
CREATE INDEX idx_cars_osago_expiry ON cars(osago_expiry_date);
CREATE INDEX idx_cars_casco_expiry ON cars(casco_expiry_date);

-- Таблица характеристик автомобиля (детальные)
CREATE TABLE car_specifications (
    id SERIAL PRIMARY KEY,
    car_id INTEGER NOT NULL UNIQUE REFERENCES cars(id) ON DELETE CASCADE,
    engine_power INTEGER, -- л.с.
    engine_volume DECIMAL(3,1), -- литры
    fuel_consumption DECIMAL(4,2), -- л/100км
    trunk_volume INTEGER, -- литры
    has_ac BOOLEAN DEFAULT FALSE,
    has_heated_seats BOOLEAN DEFAULT FALSE,
    has_navigation BOOLEAN DEFAULT FALSE,
    has_bluetooth BOOLEAN DEFAULT FALSE,
    has_cruise_control BOOLEAN DEFAULT FALSE,
    has_parking_sensors BOOLEAN DEFAULT FALSE,
    has_camera BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_car_specifications_car_id ON car_specifications(car_id);

-- ============================================================================
-- 4. БРОНИРОВАНИЕ И АРЕНДА
-- ============================================================================

-- Таблица бронирований
CREATE TABLE bookings (
    id SERIAL PRIMARY KEY,
    booking_number VARCHAR(20) NOT NULL UNIQUE,
    user_id INTEGER NOT NULL REFERENCES users(id),
    car_id INTEGER NOT NULL REFERENCES cars(id),
    pickup_location_address VARCHAR(255),
    pickup_latitude DECIMAL(9,6),
    pickup_longitude DECIMAL(9,6),
    dropoff_location_address VARCHAR(255),
    dropoff_latitude DECIMAL(9,6),
    dropoff_longitude DECIMAL(9,6),
    planned_start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    planned_end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    actual_start_time TIMESTAMP WITH TIME ZONE,
    actual_end_time TIMESTAMP WITH TIME ZONE,
    total_price DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending', -- pending, confirmed, active, completed, cancelled, no_show
    cancellation_reason TEXT,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    cancelled_by INTEGER REFERENCES users(id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_times CHECK (planned_end_time > planned_start_time),
    CONSTRAINT chk_actual_times CHECK (actual_end_time IS NULL OR actual_start_time IS NULL OR actual_end_time >= actual_start_time)
);

CREATE INDEX idx_bookings_user_id ON bookings(user_id);
CREATE INDEX idx_bookings_car_id ON bookings(car_id);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_planned_start ON bookings(planned_start_time);
CREATE INDEX idx_bookings_planned_end ON bookings(planned_end_time);
CREATE INDEX idx_bookings_booking_number ON bookings(booking_number);
CREATE INDEX idx_bookings_created_at ON bookings(created_at);

-- Таблица сессий аренды (фактическое использование)
CREATE TABLE rental_sessions (
    id SERIAL PRIMARY KEY,
    booking_id INTEGER NOT NULL UNIQUE REFERENCES bookings(id) ON DELETE CASCADE,
    start_mileage INTEGER NOT NULL,
    end_mileage INTEGER,
    start_fuel_level DECIMAL(5,2) NOT NULL, -- процент 0-100
    end_fuel_level DECIMAL(5,2), -- процент 0-100
    actual_start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    actual_end_time TIMESTAMP WITH TIME ZONE,
    total_duration_minutes INTEGER,
    total_distance_km INTEGER,
    fuel_consumed_liters DECIMAL(5,2),
    start_photo_url TEXT,
    end_photo_url TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_fuel_level_start CHECK (start_fuel_level BETWEEN 0 AND 100),
    CONSTRAINT chk_fuel_level_end CHECK (end_fuel_level IS NULL OR end_fuel_level BETWEEN 0 AND 100)
);

CREATE INDEX idx_rental_sessions_booking_id ON rental_sessions(booking_id);
CREATE INDEX idx_rental_sessions_actual_start ON rental_sessions(actual_start_time);
CREATE INDEX idx_rental_sessions_actual_end ON rental_sessions(actual_end_time);

-- ============================================================================
-- 5. ФИНАНСЫ
-- ============================================================================

-- Таблица платежей
CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    booking_id INTEGER NOT NULL REFERENCES bookings(id),
    payment_method_id INTEGER REFERENCES payment_methods(id),
    amount DECIMAL(10,2) NOT NULL,
    blocked_amount DECIMAL(10,2) DEFAULT 0,
    final_amount DECIMAL(10,2),
    status VARCHAR(20) DEFAULT 'pending', -- pending, processing, completed, failed, refunded, partially_refunded
    transaction_id VARCHAR(100) UNIQUE,
    payment_gateway VARCHAR(50), -- stripe, cloudpayments, sbp
    payment_date TIMESTAMP WITH TIME ZONE,
    refund_amount DECIMAL(10,2) DEFAULT 0,
    refund_date TIMESTAMP WITH TIME ZONE,
    currency VARCHAR(3) DEFAULT 'RUB',
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_amount CHECK (amount >= 0),
    CONSTRAINT chk_refund CHECK (refund_amount IS NULL OR refund_amount <= amount)
);

CREATE INDEX idx_payments_booking_id ON payments(booking_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_transaction_id ON payments(transaction_id);
CREATE INDEX idx_payments_payment_date ON payments(payment_date);
CREATE INDEX idx_payments_user_id ON payments(booking_id);

-- Таблица логов транзакций
CREATE TABLE transaction_logs (
    id SERIAL PRIMARY KEY,
    payment_id INTEGER NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL, -- created, authorized, captured, refunded, failed
    status_before VARCHAR(20),
    status_after VARCHAR(20),
    amount_before DECIMAL(10,2),
    amount_after DECIMAL(10,2),
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_transaction_logs_payment_id ON transaction_logs(payment_id);
CREATE INDEX idx_transaction_logs_action ON transaction_logs(action);
CREATE INDEX idx_transaction_logs_created_at ON transaction_logs(created_at);

-- Таблица чеков (54-ФЗ)
CREATE TABLE receipts (
    id SERIAL PRIMARY KEY,
    payment_id INTEGER NOT NULL REFERENCES payments(id),
    receipt_number VARCHAR(30) NOT NULL UNIQUE,
    fiscal_document_number VARCHAR(20),
    fiscal_date TIMESTAMP WITH TIME ZONE,
    issue_date DATE NOT NULL,
    amount_without_tax DECIMAL(10,2) NOT NULL,
    tax_amount DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    tax_system VARCHAR(20), -- osn, usn, patent
    receipt_url VARCHAR(500),
    status VARCHAR(20) DEFAULT 'pending', -- pending, sent, error
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_receipt_amounts CHECK (total_amount = amount_without_tax + tax_amount)
);

CREATE INDEX idx_receipts_payment_id ON receipts(payment_id);
CREATE INDEX idx_receipts_number ON receipts(receipt_number);
CREATE INDEX idx_receipts_issue_date ON receipts(issue_date);

-- Таблица позиций чека
CREATE TABLE receipt_items (
    id SERIAL PRIMARY KEY,
    receipt_id INTEGER NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
    description VARCHAR(255) NOT NULL,
    quantity DECIMAL(10,2) NOT NULL,
    price_per_unit DECIMAL(10,2) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    tax_rate DECIMAL(5,2) DEFAULT 20.00, -- процент НДС
    tax_amount DECIMAL(10,2),
    payment_object_type VARCHAR(50), -- commodity, service
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_item_amount CHECK (amount = quantity * price_per_unit)
);

CREATE INDEX idx_receipt_items_receipt_id ON receipt_items(receipt_id);

-- ============================================================================
-- 6. ИНЦИДЕНТЫ И ШТРАФЫ
-- ============================================================================

-- Таблица инцидентов
CREATE TABLE incidents (
    id SERIAL PRIMARY KEY,
    incident_type VARCHAR(30) NOT NULL, -- damage, accident, traffic_violation, cleaning, fuel
    description TEXT NOT NULL,
    photos TEXT[],
    reported_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolution TEXT,
    resolution_status VARCHAR(20) DEFAULT 'open', -- open, investigating, resolved, closed
    rental_session_id INTEGER REFERENCES rental_sessions(id),
    user_id INTEGER NOT NULL REFERENCES users(id),
    car_id INTEGER NOT NULL REFERENCES cars(id),
    reported_by INTEGER REFERENCES users(id),
    assigned_to INTEGER REFERENCES users(id),
    priority VARCHAR(10) DEFAULT 'medium', -- low, medium, high, critical
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_incidents_rental_session_id ON incidents(rental_session_id);
CREATE INDEX idx_incidents_user_id ON incidents(user_id);
CREATE INDEX idx_incidents_car_id ON incidents(car_id);
CREATE INDEX idx_incidents_type ON incidents(incident_type);
CREATE INDEX idx_incidents_status ON incidents(resolution_status);
CREATE INDEX idx_incidents_reported_at ON incidents(reported_at);

-- Таблица штрафов
CREATE TABLE fines (
    id SERIAL PRIMARY KEY,
    incident_id INTEGER REFERENCES incidents(id),
    rental_session_id INTEGER REFERENCES rental_sessions(id),
    fine_type VARCHAR(30) NOT NULL, -- damage, traffic_police, cleaning, late_return
    amount DECIMAL(10,2) NOT NULL,
    reason VARCHAR(255) NOT NULL,
    issue_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    due_date DATE,
    is_paid BOOLEAN DEFAULT FALSE,
    paid_at TIMESTAMP WITH TIME ZONE,
    payment_id INTEGER REFERENCES payments(id),
    traffic_police_number VARCHAR(20), -- номер постановления ГИБДД
    traffic_police_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_fine_amount CHECK (amount >= 0),
    CONSTRAINT chk_due_date CHECK (due_date IS NULL OR due_date >= issue_date::date)
);

CREATE INDEX idx_fines_incident_id ON fines(incident_id);
CREATE INDEX idx_fines_rental_session_id ON fines(rental_session_id);
CREATE INDEX idx_fines_is_paid ON fines(is_paid);
CREATE INDEX idx_fines_payment_id ON fines(payment_id);
CREATE INDEX idx_fines_due_date ON fines(due_date);

-- ============================================================================
-- 7. ОТЗЫВЫ И УВЕДОМЛЕНИЯ
-- ============================================================================

-- Таблица отзывов
CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    rental_session_id INTEGER NOT NULL UNIQUE REFERENCES rental_sessions(id),
    user_id INTEGER NOT NULL REFERENCES users(id),
    car_id INTEGER NOT NULL REFERENCES cars(id),
    rating INTEGER NOT NULL,
    comment TEXT,
    pros TEXT,
    cons TEXT,
    is_verified BOOLEAN DEFAULT TRUE,
    is_published BOOLEAN DEFAULT FALSE,
    response_text TEXT,
    response_by INTEGER REFERENCES users(id),
    response_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_rating CHECK (rating BETWEEN 1 AND 5)
);

CREATE INDEX idx_reviews_rental_session_id ON reviews(rental_session_id);
CREATE INDEX idx_reviews_user_id ON reviews(user_id);
CREATE INDEX idx_reviews_car_id ON reviews(car_id);
CREATE INDEX idx_reviews_rating ON reviews(rating);
CREATE INDEX idx_reviews_created_at ON reviews(created_at);
CREATE INDEX idx_reviews_is_published ON reviews(is_published);

-- Таблица уведомлений
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notification_type VARCHAR(30) NOT NULL, -- email, sms, push, in_app
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    delivery_status VARCHAR(20) DEFAULT 'pending', -- pending, sent, delivered, failed
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_notifications_type ON notifications(notification_type);
CREATE INDEX idx_notifications_sent_at ON notifications(sent_at);
CREATE INDEX idx_notifications_delivery_status ON notifications(delivery_status);

-- ============================================================================
-- 8. АУДИТ И ЛОГИРОВАНИЕ
-- ============================================================================

-- Таблица аудита изменений
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id INTEGER NOT NULL,
    action VARCHAR(20) NOT NULL, -- INSERT, UPDATE, DELETE
    old_data JSONB,
    new_data JSONB,
    changed_by INTEGER REFERENCES users(id),
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_log_table_name ON audit_log(table_name);
CREATE INDEX idx_audit_log_record_id ON audit_log(record_id);
CREATE INDEX idx_audit_log_action ON audit_log(action);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at);
CREATE INDEX idx_audit_log_changed_by ON audit_log(changed_by);

-- ============================================================================
-- 9. СИСТЕМНЫЕ ТАБЛИЦЫ
-- ============================================================================

-- Таблица сессий пользователей
CREATE TABLE user_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) NOT NULL UNIQUE,
    refresh_token VARCHAR(255),
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions(session_token);
CREATE INDEX idx_user_sessions_expires_at ON user_sessions(expires_at);
CREATE INDEX idx_user_sessions_is_active ON user_sessions(is_active);

-- Таблица настроек системы
CREATE TABLE system_settings (
    id SERIAL PRIMARY KEY,
    setting_key VARCHAR(100) NOT NULL UNIQUE,
    setting_value TEXT NOT NULL,
    setting_type VARCHAR(20) DEFAULT 'string', -- string, number, boolean, json
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    updated_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_system_settings_key ON system_settings(setting_key);
CREATE INDEX idx_system_settings_is_public ON system_settings(is_public);

-- ============================================================================
-- 10. ТРИГГЕРЫ И ФУНКЦИИ
-- ============================================================================

-- Функция для обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггеры для таблиц с updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cars_updated_at BEFORE UPDATE ON cars
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Функция для генерации номера брони
CREATE OR REPLACE FUNCTION generate_booking_number()
RETURNS TRIGGER AS $$
BEGIN
    NEW.booking_number := 'BK-' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDD') || '-' || LPAD(NEW.id::TEXT, 6, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER generate_booking_number_trigger BEFORE INSERT ON bookings
    FOR EACH ROW EXECUTE FUNCTION generate_booking_number();

-- ============================================================================
-- 11. НАЧАЛЬНЫЕ ДАННЫЕ
-- ============================================================================

-- Вставка ролей
INSERT INTO roles (name, description) VALUES
    ('customer', 'Клиент сервиса'),
    ('admin', 'Администратор системы'),
    ('manager', 'Менеджер автопарка'),
    ('support', 'Служба поддержки'),
    ('fleet_owner', 'Владелец автопарка');

-- Вставка системных настроек
INSERT INTO system_settings (setting_key, setting_value, setting_type, description) VALUES
    ('min_booking_duration_hours', '1', 'number', 'Минимальная длительность брони в часах'),
    ('max_booking_duration_days', '30', 'number', 'Максимальная длительность брони в днях'),
    ('cancellation_fee_percent', '10', 'number', 'Комиссия за отмену брони в процентах'),
    ('deposit_hold_days', '7', 'number', 'Дней удержания залога после аренды'),
    ('fuel_penalty_per_liter', '50', 'number', 'Штраф за литр недостающего топлива'),
    ('late_return_fee_per_hour', '500', 'number', 'Штраф за час просрочки возврата'),
    ('min_driver_license_validity_days', '90', 'number', 'Минимальный срок действия прав в днях'),
    ('support_email', 'support@carrental.ru', 'string', 'Email службы поддержки'),
    ('support_phone', '+7 (800) 000-00-00', 'string', 'Телефон службы поддержки');

-- ============================================================================
-- 12. ПРЕДСТАВЛЕНИЯ (VIEWS)
-- ============================================================================

-- Представление активных бронирований
CREATE OR REPLACE VIEW active_bookings AS
SELECT 
    b.id,
    b.booking_number,
    b.user_id,
    u.first_name || ' ' || u.last_name AS user_name,
    b.car_id,
    c.brand || ' ' || c.model AS car_name,
    c.license_plate,
    b.planned_start_time,
    b.planned_end_time,
    b.actual_start_time,
    b.actual_end_time,
    b.status,
    b.total_price,
    b.created_at
FROM bookings b
JOIN users u ON b.user_id = u.id
JOIN cars c ON b.car_id = c.id
WHERE b.status IN ('confirmed', 'active')
    AND b.is_active = TRUE
    AND c.deleted_at IS NULL;

-- Представление доступных автомобилей
CREATE OR REPLACE VIEW available_cars AS
SELECT 
    c.id,
    c.vin,
    c.license_plate,
    c.brand,
    c.model,
    c.year,
    c.color,
    c.transmission,
    c.fuel_type,
    c.seats_count,
    c.price_per_day,
    c.price_per_hour,
    c.deposit_amount,
    c.latitude,
    c.longitude,
    c.status,
    c.photos,
    cs.engine_power,
    cs.has_ac,
    cs.has_navigation,
    f.name AS fleet_name
FROM cars c
LEFT JOIN car_specifications cs ON c.id = cs.car_id
LEFT JOIN car_fleets f ON c.fleet_id = f.id
WHERE c.status = 'available'
    AND c.is_active = TRUE
    AND c.deleted_at IS NULL
    AND (c.osago_expiry_date IS NULL OR c.osago_expiry_date > CURRENT_DATE);

-- Представление финансовой статистики
CREATE OR REPLACE VIEW financial_summary AS
SELECT 
    DATE_TRUNC('month', p.payment_date) AS month,
    COUNT(*) AS total_payments,
    SUM(p.amount) AS total_amount,
    SUM(p.refund_amount) AS total_refunds,
    SUM(p.amount - p.refund_amount) AS net_amount,
    COUNT(CASE WHEN p.status = 'completed' THEN 1 END) AS completed_payments,
    COUNT(CASE WHEN p.status = 'failed' THEN 1 END) AS failed_payments
FROM payments p
WHERE p.payment_date IS NOT NULL
GROUP BY DATE_TRUNC('month', p.payment_date)
ORDER BY month DESC;

-- ============================================================================
-- 13. ПРИВИЛЕГИИ (ОПЦИОНАЛЬНО)
-- ============================================================================

-- Создание роли для приложения
-- CREATE ROLE carrental_app WITH LOGIN PASSWORD 'secure_password';
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO carrental_app;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO carrental_app;

-- ============================================================================
-- КОНЕЦ СХЕМЫ БАЗЫ ДАННЫХ
-- ============================================================================