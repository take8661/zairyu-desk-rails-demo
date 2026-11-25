class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.references :organization, null: false, foreign_key: true
      # ジョブ等のシステム操作は NULL。ユーザーを削除しても履歴は残す（nullify）
      t.references :user, null: true, foreign_key: { on_delete: :nullify }
      t.string :action, null: false
      t.string :target_type, null: false
      t.bigint :target_id
      t.json :changes_json
      t.datetime :created_at, null: false
    end
    add_index :audit_logs, [ :organization_id, :created_at ]
  end
end
