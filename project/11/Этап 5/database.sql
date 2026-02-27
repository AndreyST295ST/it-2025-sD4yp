-- 1. Настройка окружения
CREATE SCHEMA IF NOT EXISTS crypto_arbitrage;

-- Активация pgcrypto для генерации UUID и хеширования
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;

-- ==========================================
-- БЛОК ПОЛЬЗОВАТЕЛЕЙ И ДОСТУПА
-- ==========================================

-- Таблица пользователей
CREATE TABLE crypto_arbitrage.users (
    user_id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(100),
    role VARCHAR(20) NOT NULL DEFAULT 'trader' CHECK (role IN ('trader', 'admin')),
    
    -- Настройки
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
    preferred_currency VARCHAR(10) NOT NULL DEFAULT 'USDT' CHECK (preferred_currency IN ('USDT', 'USD')),
    settings JSONB DEFAULT '{}'::jsonb, -- Храним пороги доходности, пресеты фильтров здесь
    
    is_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'blocked')),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Таблица API ключей (Зашифрованные данные)
CREATE TABLE crypto_arbitrage.user_api_keys (
    key_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL REFERENCES crypto_arbitrage.users(user_id) ON DELETE CASCADE,
    exchange_name VARCHAR(50) NOT NULL DEFAULT 'BingX',
    key_name VARCHAR(100) NOT NULL,
    
    -- В БД храним только зашифрованные значения или хеши для проверки, 
    api_key_encrypted TEXT NOT NULL, 
    api_secret_encrypted TEXT NOT NULL,
    
    permissions JSONB NOT NULL DEFAULT '["read"]'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_api_keys_user ON crypto_arbitrage.user_api_keys(user_id);

-- ==========================================
-- БЛОК РЫНОЧНЫХ ДАННЫХ
-- ==========================================

CREATE TABLE crypto_arbitrage.exchanges (
    exchange_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL DEFAULT 'online',
    base_url TEXT NOT NULL
);

INSERT INTO crypto_arbitrage.exchanges (name, base_url) VALUES ('BingX', 'https://open-api.bingx.com');

CREATE TABLE crypto_arbitrage.trading_pairs (
    pair_id SERIAL PRIMARY KEY,
    exchange_id INT NOT NULL REFERENCES crypto_arbitrage.exchanges(exchange_id),
    symbol VARCHAR(30) NOT NULL, -- BTC-USDT
    base_asset VARCHAR(10) NOT NULL, -- BTC
    quote_asset VARCHAR(10) NOT NULL, -- USDT
    
    -- Торговые ограничения
    min_notional NUMERIC(20, 8), -- Мин сумма в USDT
    max_leverage INT DEFAULT 50,
    
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(exchange_id, symbol)
);

CREATE TABLE crypto_arbitrage.funding_rate_history (
    pair_id INT NOT NULL REFERENCES crypto_arbitrage.trading_pairs(pair_id) ON DELETE CASCADE,
    recorded_at TIMESTAMPTZ NOT NULL,
    
    funding_rate NUMERIC(12, 8) NOT NULL, -- 0.00010000
    spot_price NUMERIC(20, 8) NOT NULL,
    perp_price NUMERIC(20, 8) NOT NULL,
    
    -- Генерируемые столбцы для экономии вычислений при чтении
    spread_percent NUMERIC(10, 4) GENERATED ALWAYS AS (
        CASE WHEN spot_price > 0 THEN ((perp_price - spot_price) / spot_price) * 100 ELSE 0 END
    ) STORED,
    
    predicted_apy NUMERIC(10, 2) GENERATED ALWAYS AS (
        funding_rate * 3 * 365 * 100
    ) STORED,

    next_funding_time TIMESTAMPTZ NOT NULL,

    PRIMARY KEY (pair_id, recorded_at)
) PARTITION BY RANGE (recorded_at);

-- Пример создания партиций (в продакшене лучше использовать pg_partman)
CREATE TABLE crypto_arbitrage.funding_history_2024_q1 PARTITION OF crypto_arbitrage.funding_rate_history
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');
CREATE TABLE crypto_arbitrage.funding_history_default PARTITION OF crypto_arbitrage.funding_rate_history DEFAULT;

-- Индекс BRIN очень эффективен для упорядоченных временных рядов
CREATE INDEX idx_funding_history_time_brin ON crypto_arbitrage.funding_rate_history USING BRIN (recorded_at);


-- "Кэш" 
CREATE TABLE crypto_arbitrage.market_snapshot_latest (
    pair_id INT PRIMARY KEY REFERENCES crypto_arbitrage.trading_pairs(pair_id) ON DELETE CASCADE,
    funding_rate NUMERIC(12, 8),
    spot_price NUMERIC(20, 8),
    perp_price NUMERIC(20, 8),
    spread_percent NUMERIC(10, 4),
    apy NUMERIC(10, 2),
    next_funding_time TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==========================================
-- БЛОК ТОРГОВЛИ И ПОРТФЕЛЯ
-- ==========================================

-- Позиции пользователя
CREATE TABLE crypto_arbitrage.positions (
    position_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL REFERENCES crypto_arbitrage.users(user_id),
    pair_id INT NOT NULL REFERENCES crypto_arbitrage.trading_pairs(pair_id),
    
    -- Данные входа
    is_open BOOLEAN NOT NULL DEFAULT TRUE,
    side VARCHAR(10) NOT NULL DEFAULT 'LONG_SPOT_SHORT_PERP', -- Стратегия арбитража обычно такая
    
    entry_spot_price NUMERIC(20, 8) NOT NULL,
    entry_perp_price NUMERIC(20, 8) NOT NULL,
    
    size_asset NUMERIC(20, 8) NOT NULL, -- Количество монет (например, 0.1 BTC)
    leverage INT NOT NULL DEFAULT 1,
    
    -- Данные выхода (заполняются при закрытии)
    exit_spot_price NUMERIC(20, 8),
    exit_perp_price NUMERIC(20, 8),
    realized_pnl_usdt NUMERIC(20, 8), -- Фиксируем только когда закрыли
    
    fees_paid_usdt NUMERIC(20, 8) DEFAULT 0,
    accumulated_funding_usdt NUMERIC(20, 8) DEFAULT 0, -- Обновляется периодически (раз в 8 часов), а не реалтайм
    
    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ
);

CREATE INDEX idx_positions_user_active ON crypto_arbitrage.positions(user_id) WHERE is_open = TRUE;

-- ==========================================
-- БЛОК Оповещений
-- ==========================================

CREATE TABLE crypto_arbitrage.alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL REFERENCES crypto_arbitrage.users(user_id) ON DELETE CASCADE,
    pair_id INT REFERENCES crypto_arbitrage.trading_pairs(pair_id), -- Если NULL, то "Любая пара"
    
    condition_type VARCHAR(50) NOT NULL CHECK (condition_type IN ('funding_gt', 'spread_gt', 'apy_gt')),
    threshold_value NUMERIC(20, 8) NOT NULL,
    
    notification_channels JSONB DEFAULT '["email"]'::jsonb, -- ["email", "telegram", "push"]
    
    is_active BOOLEAN DEFAULT TRUE,
    last_triggered_at TIMESTAMPTZ,
    cooldown_minutes INT DEFAULT 60 -- Чтобы не спамить
);

-- ==========================================
-- ANALYTICS & VIEWS
-- ==========================================

-- Представление для Дашборда (Самое нагруженное)
CREATE OR REPLACE VIEW crypto_arbitrage.view_dashboard_tickers AS
SELECT 
    tp.pair_id,
    tp.symbol,
    ms.spot_price,
    ms.perp_price,
    ms.funding_rate,
    ms.spread_percent,
    ms.apy,
    ms.next_funding_time,
    ms.updated_at
FROM crypto_arbitrage.trading_pairs tp
JOIN crypto_arbitrage.market_snapshot_latest ms ON tp.pair_id = ms.pair_id
WHERE tp.is_active = TRUE;

-- Это представление соединяет статические данные позиции с текущими ценами
CREATE OR REPLACE VIEW crypto_arbitrage.view_user_active_portfolio AS
SELECT 
    p.position_id,
    p.user_id,
    tp.symbol,
    p.size_asset,
    p.leverage,
    p.entry_spot_price,
    p.entry_perp_price,
    -- Текущие цены из снапшота
    ms.spot_price as current_spot,
    ms.perp_price as current_perp,
    
    -- Расчет PnL Спота
    (ms.spot_price - p.entry_spot_price) * p.size_asset as pnl_spot_est,
    
    -- Расчет PnL Фьючерса 
    (p.entry_perp_price - ms.perp_price) * p.size_asset as pnl_perp_est,
    
    p.accumulated_funding_usdt
FROM crypto_arbitrage.positions p
JOIN crypto_arbitrage.trading_pairs tp ON p.pair_id = tp.pair_id
JOIN crypto_arbitrage.market_snapshot_latest ms ON p.pair_id = ms.pair_id
WHERE p.is_open = TRUE;

-- ==========================================
-- СИСТЕМНЫЕ ЛОГИ
-- ==========================================

CREATE TABLE crypto_arbitrage.system_logs (
    log_id BIGSERIAL,
    level VARCHAR(10) CHECK (level IN ('INFO', 'WARN', 'ERROR')),
    source VARCHAR(50),
    message TEXT,
    meta JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
) PARTITION BY RANGE (created_at);

CREATE TABLE crypto_arbitrage.system_logs_def PARTITION OF crypto_arbitrage.system_logs DEFAULT;

-- Функция автообновления updated_at
CREATE OR REPLACE FUNCTION crypto_arbitrage.fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_update BEFORE UPDATE ON crypto_arbitrage.users
FOR EACH ROW EXECUTE FUNCTION crypto_arbitrage.fn_update_timestamp();
