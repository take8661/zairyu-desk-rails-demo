class CreateStaffMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :staff_members do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :employee_code, null: false
      t.string :full_name, null: false
      t.string :full_name_kana
      t.date :birth_on, null: false
      t.string :nationality, null: false
      t.string :preferred_language, null: false, default: "ja"
      t.date :hired_on, null: false
      t.date :left_on
      t.string :status, null: false, default: "active"
      t.string :job_title
      t.string :workplace
      t.integer :hourly_wage_yen
      t.decimal :weekly_hours, precision: 4, scale: 1

      t.timestamps

      t.check_constraint "status IN ('active','left')", name: "staff_members_status_check"
    end
    add_index :staff_members, [ :organization_id, :employee_code ], unique: true
  end
end
