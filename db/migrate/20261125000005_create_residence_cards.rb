class CreateResidenceCards < ActiveRecord::Migration[8.1]
  def change
    create_table :residence_cards do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :staff_member, null: false, foreign_key: true
      t.string :status_of_residence, null: false
      t.string :card_number_last4, limit: 4, null: false
      t.date :issued_on
      t.date :expires_on, null: false
      t.boolean :permission_for_activity, null: false, default: false

      t.timestamps
    end
    add_index :residence_cards, [ :staff_member_id, :expires_on ]
  end
end
