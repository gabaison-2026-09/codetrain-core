-- CodeTrain 開発用シードデータ
--
-- 目的（LOCAL_DEV.md §8）: Flutter 開発者が LLM もサンドボックスも起動せずに
-- MVP ループを触れる状態を作る。Track B の独立性はこのシードが支えている。
--
-- 方針:
--   * 問題は「手書き」。生成パイプライン（Track A）の実行結果に依存させない。
--   * PoC 段階は GitHub 収集をしないため、出典の無い問題は raw_source の
--     固定ダミー行（'00000000-0000-0000-0000-000000000001'）を指す。
--     実コード引用を含むものだけ専用の raw_source 行に出典・ライセンスを持たせる。
--   * 何度流しても同じ状態になるよう、**ID（uuid）を固定**して
--     ON CONFLICT DO NOTHING で入れる。アプリは gen_random_uuid() で採番するため
--     固定 ID と衝突しない（シーケンス調整は不要）。
--   * 問題文は日本語。言語の扱い（OPEN_ISSUES B-1）は未決のため language 列はまだ持たない。

BEGIN;

-- ---------------------------------------------------------------------------
-- スキルツリー
-- ---------------------------------------------------------------------------

INSERT INTO skill (id, slug, name, description, display_order) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'js-basics', 'JavaScript 基礎', '値・型・スコープ・非同期の土台', 1),
    ('a0000000-0000-0000-0000-000000000002', 'web-api',   'Web API',        'HTTP・REST・ステータスコードの扱い', 2)
ON CONFLICT (id) DO NOTHING;

