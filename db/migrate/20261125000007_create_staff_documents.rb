class CreateStaffDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :staff_documents do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :staff_member, null: false, foreign_key: true
      t.references :document_type, null: false, foreign_key: true
      t.string :state, null: false, default: "missing"
      t.date :submitted_on
      t.date :expires_on
      t.text :note

      t.timestamps

      t.check_constraint "state IN ('missing','submitted','approved','expired')", name: "staff_documents_state_check"
    end
    add_index :staff_documents, [ :staff_member_id, :document_type_id ], unique: true
  end
end
