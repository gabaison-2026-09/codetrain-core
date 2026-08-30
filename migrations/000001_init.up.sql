-- CodeTrain 初期スキーマ
-- DESIGN.md §6「データモデル（主要エンティティ）」に対応する。
-- Aurora Serverless v2 (PostgreSQL) を本番に使うが、Aurora 固有機能は使わない
-- （LOCAL_DEV.md §4.2）。素の PostgreSQL で動くことをローカルで担保する。

BEGIN;

-- ---------------------------------------------------------------------------
-- 列挙型
-- ---------------------------------------------------------------------------

-- 問題タイプ。DESIGN.md §3 の MVP スコープに挙がっている5種。
CREATE TYPE question_type AS ENUM (
    'code_reading',      -- コード読解
    'output_prediction', -- 出力予測
    'bug_finding',       -- バグ発見
    'fill_in_blank',     -- 穴埋め
    'best_practice'      -- ベストプラクティス選択
);

-- 問題のライフサイクル。DESIGN.md §5 のデータフローに対応。
CREATE TYPE question_status AS ENUM (
    'draft',         -- 生成直後
    'needs_review',  -- 自動検証を通過し、人間レビュー待ち
    'published',     -- 承認済み。配信対象
    'rejected'       -- 却下
);

-- レビュー判定。
CREATE TYPE review_verdict AS ENUM (
    'pending',
    'approved',
    'rejected'
);

-- ---------------------------------------------------------------------------
-- コンテンツ側
-- ---------------------------------------------------------------------------

-- 取得元コード・出典・ライセンス。
-- DESIGN.md §9（法務・ライセンス制約）により、帰属表示に必要な情報を必ず保持する。
CREATE TABLE raw_source (
    id              BIGSERIAL PRIMARY KEY,
    repo_full_name  TEXT        NOT NULL,              -- 例: golang/go
    repo_url        TEXT        NOT NULL,
    commit_sha      TEXT        NOT NULL,
    file_path       TEXT        NOT NULL,
    start_line      INTEGER,
    end_line        INTEGER,
    language        TEXT        NOT NULL,              -- 例: go / typescript
    license_spdx    TEXT        NOT NULL,              -- 例: MIT / Apache-2.0
    license_url     TEXT,
    author_attribution TEXT,                           -- NOTICE 等の帰属表示テキスト
    s3_key          TEXT,                              -- S3 に置いた原文の位置
    fetched_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (repo_full_name, commit_sha, file_path, start_line, end_line)
);

-- スキルツリーのトピック。
CREATE TABLE skill (
    id           BIGSERIAL PRIMARY KEY,
    slug         TEXT        NOT NULL UNIQUE,          -- 例: js-basics
    name         TEXT        NOT NULL,
    description  TEXT,
    display_order INTEGER    NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- スキルツリーのノード（トピック内の単元）と前提関係。
-- parent_id は「このノードを解放するのに必要な直前のノード」。NULL ならツリーの起点。
CREATE TABLE skill_node (
    id            BIGSERIAL PRIMARY KEY,
    skill_id      BIGINT      NOT NULL REFERENCES skill(id) ON DELETE CASCADE,
    parent_id     BIGINT      REFERENCES skill_node(id) ON DELETE SET NULL,
    slug          TEXT        NOT NULL,
    name          TEXT        NOT NULL,
    description   TEXT,
    difficulty    SMALLINT    NOT NULL DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 5),
    display_order INTEGER     NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (skill_id, slug)
);

CREATE INDEX idx_skill_node_skill  ON skill_node (skill_id);
CREATE INDEX idx_skill_node_parent ON skill_node (parent_id);

