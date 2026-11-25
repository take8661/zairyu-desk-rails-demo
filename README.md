# Zairyu Desk

外国人スタッフの在留期限と提出書類を管理する、マルチテナント（組織ごとにデータを分離）の Rails アプリです。個人のポートフォリオとして作った**デモ**で、画面・データはすべて架空です。

> **架空のデータによるデモです。** 登場する組織・人物・数値はすべて架空で、実在のものとは関係ありません。PDF・CSV は行政の正式様式ではありません。

## ドキュメント
仕様書・テストの中身と結果・作成の経緯・使用説明書は [docs/README.md](docs/README.md) にまとめています。

## 何ができるか
- ダッシュボードで、在留期限が近いスタッフ（90／60／30日以内・期限切れ）と書類の未提出・期限切れを一目で確認
- スタッフの登録・編集、在留カード履歴の追加（カード番号は下4桁のみ保存）
- 書類チェックリスト（未提出 → 提出済み → 承認済み、期限切れは自動設定）
- 毎日の期限チェック（通知を作成。メールは送らず「送信予定メール（デモ表示）」として画面表示）と「今すぐ実行」
- 在留期限一覧 PDF（日本語・A4横）、提出用 CSV（Shift_JIS／UTF-8、和暦／西暦）
- 組織設定（ユーザー・書類種別）、操作の監査ログ

## 起動手順
Windows で、Ruby 3.4（RubyInstaller＋DevKit）と Bundler が入っている前提です。
1. `起動.bat` をダブルクリック（初回は `bundle install`・DB作成・デモデータ投入を自動で行い、ブラウザで開きます）
2. ログイン：`admin@demo-a.example`（管理者）／`member@demo-a.example`（一般）／別組織 `admin@demo-b.example`。パスワードは架空のデモ用の値 `demo-pass-2026`（環境変数 `DEMO_PASSWORD` で変更可）

詳しくは `起動方法.md`。**日本語を含むフォルダ**に置くと Ruby が `bin/rails` を読めないことがあるため、`C:\projects\zairyu-desk-rails-demo` のような英数字だけのパスに置いてください。

## テスト実行方法
`テスト実行.bat`、または `bundle exec rspec`（全件）と `bundle exec rubocop`。
- 結果（2026-11-25、開発環境で実測）：RSpec 285 examples, 0 failures／RuboCop 116 files, no offenses
- **SimpleCov 行カバレッジ：99.10%（771 / 778）**
- テナント分離の専用テスト：`spec/requests/tenant_isolation_spec.rb`、`spec/requests/tenant_isolation_exports_spec.rb`、静的検査 `spec/lint/tenant_scope_spec.rb`

## 技術構成
Rails 8.1／Ruby 3.4／SQLite／標準認証（bcrypt）／ActiveJob（async）／Prawn＋prawn-table（PDF）／RSpec・FactoryBot・Capybara・WebMock・SimpleCov。Solid Queue・外部の管理画面gem・認可gemは使っていません（権限は `app/policies/`、テナント分離は `Current.organization` 経由の取得のみ）。定期実行は、起動時の1回・画面の「今すぐ実行」・`ruby bin/rails zairyu:daily` で代替しています。

## AIエージェント
この実装は、AIエージェント（役割分担した複数のAI）が仕様書にもとづいて書き、別のAIがレビュー・再検査する流れで作りました。作り方の流れは `docs/development_process.md`、設計の判断は `docs/review_log.md`、コード規約は `docs/coding_guidelines.md`、テーブル構成は `docs/er.md` に記録しています。お知らせ文の自動作成（Claude API 連携）は今回の範囲に含めていません。

## フォントとライセンス
PDF の日本語は同梱の Noto Sans JP（SIL Open Font License 1.1。全文は `vendor/fonts/OFL-NotoSansJP.txt`）。Prawn は Ruby ライセンス／GPLv2／GPLv3 から選べるため、Ruby ライセンスで利用しています。

## 画面写真
**撮影待ち**（`docs/screenshots/` に、ダッシュボード・スタッフ一覧・書類チェックリスト・PDF の4枚以上を、起動後に撮影して置きます）。未撮影のため、この項目は未完了です。
