# コーディング規約

- **テナント分離**：コントローラは必ず `Current.organization` 経由で取得する（`current_organization.staff_members.find(...)`）。素の `StaffMember.find` 等は禁止で、`spec/lint/tenant_scope_spec.rb` が検出する。フォームから `organization_id` を受け取らない。他組織のIDは404。
- **ジョブ・サービス**：`Current` を使わず、組織IDを引数で受ける。ジョブは薄い包みにし、処理本体は `ExpiryAlertService`／`DocumentExpiryService` に置く。
- **列挙**：string＋モデルの定数＋CHECK制約（整数 enum は使わない）。
- **日付**：「今日」は `Date.current`（Tokyo）。期限の区分は `ExpiryBand.for(days_left)` の1か所だけ。
- **個人情報**：在留カード番号は下4桁のみ保存。ログは `filter_parameters` でマスクする。
- **権限**：`app/policies/` の自前 Policy。画面ごとに `authorize!` を呼ぶ。
- **出力**：CSV は先頭が `= + - @` のセルをエスケープする。PDF の日本語は同梱の静的TTF。
- **静的検査・テスト**：`bundle exec rubocop` は違反0、`bundle exec rspec` は全件合格を保つ。
