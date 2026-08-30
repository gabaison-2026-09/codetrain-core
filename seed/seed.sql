-- CodeTrain 開発用シードデータ
--
-- 目的（LOCAL_DEV.md §8）: Flutter 開発者が LLM もサンドボックスも起動せずに
-- MVP ループを触れる状態を作る。Track B の独立性はこのシードが支えている。
--
-- 方針:
--   * 問題は「手書き」。生成パイプライン（Track A）の実行結果に依存させない。
--   * 実コードの引用を含むものは raw_source に出典・ライセンスを持たせ、
--     帰属表示の実装（DESIGN.md §9）を検証できるようにする。
--   * 何度流しても同じ状態になるよう、**ID を固定**して ON CONFLICT DO NOTHING で入れる。
--     末尾でシーケンスを 1000 まで進め、アプリが採番する ID と衝突させない。
--   * 問題文は日本語。言語の扱い（OPEN_ISSUES B-1）は未決のため language 列はまだ持たない。

BEGIN;

-- ---------------------------------------------------------------------------
-- スキルツリー
-- ---------------------------------------------------------------------------

INSERT INTO skill (id, slug, name, description, display_order) VALUES
    (1, 'js-basics',  'JavaScript 基礎', '値・型・スコープ・非同期の土台', 1),
    (2, 'web-api',    'Web API',        'HTTP・REST・ステータスコードの扱い', 2)
ON CONFLICT (id) DO NOTHING;

INSERT INTO skill_node (id, skill_id, parent_id, slug, name, description, difficulty, display_order) VALUES
    (1, 1, NULL, 'values-and-types', '値と型',       '型変換と比較演算子の挙動',         1, 1),
    (2, 1, 1,    'scope-and-closure', 'スコープとクロージャ', 'var/let の違いとクロージャ', 2, 2),
    (3, 1, 2,    'array-methods',     '配列メソッド', 'map / filter / reduce の使い分け', 2, 3),
    (4, 1, 3,    'async',             '非同期処理',   'Promise と async/await',          3, 4),
    (5, 2, NULL, 'http-basics',       'HTTP の基礎',  'メソッドとステータスコード',       1, 1),
    (6, 2, 5,    'rest-design',       'REST 設計',    'リソース指向のエンドポイント設計', 3, 2)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 出典（帰属表示の検証用）
-- ---------------------------------------------------------------------------

INSERT INTO raw_source (
    id, repo_full_name, repo_url, commit_sha, file_path,
    start_line, end_line, language, license_spdx, license_url, author_attribution, s3_key
) VALUES
    (1, 'codetrain/seed-fixtures', 'https://github.com/codetrain/seed-fixtures',
     '0000000000000000000000000000000000000000', 'examples/array.js',
     1, 12, 'javascript', 'MIT', 'https://opensource.org/licenses/MIT',
     'CodeTrain seed fixtures contributors', NULL),
    (2, 'codetrain/seed-fixtures', 'https://github.com/codetrain/seed-fixtures',
     '0000000000000000000000000000000000000000', 'examples/async.js',
     1, 20, 'javascript', 'Apache-2.0', 'https://www.apache.org/licenses/LICENSE-2.0',
     'CodeTrain seed fixtures contributors', NULL)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 問題（published）
-- 全5タイプ × 難易度1〜5 を網羅する。prompt_version 等の生成メタデータは
-- 手書きのため NULL のまま（OPEN_ISSUES C-3 の列が NULL 許容であることの確認も兼ねる）。
-- ---------------------------------------------------------------------------

INSERT INTO question (
    id, skill_node_id, raw_source_id, type, status, difficulty,
    title, body, code, code_language, choices, correct_keys, explanation, tags
) VALUES
-- --- code_reading -----------------------------------------------------------
(1, 1, NULL, 'code_reading', 'published', 1,
 '厳密等価演算子の比較結果',
 '次のコードで `result` に入る値はどれですか。',
 'const result = 1 === "1";',
 'javascript',
 '[{"key":"a","text":"true"},{"key":"b","text":"false"},{"key":"c","text":"1"},{"key":"d","text":"TypeError"}]',
 '["b"]',
 '`===` は型変換を行わないため、number の 1 と string の "1" は等しくならず false になる。型変換を伴う `==` なら true になる。',
 ARRAY['javascript','operator']),