-- 設問本体。
-- choices は [{"key":"a","text":"..."}] 形式の JSON 配列、
-- correct_keys は正解の key の配列（単一選択なら要素1つ）。
--
-- prompt_version / model_id / gen_tokens / generated_at は生成メタデータ
-- （OPEN_ISSUES C-3）。「どの設定で作った問題が良かったか」を後から辿るために
-- 最初から持たせる。手書きのシード問題では NULL になる。
CREATE TABLE question (
    id             BIGSERIAL PRIMARY KEY,
    skill_node_id  BIGINT          REFERENCES skill_node(id) ON DELETE SET NULL,
    raw_source_id  BIGINT          REFERENCES raw_source(id) ON DELETE SET NULL,
    type           question_type   NOT NULL,
    status         question_status NOT NULL DEFAULT 'draft',
    difficulty     SMALLINT        NOT NULL DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 5),
    title          TEXT            NOT NULL,
    body           TEXT            NOT NULL,           -- 設問文
    code           TEXT,                               -- 提示するコード片
    code_language  TEXT,
    choices        JSONB           NOT NULL DEFAULT '[]'::jsonb,
    correct_keys   JSONB           NOT NULL DEFAULT '[]'::jsonb,
    explanation    TEXT,
    tags           TEXT[]          NOT NULL DEFAULT '{}',
    prompt_version TEXT,
    model_id       TEXT,
    gen_tokens     INTEGER,
    generated_at   TIMESTAMPTZ,
    created_at     TIMESTAMPTZ     NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE INDEX idx_question_status     ON question (status);
CREATE INDEX idx_question_skill_node ON question (skill_node_id);
CREATE INDEX idx_question_tags       ON question USING GIN (tags);

-- ---------------------------------------------------------------------------
-- ユーザー側
-- ---------------------------------------------------------------------------

-- 認証情報・プロフィール。
-- external_id は認証基盤上の識別子。AUTH_MODE=cognito では Cognito の sub、
-- AUTH_MODE=dev では X-Dev-User ヘッダの値が入る（LOCAL_DEV.md §5.4）。
-- "user" は予約語のため app_user とする。
CREATE TABLE app_user (
    id           BIGSERIAL PRIMARY KEY,
    external_id  TEXT        NOT NULL UNIQUE,
    display_name TEXT        NOT NULL,
    email        TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- XP・streak・現在のツリー位置。
-- ゲーム設計パラメータ（OPEN_ISSUES B-3）は未確定のため、
-- 値を保持する列だけ用意し、計算ロジックはアプリ側に持たせない。
CREATE TABLE user_progress (
    user_id            BIGINT      PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
    xp                 INTEGER     NOT NULL DEFAULT 0,
    streak_days        INTEGER     NOT NULL DEFAULT 0,
    last_studied_on    DATE,
    hearts             SMALLINT    NOT NULL DEFAULT 5,
    hearts_updated_at  TIMESTAMPTZ,
    current_skill_node_id BIGINT   REFERENCES skill_node(id) ON DELETE SET NULL,
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 回答履歴。
CREATE TABLE attempt (
    id             BIGSERIAL PRIMARY KEY,
    user_id        BIGINT      NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    question_id    BIGINT      NOT NULL REFERENCES question(id) ON DELETE CASCADE,
    selected_keys  JSONB       NOT NULL DEFAULT '[]'::jsonb,
    is_correct     BOOLEAN     NOT NULL,
    duration_ms    INTEGER,
    answered_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_attempt_user_answered ON attempt (user_id, answered_at DESC);
CREATE INDEX idx_attempt_question      ON attempt (question_id);

-- question × user の間隔反復状態（SM-2 ベース）。
-- 具体仕様は OPEN_ISSUES B-4 で未確定のため、SM-2 が必要とする値の器だけ置く。
CREATE TABLE srs_state (
    user_id        BIGINT      NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    question_id    BIGINT      NOT NULL REFERENCES question(id) ON DELETE CASCADE,
    easiness       REAL        NOT NULL DEFAULT 2.5,
    interval_days  INTEGER     NOT NULL DEFAULT 0,
    repetitions    INTEGER     NOT NULL DEFAULT 0,
    due_on         DATE        NOT NULL,
    last_reviewed_at TIMESTAMPTZ,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, question_id)
);

CREATE INDEX idx_srs_state_due ON srs_state (user_id, due_on);

-- レビュー対象・レビュアー・判定。
CREATE TABLE review_queue (
    id           BIGSERIAL PRIMARY KEY,
    question_id  BIGINT         NOT NULL REFERENCES question(id) ON DELETE CASCADE,
    reviewer_id  BIGINT         REFERENCES app_user(id) ON DELETE SET NULL,
    verdict      review_verdict NOT NULL DEFAULT 'pending',
    comment      TEXT,
    created_at   TIMESTAMPTZ    NOT NULL DEFAULT now(),
    reviewed_at  TIMESTAMPTZ
);

CREATE INDEX idx_review_queue_verdict ON review_queue (verdict);
CREATE UNIQUE INDEX idx_review_queue_open
    ON review_queue (question_id)
    WHERE verdict = 'pending';

COMMIT;
