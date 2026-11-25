class CreateDocumentTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :document_types do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :required, null: false, default: true
      t.integer :renew_interval_months

      t.timestamps
    end
    add_index :document_types, [ :organization_id, :name ], unique: true
  end
end