(2, 2, NULL, 'code_reading', 'published', 3,
 'クロージャが捕捉する変数',
 '次のコードを実行したとき、コンソールに出力される値はどれですか。',
 'function counter() {
  let n = 0;
  return () => ++n;
}
const c = counter();
c();
c();
console.log(c());',
 'javascript',
 '[{"key":"a","text":"1"},{"key":"b","text":"2"},{"key":"c","text":"3"},{"key":"d","text":"undefined"}]',
 '["c"]',
 '`counter` が返す関数は同じ `n` を捕捉し続ける。3回呼び出されるので 3 が出力される。',
 ARRAY['javascript','closure']),

-- --- output_prediction ------------------------------------------------------
(3, 1, NULL, 'output_prediction', 'published', 2,
 'var のホイスティング',
 '次のコードの出力を予測してください。',
 'console.log(typeof x);
var x = 5;',
 'javascript',
 '[{"key":"a","text":"number"},{"key":"b","text":"undefined"},{"key":"c","text":"ReferenceError"},{"key":"d","text":"null"}]',
 '["b"]',
 '`var` の宣言は巻き上げられるが、代入は巻き上げられない。宣言済みで未代入の変数は `undefined` であり、その `typeof` は "undefined" になる。',
 ARRAY['javascript','hoisting']),

(4, 4, 2, 'output_prediction', 'published', 4,
 'イベントループの実行順序',
 '次のコードが出力する順序として正しいものはどれですか。',
 'console.log("A");
setTimeout(() => console.log("B"), 0);
Promise.resolve().then(() => console.log("C"));
console.log("D");',
 'javascript',
 '[{"key":"a","text":"A D C B"},{"key":"b","text":"A B C D"},{"key":"c","text":"A D B C"},{"key":"d","text":"A C D B"}]',
 '["a"]',
 '同期コード（A, D）が先に走り、次にマイクロタスクの Promise コールバック（C）、最後にマクロタスクの setTimeout（B）が実行される。',
 ARRAY['javascript','event-loop','async']),

(5, 3, 1, 'output_prediction', 'published', 5,
 'reduce の初期値の有無',
 '次のコードの出力はどれですか。',
 'const xs = [1, 2, 3, 4];
const r = xs.reduce((a, b) => a + b);
console.log(r / xs.length);',
 'javascript',
 '[{"key":"a","text":"2.5"},{"key":"b","text":"10"},{"key":"c","text":"2"},{"key":"d","text":"NaN"}]',
 '["a"]',
 '初期値なしの `reduce` は先頭要素を初期値として残りを畳み込む。合計は 10、要素数 4 なので 2.5 になる。',
 ARRAY['javascript','array']),

-- --- bug_finding ------------------------------------------------------------
(6, 3, 1, 'bug_finding', 'published', 3,
 'filter の結果が空になる原因',
 '偶数だけを取り出すつもりのコードですが、結果が期待どおりになりません。原因はどれですか。',
 'const evens = [1, 2, 3, 4].filter((n) => {
  n % 2 === 0;
});',
 'javascript',
 '[{"key":"a","text":"コールバックが値を return していない"},{"key":"b","text":"filter ではなく map を使うべき"},{"key":"c","text":"% 演算子が偶数判定に使えない"},{"key":"d","text":"配列リテラルの書き方が誤っている"}]',
 '["a"]',
 'ブロック本体のアロー関数は暗黙の return を持たない。`return n % 2 === 0;` と書くか、`(n) => n % 2 === 0` の式形式にする必要がある。返り値が undefined のため全要素が除外される。',
 ARRAY['javascript','array','bug']),