INSERT INTO skill_node (id, skill_id, slug, name, description, difficulty, display_order) VALUES
    ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'values-and-types',  '値と型',             '型変換と比較演算子の挙動',         1, 1),
    ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'scope-and-closure', 'スコープとクロージャ', 'var/let の違いとクロージャ',      2, 2),
    ('b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'array-methods',     '配列メソッド',        'map / filter / reduce の使い分け', 2, 3),
    ('b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'async',             '非同期処理',          'Promise と async/await',           3, 4),
    ('b0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000002', 'http-basics',       'HTTP の基礎',         'メソッドとステータスコード',       1, 1),
    ('b0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000002', 'rest-design',       'REST 設計',           'リソース指向のエンドポイント設計', 3, 2)
ON CONFLICT (id) DO NOTHING;

-- 先修関係（多対多）。js-basics は 値と型 → スコープ → 配列 → 非同期 の一本道、
-- web-api は HTTP → REST。
INSERT INTO skill_node_prerequisite (node_id, prerequisite_node_id) VALUES
    ('b0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001'),
    ('b0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000002'),
    ('b0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000003'),
    ('b0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000005')
ON CONFLICT (node_id, prerequisite_node_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 出典（帰属表示の検証用）。実コード引用を含む問題だけがこれを指す。
-- 出典の無い問題はマイグレーションが作る LLM 生成ダミー行を指す。
-- ---------------------------------------------------------------------------

INSERT INTO raw_source (
    id, repo_full_name, repo_url, commit_sha, file_path,
    start_line, end_line, language, license_spdx, license_url, author_attribution, s3_key
) VALUES
    ('c0000000-0000-0000-0000-000000000001', 'codetrain/seed-fixtures', 'https://github.com/codetrain/seed-fixtures',
     '0000000000000000000000000000000000000000', 'examples/array.js',
     1, 12, 'javascript', 'MIT', 'https://opensource.org/licenses/MIT',
     'CodeTrain seed fixtures contributors', NULL),
    ('c0000000-0000-0000-0000-000000000002', 'codetrain/seed-fixtures', 'https://github.com/codetrain/seed-fixtures',
     '0000000000000000000000000000000000000000', 'examples/async.js',
     1, 20, 'javascript', 'Apache-2.0', 'https://www.apache.org/licenses/LICENSE-2.0',
     'CodeTrain seed fixtures contributors', NULL)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 問題（published）
-- 全5タイプ × 難易度1〜5 を網羅する。prompt_version 等の生成メタデータは
-- 手書きのため NULL のまま（OPEN_ISSUES C-3 の列が NULL 許容であることの確認も兼ねる）。
-- raw_source_id: 出典なし = '00000000-0000-0000-0000-000000000001'（LLM 生成ダミー）。
-- ---------------------------------------------------------------------------

INSERT INTO question (
    id, skill_node_id, raw_source_id, type, status, difficulty,
    title, body, code, code_language, choices, correct_keys, explanation, tags
) VALUES
-- --- code_reading -----------------------------------------------------------
('d0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'code_reading', 'published', 1,
 '厳密等価演算子の比較結果',
 '次のコードで `result` に入る値はどれですか。',
 'const result = 1 === "1";',
 'javascript',
 '[{"key":"a","text":"true"},{"key":"b","text":"false"},{"key":"c","text":"1"},{"key":"d","text":"TypeError"}]',
 '["b"]',
 '`===` は型変換を行わないため、number の 1 と string の "1" は等しくならず false になる。型変換を伴う `==` なら true になる。',
 ARRAY['javascript','operator']),

('d0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'code_reading', 'published', 3,
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
('d0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'output_prediction', 'published', 2,
 'var のホイスティング',
 '次のコードの出力を予測してください。',
 'console.log(typeof x);
var x = 5;',
 'javascript',
 '[{"key":"a","text":"number"},{"key":"b","text":"undefined"},{"key":"c","text":"ReferenceError"},{"key":"d","text":"null"}]',
 '["b"]',
 '`var` の宣言は巻き上げられるが、代入は巻き上げられない。宣言済みで未代入の変数は `undefined` であり、その `typeof` は "undefined" になる。',
 ARRAY['javascript','hoisting']),

('d0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000002', 'output_prediction', 'published', 4,
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

('d0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001', 'output_prediction', 'published', 5,
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
('d0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001', 'bug_finding', 'published', 3,
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

('d0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000002', 'bug_finding', 'published', 4,
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
('d0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001', 'fill_in_blank', 'published', 2,
 '配列を変換するメソッド',
 '各要素を2倍した新しい配列を作ります。空欄に入るメソッド名はどれですか。',
 'const doubled = [1, 2, 3].____((n) => n * 2);',
 'javascript',
 '[{"key":"a","text":"map"},{"key":"b","text":"forEach"},{"key":"c","text":"filter"},{"key":"d","text":"reduce"}]',
 '["a"]',
 '`map` は各要素に関数を適用した新しい配列を返す。`forEach` は返り値が undefined、`filter` は絞り込み用。',
 ARRAY['javascript','array']),

('d0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', 'fill_in_blank', 'published', 1,
 'リソースを作成する HTTP メソッド',
 'REST API で新しいリソースを作成するときに使うメソッドはどれですか。',
 NULL,
 NULL,
 '[{"key":"a","text":"GET"},{"key":"b","text":"POST"},{"key":"c","text":"DELETE"},{"key":"d","text":"HEAD"}]',
 '["b"]',
 '`POST` はサーバ側で新しいリソースを作成する。`GET` と `HEAD` は安全（副作用なし）なメソッドで、作成には使わない。',
 ARRAY['http','rest']),

-- --- best_practice ----------------------------------------------------------
('d0000000-0000-0000-0000-00000000000a', 'b0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', 'best_practice', 'published', 2,
 'バリデーション失敗時のステータスコード',
 'リクエストボディの必須項目が欠けていたとき、返すべきステータスコードはどれですか。',
 NULL,
 NULL,
 '[{"key":"a","text":"400 Bad Request"},{"key":"b","text":"401 Unauthorized"},{"key":"c","text":"404 Not Found"},{"key":"d","text":"500 Internal Server Error"}]',
 '["a"]',
 'クライアント側の入力不備は 400 系。認証が無い場合は 401、権限不足は 403。500 はサーバ側の想定外エラーに使うもので、入力不備に使うと監視のノイズになる。',
 ARRAY['http','rest','best-practice']),

('d0000000-0000-0000-0000-00000000000b', 'b0000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000001', 'best_practice', 'published', 5,
 'REST のエンドポイント命名',
 'ユーザーの注文一覧を取得するエンドポイントとして、REST の慣習に最も沿うものはどれですか。',
 NULL,
 NULL,
 '[{"key":"a","text":"GET /users/{id}/orders"},{"key":"b","text":"GET /getUserOrders?id={id}"},{"key":"c","text":"POST /users/orders/fetch"},{"key":"d","text":"GET /orders/getByUser/{id}"}]',
 '["a"]',
 'REST はリソースを名詞の階層で表し、操作は HTTP メソッドで表現する。URL に動詞を入れる設計はメソッドの意味と重複する。',
 ARRAY['rest','api-design','best-practice']),

('d0000000-0000-0000-0000-00000000000c', 'b0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'code_reading', 'published', 2,
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

-- レビュー画面（admin）の確認用に、レビュー待ち（decision IS NULL）の問題も入れておく。
INSERT INTO question (
    id, skill_node_id, raw_source_id, type, status, difficulty,
    title, body, code, code_language, choices, correct_keys, explanation, tags,
    prompt_version, model_id, gen_tokens, generated_at
) VALUES
('d0000000-0000-0000-0000-00000000000d', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'output_prediction', 'needs_review', 3,
 '暗黙の型変換',
 '次のコードの出力を予測してください。',
 'console.log([] + {});',
 'javascript',
 '[{"key":"a","text":"[object Object]"},{"key":"b","text":"{}"},{"key":"c","text":"0"},{"key":"d","text":"NaN"}]',
 '["a"]',
 '配列は空文字列に、オブジェクトは "[object Object]" に変換されて連結される。',
 ARRAY['javascript','coercion'],
 'question_gen.v1', 'claude-haiku-4-5-20251001', 812, now()),

('d0000000-0000-0000-0000-00000000000e', 'b0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'output_prediction', 'needs_review', 2,
 '配列の型強制と + 演算子',
 '次のコードを実行したときの出力として正しいものはどれですか。',
 E'const a = [1, 2];\nconst b = [3, 4];\nconsole.log(a + b);',
 'javascript',
 '[{"key":"a","text":"[1, 2, 3, 4]"},{"key":"b","text":"\"1,23,4\""},{"key":"c","text":"NaN"},{"key":"d","text":"undefined"}]',
 '["b"]',
 '+ 演算子で配列を使うと、JavaScript は配列を文字列に型強制します。a.toString() は "1,2" に、b.toString() は "3,4" になり、文字列連結により "1,23,4" が出力されます。a は配列連結を期待した誤答、c は「無効な操作は NaN」という誤解、d は型エラーだと思い込んだ誤答です。',
 ARRAY['type-coercion','operator','string-conversion'],
 'question_gen.v1', 'claude-haiku-4-5-20251001', 950, now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO review_queue (question_id, decision, created_at) VALUES
    ('d0000000-0000-0000-0000-00000000000d', NULL, now()),
    ('d0000000-0000-0000-0000-00000000000e', NULL, now())
ON CONFLICT (question_id) WHERE decision IS NULL DO NOTHING;

-- ---------------------------------------------------------------------------
-- テストユーザーと進捗のバリエーション
-- external_id は AUTH_MODE=dev の X-Dev-User ヘッダにそのまま渡す値
-- （LOCAL_DEV.md §5.4）。UI の各状態を確認できるよう3種類用意する。
-- ---------------------------------------------------------------------------

INSERT INTO app_user (id, external_id, display_name, email) VALUES
    ('e0000000-0000-0000-0000-000000000001', 'seed-user-01', '新規ユーザー',           'seed-user-01@example.test'),
    ('e0000000-0000-0000-0000-000000000002', 'seed-user-02', '学習中ユーザー',         'seed-user-02@example.test'),
    ('e0000000-0000-0000-0000-000000000003', 'seed-user-03', '復習が溜まったユーザー', 'seed-user-03@example.test')
ON CONFLICT (id) DO NOTHING;

-- user_progress は表示用キャッシュ。streak_days / last_studied_on は daily_task
-- からの逆算結果と一致する値を入れておく（キャッシュと真実の源のズレを作らない）。
INSERT INTO user_progress (user_id, xp, level, streak_days, last_studied_on, hearts, hearts_updated_at, current_skill_node_id) VALUES
    ('e0000000-0000-0000-0000-000000000001',    0, 1, 0, NULL,                       5, now(), 'b0000000-0000-0000-0000-000000000001'),
    ('e0000000-0000-0000-0000-000000000002',  450, 3, 2, CURRENT_DATE - 1,           4, now(), 'b0000000-0000-0000-0000-000000000003'),
    ('e0000000-0000-0000-0000-000000000003', 1200, 5, 0, CURRENT_DATE - 5,           2, now(), 'b0000000-0000-0000-0000-000000000004')
ON CONFLICT (user_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- タスクスロット定義（各ユーザー5スロット）
-- difficulty NULL のスロットは、サーバが user_type_stat の正答率から推奨レベルを解決する。
-- ---------------------------------------------------------------------------

INSERT INTO user_task (user_id, slot_no, question_type, language, difficulty) VALUES
    ('e0000000-0000-0000-0000-000000000001', 1, 'code_reading',      'javascript', 1),
    ('e0000000-0000-0000-0000-000000000001', 2, 'output_prediction', 'javascript', 1),
    ('e0000000-0000-0000-0000-000000000001', 3, 'fill_in_blank',     '',           1),
    ('e0000000-0000-0000-0000-000000000001', 4, 'fill_in_blank',     'javascript', 2),
    ('e0000000-0000-0000-0000-000000000001', 5, 'best_practice',     '',           2),

    ('e0000000-0000-0000-0000-000000000002', 1, 'code_reading',      'javascript', 1),
    ('e0000000-0000-0000-0000-000000000002', 2, 'output_prediction', 'javascript', NULL),
    ('e0000000-0000-0000-0000-000000000002', 3, 'bug_finding',       'javascript', 3),
    ('e0000000-0000-0000-0000-000000000002', 4, 'fill_in_blank',     '',           NULL),
    ('e0000000-0000-0000-0000-000000000002', 5, 'best_practice',     '',           2),

    ('e0000000-0000-0000-0000-000000000003', 1, 'output_prediction', 'javascript', 4),
    ('e0000000-0000-0000-0000-000000000003', 2, 'bug_finding',       'javascript', 4),
    ('e0000000-0000-0000-0000-000000000003', 3, 'code_reading',      'javascript', 2),
    ('e0000000-0000-0000-0000-000000000003', 4, 'best_practice',     '',           5),
    ('e0000000-0000-0000-0000-000000000003', 5, 'fill_in_blank',     'javascript', 2)
ON CONFLICT (user_id, slot_no) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 回答履歴（追記専用ログ）。
-- ---------------------------------------------------------------------------

INSERT INTO attempt (id, user_id, question_id, selected_keys, is_correct, duration_ms, answered_at) VALUES
    ('f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000001', '["b"]', true,  4200, now() - INTERVAL '2 day'),
    ('f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000003', '["a"]', false, 9100, now() - INTERVAL '2 day'),
    ('f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000006', '["a"]', true,  5300, now() - INTERVAL '2 day'),
    ('f0000000-0000-0000-0000-000000000004', 'e0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-00000000000c', '["a"]', true,  3800, now() - INTERVAL '1 day'),
    ('f0000000-0000-0000-0000-000000000005', 'e0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000004', '["a"]', true,  7200, now() - INTERVAL '1 day'),
    ('f0000000-0000-0000-0000-000000000006', 'e0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000007', '["a"]', false, 12100, now() - INTERVAL '1 day'),
    ('f0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000002', '["c"]', true,  4600, now()),
    ('f0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000001', '["b"]', true,  3100, now() - INTERVAL '5 day'),
    ('f0000000-0000-0000-0000-000000000009', 'e0000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000004', '["c"]', false, 15200, now() - INTERVAL '5 day'),
    ('f0000000-0000-0000-0000-00000000000a', 'e0000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000005', '["a"]', true,  8300, now() - INTERVAL '5 day')
ON CONFLICT (id) DO NOTHING;

-- 種別×言語ごとの正答率キャッシュ（attempt から再構築可能な導出データ）。
INSERT INTO user_type_stat (user_id, question_type, language, attempts, corrects, last_difficulty) VALUES
    ('e0000000-0000-0000-0000-000000000002', 'code_reading',      'javascript', 2, 2, 2),
    ('e0000000-0000-0000-0000-000000000002', 'output_prediction', 'javascript', 2, 1, 4),
    ('e0000000-0000-0000-0000-000000000002', 'bug_finding',       'javascript', 2, 1, 4),
    ('e0000000-0000-0000-0000-000000000003', 'output_prediction', 'javascript', 1, 0, 4),
    ('e0000000-0000-0000-0000-000000000003', 'code_reading',      'javascript', 1, 1, 1)
ON CONFLICT (user_id, question_type, language) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 日次タスク割当と消化状態。連続タスク消化日数はこの表から逆算する。
--   seed-user-01: 割当なし（streak 0）
--   seed-user-02: 2日前・1日前を全消化、本日は一部のみ（streak = 2）
--   seed-user-03: 5日前に全消化、以降ギャップ（直近が古いので streak 0）
-- 便宜上スロット1〜3のみ割り当てる（残りスロットは条件一致問題が無かった想定）。
-- ---------------------------------------------------------------------------

INSERT INTO daily_task (user_id, activity_date, slot_no, question_type, language, difficulty, question_id, attempt_id, completed_at) VALUES
    -- seed-user-02: 2日前（全消化）
    ('e0000000-0000-0000-0000-000000000002', CURRENT_DATE - 2, 1, 'code_reading',      'javascript', 1, 'd0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', now() - INTERVAL '2 day'),
    ('e0000000-0000-0000-0000-000000000002', CURRENT_DATE - 2, 2, 'output_prediction', 'javascript', 2, 'd0000000-0000-0000-0000-000000000003', 'f0000000-0000-0000-0000-000000000002', now() - INTERVAL '2 day'),
    ('e0000000-0000-0000-0000-000000000002', CURRENT_DATE - 2, 3, 'bug_finding',       'javascript', 3, 'd0000000-0000-0000-0000-000000000006', 'f0000000-0000-0000-0000-000000000003', now() - INTERVAL '2 day'),
    -- seed-user-02: 1日前（全消化）
    ('e0000000-0000-0000-0000-000000000002', CURRENT_DATE - 1, 1, 'code_reading',      'javascript', 2, 'd0000000-0000-0000-0000-00000000000c', 'f0000000-0000-0000-0000-000000000004', now() - INTERVAL '1 day'),
    ('e0000000-0000-0000-0000-000000000002', CURRENT_DATE - 1, 2, 'output_prediction', 'javascript', 4, 'd0000000-0000-0000-0000-000000000004', 'f0000000-0000-0000-0000-000000000005', now() - INTERVAL '1 day'),
    ('e0000000-0000-0000-0000-000000000002', CURRENT_DATE - 1, 3, 'bug_finding',       'javascript', 4, 'd0000000-0000-0000-0000-000000000007', 'f0000000-0000-0000-0000-000000000006', now() - INTERVAL '1 day'),
    -- seed-user-02: 本日（一部のみ消化 → 本日はまだ消化扱いにならない）
    ('e0000000-0000-0000-0000-000000000002', CURRENT_DATE,     1, 'code_reading',      'javascript', 3, 'd0000000-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000007', now()),
    ('e0000000-0000-0000-0000-000000000002', CURRENT_DATE,     2, 'output_prediction', 'javascript', 5, 'd0000000-0000-0000-0000-000000000005', NULL, NULL),
    ('e0000000-0000-0000-0000-000000000002', CURRENT_DATE,     3, 'fill_in_blank',     '',           1, 'd0000000-0000-0000-0000-000000000009', NULL, NULL),
    -- seed-user-03: 5日前（全消化）、以降ギャップ
    ('e0000000-0000-0000-0000-000000000003', CURRENT_DATE - 5, 1, 'output_prediction', 'javascript', 4, 'd0000000-0000-0000-0000-000000000004', 'f0000000-0000-0000-0000-000000000009', now() - INTERVAL '5 day'),
    ('e0000000-0000-0000-0000-000000000003', CURRENT_DATE - 5, 2, 'output_prediction', 'javascript', 5, 'd0000000-0000-0000-0000-000000000005', 'f0000000-0000-0000-0000-00000000000a', now() - INTERVAL '5 day'),
    ('e0000000-0000-0000-0000-000000000003', CURRENT_DATE - 5, 3, 'code_reading',      'javascript', 1, 'd0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000008', now() - INTERVAL '5 day')
ON CONFLICT (user_id, activity_date, slot_no) DO NOTHING;

-- 復習キュー（SM-2）。seed-user-03 は期限切れの復習が溜まっている状態。
INSERT INTO srs_state (user_id, question_id, easiness, interval_days, repetitions, due_on, last_reviewed_at) VALUES
    ('e0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000001', 2.6, 4, 2, CURRENT_DATE + 2, now() - INTERVAL '2 day'),
    ('e0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000003', 2.3, 1, 1, CURRENT_DATE,     now() - INTERVAL '1 day'),
    ('e0000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000001', 2.5, 3, 2, CURRENT_DATE - 6, now() - INTERVAL '9 day'),
    ('e0000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000004', 1.9, 1, 1, CURRENT_DATE - 7, now() - INTERVAL '8 day'),
    ('e0000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000005', 2.1, 2, 1, CURRENT_DATE - 3, now() - INTERVAL '5 day')
ON CONFLICT (user_id, question_id) DO NOTHING;

COMMIT;
