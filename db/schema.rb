# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_25_000009) do
  create_table "audit_logs", force: :cascade do |t|
    t.integer "organization_id", null: false
    t.integer "user_id"
    t.string "action", null: false
    t.string "target_type", null: false
    t.bigint "target_id"
    t.json "changes_json"
    t.datetime "created_at", null: false
    t.index ["organization_id", "created_at"], name: "index_audit_logs_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_audit_logs_on_organization_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "document_types", force: :cascade do |t|
    t.integer "organization_id", null: false
    t.string "name", null: false
    t.boolean "required", default: true, null: false
    t.integer "renew_interval_months"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "name"], name: "index_document_types_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_document_types_on_organization_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "organization_id", null: false
    t.integer "staff_member_id", null: false
    t.integer "residence_card_id", null: false
    t.string "kind", null: false
    t.date "notified_on", null: false
    t.string "message", null: false
    t.string "mail_subject", null: false
    t.text "mail_body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_notifications_on_organization_id"
    t.index ["residence_card_id", "kind"], name: "index_notifications_on_residence_card_id_and_kind", unique: true
    t.index ["residence_card_id"], name: "index_notifications_on_residence_card_id"
    t.index ["staff_member_id"], name: "index_notifications_on_staff_member_id"
    t.check_constraint "kind IN ('expiry_90','expiry_60','expiry_30','expired')", name: "notifications_kind_check"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "residence_cards", force: :cascade do |t|
    t.integer "organization_id", null: false
    t.integer "staff_member_id", null: false
    t.string "status_of_residence", null: false
    t.string "card_number_last4", limit: 4, null: false
    t.date "issued_on"
    t.date "expires_on", null: false
    t.boolean "permission_for_activity", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_residence_cards_on_organization_id"
    t.index ["staff_member_id", "expires_on"], name: "index_residence_cards_on_staff_member_id_and_expires_on"
    t.index ["staff_member_id"], name: "index_residence_cards_on_staff_member_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "staff_documents", force: :cascade do |t|
    t.integer "organization_id", null: false
    t.integer "staff_member_id", null: false
    t.integer "document_type_id", null: false
    t.string "state", default: "missing", null: false
    t.date "submitted_on"
    t.date "expires_on"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_type_id"], name: "index_staff_documents_on_document_type_id"
    t.index ["organization_id"], name: "index_staff_documents_on_organization_id"
    t.index ["staff_member_id", "document_type_id"], name: "index_staff_documents_on_staff_member_id_and_document_type_id", unique: true
    t.index ["staff_member_id"], name: "index_staff_documents_on_staff_member_id"
    t.check_constraint "state IN ('missing','submitted','approved','expired')", name: "staff_documents_state_check"
  end

  create_table "staff_members", force: :cascade do |t|
    t.integer "organization_id", null: false
    t.string "employee_code", null: false
    t.string "full_name", null: false
    t.string "full_name_kana"
    t.date "birth_on", null: false
    t.string "nationality", null: false
    t.string "preferred_language", default: "ja", null: false
    t.date "hired_on", null: false
    t.date "left_on"
    t.string "status", default: "active", null: false
    t.string "job_title"
    t.string "workplace"
    t.integer "hourly_wage_yen"
    t.decimal "weekly_hours", precision: 4, scale: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "employee_code"], name: "index_staff_members_on_organization_id_and_employee_code", unique: true
    t.index ["organization_id"], name: "index_staff_members_on_organization_id"
    t.check_constraint "status IN ('active','left')", name: "staff_members_status_check"
  end

  create_table "users", force: :cascade do |t|
    t.integer "organization_id", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "role", default: "member", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.check_constraint "role IN ('admin','member')", name: "users_role_check"
  end

  add_foreign_key "audit_logs", "organizations"
  add_foreign_key "audit_logs", "users", on_delete: :nullify
  add_foreign_key "document_types", "organizations"
  add_foreign_key "notifications", "organizations"
  add_foreign_key "notifications", "residence_cards"
  add_foreign_key "notifications", "staff_members"
  add_foreign_key "residence_cards", "organizations"
  add_foreign_key "residence_cards", "staff_members"
  add_foreign_key "sessions", "users"
  add_foreign_key "staff_documents", "document_types"
  add_foreign_key "staff_documents", "organizations"
  add_foreign_key "staff_documents", "staff_members"
  add_foreign_key "staff_members", "organizations"
  add_foreign_key "users", "organizations"
end