(7, 4, 2, 'bug_finding', 'published', 4,
 'async 関数で例外が握りつぶされる',
 '次のコードでエラーが捕捉されない理由はどれですか。',
 'async function main() {
  try {
    fetchUser();
  } catch (e) {
    console.error(e);
  }
}',
 'javascript',
 '[{"key":"a","text":"fetchUser を await していないため、reject が try に捕まらない"},{"key":"b","text":"catch のブロックに return がない"},{"key":"c","text":"async 関数では try/catch が使えない"},{"key":"d","text":"console.error は例外を握りつぶす"}]',
 '["a"]',
 '`await` を付けないと Promise の reject は同期的な例外にならず、try/catch を素通りして未処理の rejection になる。',
 ARRAY['javascript','async','bug']),

-- --- fill_in_blank ----------------------------------------------------------
(8, 3, 1, 'fill_in_blank', 'published', 2,
 '配列を変換するメソッド',
 '各要素を2倍した新しい配列を作ります。空欄に入るメソッド名はどれですか。',
 'const doubled = [1, 2, 3].____((n) => n * 2);',
 'javascript',
 '[{"key":"a","text":"map"},{"key":"b","text":"forEach"},{"key":"c","text":"filter"},{"key":"d","text":"reduce"}]',
 '["a"]',
 '`map` は各要素に関数を適用した新しい配列を返す。`forEach` は返り値が undefined、`filter` は絞り込み用。',
 ARRAY['javascript','array']),

(9, 5, NULL, 'fill_in_blank', 'published', 1,
 'リソースを作成する HTTP メソッド',
 'REST API で新しいリソースを作成するときに使うメソッドはどれですか。',
 NULL,
 NULL,
 '[{"key":"a","text":"GET"},{"key":"b","text":"POST"},{"key":"c","text":"DELETE"},{"key":"d","text":"HEAD"}]',
 '["b"]',
 '`POST` はサーバ側で新しいリソースを作成する。`GET` と `HEAD` は安全（副作用なし）なメソッドで、作成には使わない。',
 ARRAY['http','rest']),

-- --- best_practice ----------------------------------------------------------
(10, 5, NULL, 'best_practice', 'published', 2,
 'バリデーション失敗時のステータスコード',
 'リクエストボディの必須項目が欠けていたとき、返すべきステータスコードはどれですか。',
 NULL,
 NULL,
 '[{"key":"a","text":"400 Bad Request"},{"key":"b","text":"401 Unauthorized"},{"key":"c","text":"404 Not Found"},{"key":"d","text":"500 Internal Server Error"}]',
 '["a"]',
 'クライアント側の入力不備は 400 系。認証が無い場合は 401、権限不足は 403。500 はサーバ側の想定外エラーに使うもので、入力不備に使うと監視のノイズになる。',
 ARRAY['http','rest','best-practice']),

(11, 6, NULL, 'best_practice', 'published', 5,
 'REST のエンドポイント命名',
 'ユーザーの注文一覧を取得するエンドポイントとして、REST の慣習に最も沿うものはどれですか。',
 NULL,
 NULL,
 '[{"key":"a","text":"GET /users/{id}/orders"},{"key":"b","text":"GET /getUserOrders?id={id}"},{"key":"c","text":"POST /users/orders/fetch"},{"key":"d","text":"GET /orders/getByUser/{id}"}]',
 '["a"]',
 'REST はリソースを名詞の階層で表し、操作は HTTP メソッドで表現する。URL に動詞を入れる設計はメソッドの意味と重複する。',
 ARRAY['rest','api-design','best-practice']),

(12, 2, NULL, 'code_reading', 'published', 2,
 'let のブロックスコープ',
 '次のコードの実行結果はどれですか。',
 'let x = 1;
{
  let x = 2;
}
console.log(x);',
 'javascript',
 '[{"key":"a","text":"1"},{"key":"b","text":"2"},{"key":"c","text":"undefined"},{"key":"d","text":"SyntaxError"}]',
 '["a"]',
 '`let` はブロックスコープを持つため、内側の `x` は別の変数。外側の `x` は 1 のまま。',
 ARRAY['javascript','scope'])
ON CONFLICT (id) DO NOTHING;

