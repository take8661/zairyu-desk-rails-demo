class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :staff_member, null: false, foreign_key: true
      t.references :residence_card, null: false, foreign_key: true
      t.string :kind, null: false
      t.date :notified_on, null: false
      t.string :message, null: false
      t.string :mail_subject, null: false
      t.text :mail_body, null: false

      t.timestamps

      t.check_constraint "kind IN ('expiry_90','expiry_60','expiry_30','expired')", name: "notifications_kind_check"
    end
    # 同じ在留カード・同じ区分の通知は1行だけ（冪等性の根拠）
    add_index :notifications, [ :residence_card_id, :kind ], unique: true
  end
end
