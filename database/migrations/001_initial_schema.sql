-- Tipos enumerados
CREATE TYPE user_role AS ENUM ('user', 'admin');

CREATE TYPE report_reason AS ENUM (
    'spam',
    'harassment',
    'hate_or_discrimination',
    'threats_or_violence',
    'other'
);

CREATE TYPE report_status AS ENUM (
    'pending',
    'action_taken',
    'dismissed'
);

CREATE TYPE moderation_action_type AS ENUM ('hide', 'restore');
CREATE TYPE moderation_target_type AS ENUM ('post', 'comment');


-- Usuarios
CREATE TABLE users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(20) NOT NULL,
    name VARCHAR(50) NOT NULL,
    email VARCHAR(254) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    bio VARCHAR(160),
    photo_url TEXT,
    role user_role NOT NULL DEFAULT 'user',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT users_username_format
        CHECK (username ~ '^[a-z0-9_]{3,20}$'),
    CONSTRAINT users_username_unique
        UNIQUE (username),
    CONSTRAINT users_name_not_blank
        CHECK (BTRIM(name) <> ''),
    CONSTRAINT users_email_normalized
        CHECK (email <> '' AND email = LOWER(BTRIM(email))),
    CONSTRAINT users_email_unique
        UNIQUE (email)
);


-- Publicaciones
CREATE TABLE posts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content VARCHAR(200) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    author_hidden_at TIMESTAMPTZ,
    admin_hidden_at TIMESTAMPTZ,
    admin_hidden_by_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,

    CONSTRAINT posts_content_not_empty
        CHECK (content ~ '[^[:space:]]'),
    CONSTRAINT posts_admin_hider_requires_hidden_state
        CHECK (
            admin_hidden_at IS NOT NULL
            OR admin_hidden_by_user_id IS NULL
        )
);


-- Comentarios
CREATE TABLE comments (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    content VARCHAR(200) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    author_hidden_at TIMESTAMPTZ,
    admin_hidden_at TIMESTAMPTZ,
    admin_hidden_by_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,

    CONSTRAINT comments_content_not_empty
        CHECK (content ~ '[^[:space:]]'),
    CONSTRAINT comments_admin_hider_requires_hidden_state
        CHECK (
            admin_hidden_at IS NOT NULL
            OR admin_hidden_by_user_id IS NULL
        )
);


-- Likes de publicaciones
CREATE TABLE post_likes (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (user_id, post_id)
);


-- Likes de comentarios
CREATE TABLE comment_likes (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    comment_id BIGINT NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (user_id, comment_id)
);


-- Seguimientos
CREATE TABLE follows (
    follower_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (follower_id, following_id),
    CONSTRAINT follows_no_self_follow
        CHECK (follower_id <> following_id)
);


-- Reportes
CREATE TABLE reports (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reporter_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    reason report_reason NOT NULL,
    details TEXT,
    status report_status NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT reports_one_per_user_per_post
        UNIQUE (reporter_id, post_id)
);


-- Revisiones de reportes.
-- Las referencias vivas pueden quedar NULL; las columnas snapshot conservan
-- quién revisó y a qué reporte se refería la revisión.
CREATE TABLE report_reviews (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    report_id BIGINT REFERENCES reports(id) ON DELETE SET NULL,
    report_id_snapshot BIGINT NOT NULL,

    reviewer_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    reviewer_user_id_snapshot BIGINT NOT NULL,
    reviewer_username_snapshot VARCHAR(20) NOT NULL,

    outcome report_status NOT NULL,
    reviewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT report_reviews_outcome_not_pending
        CHECK (outcome <> 'pending')
);


-- Historial administrativo.
-- target_id es un snapshot y no una FK para que borrar el contenido no borre
-- el historial de moderación.
CREATE TABLE moderation_actions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    moderator_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    moderator_user_id_snapshot BIGINT NOT NULL,
    moderator_username_snapshot VARCHAR(20) NOT NULL,

    target_type moderation_target_type NOT NULL,
    target_id BIGINT NOT NULL,
    action moderation_action_type NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- Índices
CREATE INDEX posts_user_id_idx
    ON posts (user_id);

CREATE INDEX posts_visible_feed_idx
    ON posts (user_id, created_at DESC, id DESC)
    WHERE author_hidden_at IS NULL
      AND admin_hidden_at IS NULL;

CREATE INDEX posts_admin_hidden_by_user_idx
    ON posts (admin_hidden_by_user_id)
    WHERE admin_hidden_by_user_id IS NOT NULL;

CREATE INDEX comments_user_id_idx
    ON comments (user_id);

CREATE INDEX comments_post_id_idx
    ON comments (post_id);

CREATE INDEX comments_visible_by_post_idx
    ON comments (post_id, created_at DESC, id DESC)
    WHERE author_hidden_at IS NULL
      AND admin_hidden_at IS NULL;

CREATE INDEX comments_admin_hidden_by_user_idx
    ON comments (admin_hidden_by_user_id)
    WHERE admin_hidden_by_user_id IS NOT NULL;

CREATE INDEX post_likes_post_id_idx
    ON post_likes (post_id);

CREATE INDEX comment_likes_comment_id_idx
    ON comment_likes (comment_id);

CREATE INDEX follows_following_id_idx
    ON follows (following_id);

CREATE INDEX reports_post_id_idx
    ON reports (post_id);

CREATE INDEX reports_pending_idx
    ON reports (created_at)
    WHERE status = 'pending';

CREATE INDEX report_reviews_report_id_idx
    ON report_reviews (report_id);

CREATE INDEX report_reviews_reviewer_id_idx
    ON report_reviews (reviewer_user_id);

CREATE INDEX moderation_actions_moderator_id_idx
    ON moderation_actions (moderator_user_id);

CREATE INDEX moderation_actions_target_idx
    ON moderation_actions (target_type, target_id);