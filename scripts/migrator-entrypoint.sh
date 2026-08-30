#!/usr/bin/env bash
# codetrain-core migrator のエントリポイント。
#
# DATABASE_URL を受け取り、以下のサブコマンドを提供する。
#   up            マイグレーションを最新まで適用
#   down [N]      N 個戻す（既定 1）
#   redo          up → down → up の往復確認（REPOSITORIES.md §4.3 の CI 相当をローカルでも）
#   version       現在のバージョン
#   drop          スキーマを丸ごと落とす
#   seed          seed/*.sql を投入（内部で up を先に実行する）
#   psql [args]   デバッグ用に psql をそのまま呼ぶ
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL が設定されていません}"

MIGRATIONS_DIR=/migrations
SEED_DIR=/seed

migrate_cmd() {
  migrate -path "$MIGRATIONS_DIR" -database "$DATABASE_URL" "$@"
}

cmd="${1:-up}"
shift || true

case "$cmd" in
  up)
    migrate_cmd up
    ;;
  down)
    migrate_cmd down "${1:-1}"
    ;;
  redo)
    # down で消える範囲を確認するための往復。CI で流す検証と同じ手順。
    migrate_cmd up
    migrate_cmd down -all
    migrate_cmd up
    ;;
  version)
    migrate_cmd version
    ;;
  drop)
    migrate_cmd drop -f
    ;;
  force)
    migrate_cmd force "${1:?force にはバージョン番号が必要です}"
    ;;
  seed)
    # シードは常に最新スキーマの上に載せる。
    migrate_cmd up
    shopt -s nullglob
    files=("$SEED_DIR"/*.sql)
    if [ ${#files[@]} -eq 0 ]; then
      echo "seed: $SEED_DIR に .sql がありません" >&2
      exit 1
    fi
    for f in "${files[@]}"; do
      echo "seed: applying $(basename "$f")"
      # ON_ERROR_STOP=1: 途中で失敗したら黙って続けない
      psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f "$f"
    done
    echo "seed: done"
    ;;
  psql)
    exec psql "$DATABASE_URL" "$@"
    ;;
  *)
    echo "unknown command: $cmd" >&2
    echo "usage: migrator {up|down [N]|redo|version|drop|force V|seed|psql}" >&2
    exit 2
    ;;
esac
