-- Make display_name globally unique

ALTER TABLE users ADD CONSTRAINT users_display_name_unique UNIQUE (display_name);