-- レビュー画面（admin）の確認用に、レビュー待ちの問題も1件入れておく。
INSERT INTO question (
    id, skill_node_id, raw_source_id, type, status, difficulty,
    title, body, code, code_language, choices, correct_keys, explanation, tags,
    prompt_version, model_id, gen_tokens, generated_at
) VALUES
(13, 1, 1, 'output_prediction', 'needs_review', 3,
 '暗黙の型変換',
 '次のコードの出力を予測してください。',
 'console.log([] + {});',
 'javascript',
 '[{"key":"a","text":"[object Object]"},{"key":"b","text":"{}"},{"key":"c","text":"0"},{"key":"d","text":"NaN"}]',
 '["a"]',
 '配列は空文字列に、オブジェクトは "[object Object]" に変換されて連結される。',
 ARRAY['javascript','coercion'],
 'question_gen.v1', 'claude-haiku-4-5-20251001', 812, now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO review_queue (id, question_id, verdict, created_at) VALUES
    (1, 13, 'pending', now())
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- テストユーザーと進捗のバリエーション
-- external_id は AUTH_MODE=dev の X-Dev-User ヘッダにそのまま渡す値
-- （LOCAL_DEV.md §5.4）。UI の各状態を確認できるよう3種類用意する。
-- ---------------------------------------------------------------------------

INSERT INTO app_user (id, external_id, display_name, email) VALUES
    (1, 'seed-user-01', '新規ユーザー',   'seed-user-01@example.test'),
    (2, 'seed-user-02', '学習中ユーザー', 'seed-user-02@example.test'),
    (3, 'seed-user-03', '復習が溜まったユーザー', 'seed-user-03@example.test')
ON CONFLICT (id) DO NOTHING;

INSERT INTO user_progress (user_id, xp, streak_days, last_studied_on, hearts, hearts_updated_at, current_skill_node_id) VALUES
    (1,    0, 0, NULL,                       5, now(), 1),
    (2,  450, 7, CURRENT_DATE,               4, now(), 3),
    (3, 1200, 0, CURRENT_DATE - INTERVAL '5 day', 2, now(), 4)
ON CONFLICT (user_id) DO NOTHING;

-- 学習中ユーザーの回答履歴。
INSERT INTO attempt (id, user_id, question_id, selected_keys, is_correct, duration_ms, answered_at) VALUES
    (1, 2, 1, '["b"]', true,  4200, now() - INTERVAL '2 day'),
    (2, 2, 3, '["a"]', false, 9100, now() - INTERVAL '2 day'),
    (3, 2, 3, '["b"]', true,  5300, now() - INTERVAL '1 day'),
    (4, 3, 1, '["b"]', true,  3100, now() - INTERVAL '9 day'),
    (5, 3, 4, '["c"]', false, 15200, now() - INTERVAL '8 day')
ON CONFLICT (id) DO NOTHING;

-- 復習キュー。seed-user-03 は期限切れの復習が溜まっている状態。
INSERT INTO srs_state (user_id, question_id, easiness, interval_days, repetitions, due_on, last_reviewed_at) VALUES
    (2, 1, 2.6, 4, 2, CURRENT_DATE + 2,  now() - INTERVAL '2 day'),
    (2, 3, 2.3, 1, 1, CURRENT_DATE,      now() - INTERVAL '1 day'),
    (3, 1, 2.5, 3, 2, CURRENT_DATE - 6,  now() - INTERVAL '9 day'),
    (3, 4, 1.9, 1, 1, CURRENT_DATE - 7,  now() - INTERVAL '8 day'),
    (3, 5, 2.1, 2, 1, CURRENT_DATE - 3,  now() - INTERVAL '5 day')
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- シーケンスを固定 ID の範囲外へ進める。
-- これをしないと、アプリが最初に INSERT したときに id=1 で一意制約違反になる。
-- ---------------------------------------------------------------------------

-- DO ブロックにしているのは、setval の戻り値で出力を埋めないため。
DO $$
DECLARE
    seq TEXT;
BEGIN
    FOREACH seq IN ARRAY ARRAY[
        'skill_id_seq', 'skill_node_id_seq', 'raw_source_id_seq',
        'question_id_seq', 'review_queue_id_seq', 'app_user_id_seq', 'attempt_id_seq'
    ] LOOP
        PERFORM setval(seq, 1000, false);
    END LOOP;
END $$;

COMMIT;
