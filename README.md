# codetrain-core

`codetrain-api` と `codetrain-pipeline` の**契約**を1箇所に集めるリポジトリ。
位置づけの詳細は [Document/REPOSITORIES.md](../Document/REPOSITORIES.md) §2.1。

```
migrations/   DB マイグレーション（golang-migrate 形式）
seed/         ローカル開発用シードデータ
pkg/domain/   api / pipeline が共有するドメイン型
scripts/      migrator イメージのエントリポイント
```

## マイグレーションを書けるのは core だけ

`api` と `pipeline` の両方がマイグレーションを打てる状態は、デプロイ順序次第で壊れる。
DB スキーマを変更するのは **core の migrator だけ**とする。

- ツールは **golang-migrate**（OPEN_ISSUES D-1 の決定）。
- **`.down.sql` を必ず書く。** ロールバック手段のないマイグレーションは本番で詰む。
  往復は `make migrate-redo`（devenv）または `migrator redo` で確認できる。
- 破壊的変更は避け、**expand / contract の2段階**で入れる（REPOSITORIES.md §3.1）。
  1. expand: 列・テーブルを追加する（旧コードでも動く）
  2. contract: 旧コードが使わなくなった列を、次のリリースで削除する

新しいマイグレーションはファイル名の連番を1つ進めて追加する。

```
migrations/000002_add_question_language.up.sql
migrations/000002_add_question_language.down.sql
```

## ローカルでの実行

`codetrain-devenv` の Makefile から実行する（[Document/LOCAL_DEV.md](../Document/LOCAL_DEV.md) §10.2）。

```bash
cd ../codetrain-devenv
make migrate        # 最新まで適用
make seed           # migrate してからシード投入
make migrate-redo   # up → down -all → up の往復検証
make reset-db       # ボリュームごと作り直して migrate + seed
```

## Go module としての参照

`api` / `pipeline` は core を Go module としてバージョン固定で参照する。
ただし **core がまだ GitHub に push されていない間は**、`go.mod` の
`replace github.com/gabaison-2026-09/codetrain-core => ../codetrain-core` で
隣のチェックアウトを指している（LOCAL_DEV.md §10.1）。
core を push してタグを打った時点で `replace` を外し、`GOPRIVATE` 経由の取得に切り替える。

## Go のバージョン

`.go-version`（goenv）は**ホストの補助ツールチェーン向け**であり、実際のビルドは
利用側の Dockerfile のベースイメージが決める（LOCAL_DEV.md §9.2）。
バージョンを上げるときは両方を同じ PR で更新すること。
