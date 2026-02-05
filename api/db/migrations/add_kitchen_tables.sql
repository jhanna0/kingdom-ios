-- Kitchen System Tables
-- Run this migration to add oven slots and kitchen history

-- Oven slots (active baking state)
CREATE TABLE IF NOT EXISTS oven_slots (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    slot_index INTEGER NOT NULL,
    status VARCHAR NOT NULL DEFAULT 'empty',
    wheat_used INTEGER DEFAULT 0,
    loaves_pending INTEGER DEFAULT 0,
    started_at TIMESTAMP,
    ready_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_oven_slots_user_id ON oven_slots(user_id);

-- Kitchen history (tracking for future achievements)
CREATE TABLE IF NOT EXISTS kitchen_history (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    slot_index INTEGER NOT NULL,
    action VARCHAR NOT NULL,
    wheat_used INTEGER DEFAULT 0,
    loaves_produced INTEGER DEFAULT 0,
    started_at TIMESTAMP,
    completed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_kitchen_history_user_id ON kitchen_history(user_id);
