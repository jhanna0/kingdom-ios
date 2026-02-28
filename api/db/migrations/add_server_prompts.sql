-- Server Prompts System
-- Backend-driven popups for feedback, polls, announcements, etc.
-- Run: psql -d kingdom -f db/migrations/add_server_prompts.sql

-- Server prompts (admin creates these)
CREATE TABLE IF NOT EXISTS server_prompts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    modal_url TEXT NOT NULL,                      -- URL to load in webview (backend serves the HTML)
    target_platform TEXT DEFAULT 'all',           -- 'ios', 'android', or 'all'
    expires_at TIMESTAMP WITH TIME ZONE,          -- Prompt stops showing after this date
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Track which users dismissed which prompts
CREATE TABLE IF NOT EXISTS prompt_dismissals (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    prompt_id UUID NOT NULL REFERENCES server_prompts(id) ON DELETE CASCADE,
    dismissal_count INTEGER DEFAULT 1,
    last_shown_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    dismissed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed BOOLEAN DEFAULT FALSE,
    UNIQUE(user_id, prompt_id)
);

CREATE INDEX IF NOT EXISTS ix_prompt_dismissals_user_id ON prompt_dismissals(user_id);
CREATE INDEX IF NOT EXISTS ix_prompt_dismissals_prompt_id ON prompt_dismissals(prompt_id);
