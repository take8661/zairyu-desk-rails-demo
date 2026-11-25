# デモデータ。すべて架空。日付は実行日からの相対。
# 冪等：find_or_create_by／find_by のみで、既にあるものは更新しない（再実行しても件数が変わらない）。
today = Date.current
# ログイン用の初期値は環境変数 DEMO_PASSWORD で上書きできる（架空のデモ用の値。実在のものではない）
login_secret = ENV.fetch("DEMO_PASSWORD", "demo-pass-2026")

def seed_organization(name:, slug:)
  Organization.find_or_create_by!(slug: slug) { |org| org.name = name }
end

def seed_user(organization, email:, role:, login_secret:)
  User.find_by(email_address: email) ||
    organization.users.create!(email_address: email, role: role, password: login_secret)
end

def seed_document_type(organization, name:, required:, renew_interval_months:)
  organization.document_types.find_or_create_by!(name: name) do |type|
    type.required = required
    type.renew_interval_months = renew_interval_months
  end
end

# スタッフと在留カードを作る（既にあれば何もしない）。新規に作った場合だけ true を返す。
def seed_staff(organization, attrs, cards)
  existing = organization.staff_members.find_by(employee_code: attrs[:employee_code])
  return [ existing, false ] if existing

  staff = organization.staff_members.build(attrs)
  cards.first(1).each { |card| staff.residence_cards.build(card.merge(organization_id: organization.id)) }
  staff.save!
  # 2枚目以降（在留期間更新の履歴）
  cards.drop(1).each do |card|
    staff.residence_cards.find_or_create_by!(expires_on: card[:expires_on]) do |rc|
      rc.assign_attributes(card.merge(organization_id: organization.id))
    end
  end
  [ staff, true ]
end

# 書類の状態を設定する（新規作成したスタッフだけ。遷移規則はシードなので迂回する）
def seed_documents(staff, states, today)
  staff.staff_documents.includes(:document_type).each do |document|
    state, offset = states[document.document_type.name]
    next if state.nil? || state == "missing"

    document.skip_transition_check = true
    submitted_on = today + (offset || -30)
    document.update!(state: state, submitted_on: submitted_on)
  end
end

# =====================================================================
# 組織A「あおぞら製作所（架空）」
# =====================================================================
org_a = seed_organization(name: "あおぞら製作所（架空）", slug: "demo-a")
seed_user(org_a, email: "admin@demo-a.example", role: "admin", login_secret: login_secret)
seed_user(org_a, email: "member@demo-a.example", role: "member", login_secret: login_secret)

doc_passport = "パスポート写し"
doc_card_copy = "在留カード写し"
doc_contract = "雇用契約書"
doc_insurance = "健康保険証写し"
doc_permit = "資格外活動許可書"

seed_document_type(org_a, name: doc_passport, required: true, renew_interval_months: nil)
seed_document_type(org_a, name: doc_card_copy, required: true, renew_interval_months: nil)
seed_document_type(org_a, name: doc_contract, required: true, renew_interval_months: 12)
seed_document_type(org_a, name: doc_insurance, required: true, renew_interval_months: nil)
seed_document_type(org_a, name: doc_permit, required: false, renew_interval_months: 12)

# 状態の指定: { 書類種別名 => [状態, 提出日（今日からの相対日数）] }。未指定の書類は missing のまま。
optional_approved = { doc_permit => [ "approved", -60 ] }

staff_a_rows = [
  { code: "A-001", name: "グエン・ヴァン・アン", nationality: "ベトナム", lang: "vi", status: "技術・人文知識・国際業務", days: 300,
    birth: Date.new(1993, 5, 14), hired: Date.new(2023, 4, 1), job: "設計補助", place: "本社設計室", wage: 1450, hours: 40.0, last4: "A1B2",
    old_card_days: -65,
    docs: { doc_passport => [ "approved", -200 ], doc_card_copy => [ "approved", -200 ], doc_contract => [ "approved", -30 ], doc_insurance => [ "submitted", -5 ] } },
  { code: "A-002", name: "チャン・ティ・マイ", nationality: "ベトナム", lang: "vi", status: "特定技能1号", days: 45,
    birth: Date.new(1998, 9, 2), hired: Date.new(2024, 6, 1), job: "金属加工", place: "第一工場", wage: 1250, hours: 40.0, last4: "C3D4",
    docs: { doc_passport => [ "approved", -150 ], doc_card_copy => [ "approved", -150 ], doc_contract => [ "approved", -40 ], doc_insurance => [ "submitted", -4 ] } },
  { code: "A-003", name: "マリア・サントス", nationality: "フィリピン", lang: "tl", status: "特定技能1号", days: 8,
    birth: Date.new(1996, 1, 23), hired: Date.new(2023, 11, 1), job: "組立", place: "第二工場", wage: 1230, hours: 38.0, last4: "E5F6",
    docs: { doc_passport => [ "approved", -180 ], doc_card_copy => [ "approved", -180 ] } },
  { code: "A-004", name: "プトゥ・ウィジャヤ", nationality: "インドネシア", lang: "id", status: "技能実習", days: -12,
    birth: Date.new(1999, 7, 30), hired: Date.new(2022, 10, 1), job: "溶接補助", place: "第一工場", wage: 1180, hours: 40.0, last4: "G7H8",
    docs: { doc_passport => [ "approved", -300 ], doc_card_copy => [ "approved", -300 ], doc_contract => [ "approved", -400 ], doc_insurance => [ "approved", -300 ] } },
  { code: "A-005", name: "リー・ウェイ", nationality: "中国", lang: "zh", status: "技術・人文知識・国際業務", days: 120,
    birth: Date.new(1990, 12, 8), hired: Date.new(2021, 4, 1), job: "品質管理", place: "品質管理課", wage: 1500, hours: 40.0, last4: "J9K1",
    old_card_days: -245,
    docs: { doc_passport => [ "approved", -250 ], doc_card_copy => [ "approved", -250 ], doc_contract => [ "approved", -60 ], doc_insurance => [ "submitted", -3 ] } },
  { code: "A-006", name: "ラム・バハドゥール・タパ", nationality: "ネパール", lang: "ne", status: "留学", days: 25,
    birth: Date.new(2001, 3, 17), hired: Date.new(2025, 4, 1), job: "梱包（アルバイト）", place: "出荷センター", wage: 1100, hours: 28.0, last4: "L2M3",
    permission: true,
    docs: { doc_passport => [ "approved", -120 ], doc_card_copy => [ "submitted", -2 ], doc_contract => [ "approved", -90 ], doc_insurance => [ "approved", -120 ] }.merge(optional_approved) },
  { code: "A-007", name: "チョー・ジン・ウー", nationality: "ミャンマー", lang: "my", status: "特定技能1号", days: 88,
    birth: Date.new(1997, 6, 5), hired: Date.new(2024, 2, 1), job: "塗装", place: "第二工場", wage: 1240, hours: 40.0, last4: "N4P5",
    docs: { doc_passport => [ "approved", -160 ], doc_card_copy => [ "approved", -160 ], doc_contract => [ "submitted", -6 ] } },
  { code: "A-008", name: "ジョン・カーター", nationality: "アメリカ", lang: "en", status: "技術・人文知識・国際業務", days: 700,
    birth: Date.new(1988, 10, 21), hired: Date.new(2019, 4, 1), job: "海外営業", place: "本社営業部", wage: 1900, hours: 40.0, last4: "Q6R7",
    docs: { doc_passport => [ "approved", -500 ], doc_contract => [ "approved", -20 ] } },
  { code: "A-009", name: "ファム・ティ・ラン", nationality: "ベトナム", lang: "vi", status: "技能実習", days: -3,
    birth: Date.new(2000, 2, 11), hired: Date.new(2022, 12, 1), job: "縫製", place: "第三工場", wage: 1180, hours: 40.0, last4: "S8T9",
    docs: { doc_passport => [ "approved", -320 ], doc_card_copy => [ "approved", -320 ], doc_contract => [ "approved", -400 ], doc_insurance => [ "submitted", -7 ] } },
  { code: "A-010", name: "シタ・グルン", nationality: "ネパール", lang: "ne", status: "家族滞在", days: 59,
    birth: Date.new(1995, 8, 26), hired: Date.new(2024, 9, 1), job: "検品（パート）", place: "出荷センター", wage: 1120, hours: 24.0, last4: "U1V2",
    permission: true,
    docs: { doc_passport => [ "submitted", -8 ], doc_card_copy => [ "approved", -140 ], doc_insurance => [ "approved", -140 ] }.merge(optional_approved) },
  { code: "A-011", name: "デウィ・レスタリ", nationality: "インドネシア", lang: "id", status: "特定技能1号", days: 75,
    birth: Date.new(1999, 4, 9), hired: Date.new(2024, 5, 1), job: "食品加工", place: "第三工場", wage: 1230, hours: 40.0, last4: "W3X4",
    docs: { doc_contract => [ "submitted", -9 ] } },
  { code: "A-012", name: "アン・トゥアン・レ", nationality: "ベトナム", lang: "vi", status: "特定技能2号", days: 10,
    birth: Date.new(1992, 11, 3), hired: Date.new(2020, 4, 1), job: "生産管理", place: "本社工場", wage: 1700, hours: 40.0, last4: "Y5Z6",
    left: true,
    docs: { doc_passport => [ "approved", -400 ], doc_card_copy => [ "approved", -400 ], doc_contract => [ "approved", -100 ],
            doc_insurance => [ "approved", -400 ] }.merge(optional_approved) }
]

staff_a_rows.each do |row|
  attrs = {
    employee_code: row[:code], full_name: row[:name], full_name_kana: row[:name], birth_on: row[:birth],
    nationality: row[:nationality], preferred_language: row[:lang], hired_on: row[:hired],
    job_title: row[:job], workplace: row[:place], hourly_wage_yen: row[:wage], weekly_hours: row[:hours]
  }
  if row[:left]
    attrs[:status] = "left"
    attrs[:left_on] = today - 30
  end

  expires_on = today + row[:days]
  cards = [ { status_of_residence: row[:status], card_number_last4: row[:last4], expires_on: expires_on,
              issued_on: expires_on - 1095, permission_for_activity: row.fetch(:permission, false) } ]
  if row[:old_card_days]
    old_expires_on = today + row[:old_card_days]
    cards << { status_of_residence: row[:status], card_number_last4: row[:last4], expires_on: old_expires_on,
               issued_on: old_expires_on - 1095, permission_for_activity: false }
  end

  staff, created = seed_staff(org_a, attrs, cards)
  seed_documents(staff, row[:docs], today) if created
end

# =====================================================================
# 組織B「みなと物流（架空）」（分離確認用）
# =====================================================================
org_b = seed_organization(name: "みなと物流（架空）", slug: "demo-b")
seed_user(org_b, email: "admin@demo-b.example", role: "admin", login_secret: login_secret)

seed_document_type(org_b, name: doc_passport, required: true, renew_interval_months: nil)
seed_document_type(org_b, name: doc_card_copy, required: true, renew_interval_months: nil)
seed_document_type(org_b, name: doc_contract, required: true, renew_interval_months: 12)

staff_b_rows = [
  { code: "B-001", name: "ブイ・ミン・クアン", nationality: "ベトナム", lang: "vi", status: "特定技能1号", days: 20,
    birth: Date.new(1997, 3, 3), hired: Date.new(2024, 4, 1), job: "仕分け", place: "港湾倉庫", wage: 1250, hours: 40.0, last4: "B1C1" },
  { code: "B-002", name: "ソムチャイ・ワンナ", nationality: "タイ", lang: "en", status: "技能実習", days: 70,
    birth: Date.new(1999, 9, 9), hired: Date.new(2023, 8, 1), job: "フォークリフト補助", place: "港湾倉庫", wage: 1200, hours: 40.0, last4: "B2C2" },
  { code: "B-003", name: "カマラ・デヴィ", nationality: "ネパール", lang: "ne", status: "留学", days: 200,
    birth: Date.new(2002, 1, 15), hired: Date.new(2025, 6, 1), job: "梱包（アルバイト）", place: "配送センター", wage: 1100, hours: 28.0, last4: "B3C3" },
  { code: "B-004", name: "ワン・ジエ", nationality: "中国", lang: "zh", status: "技術・人文知識・国際業務", days: -5,
    birth: Date.new(1991, 7, 19), hired: Date.new(2020, 10, 1), job: "貿易事務", place: "本社事務所", wage: 1600, hours: 40.0, last4: "B4C4" },
  { code: "B-005", name: "ホセ・リベラ", nationality: "フィリピン", lang: "tl", status: "永住者", days: 400,
    birth: Date.new(1985, 12, 24), hired: Date.new(2018, 4, 1), job: "運行管理", place: "配送センター", wage: 1650, hours: 40.0, last4: "B5C5" }
]

staff_b_rows.each do |row|
  attrs = {
    employee_code: row[:code], full_name: row[:name], full_name_kana: row[:name], birth_on: row[:birth],
    nationality: row[:nationality], preferred_language: row[:lang], hired_on: row[:hired],
    job_title: row[:job], workplace: row[:place], hourly_wage_yen: row[:wage], weekly_hours: row[:hours]
  }
  expires_on = today + row[:days]
  cards = [ { status_of_residence: row[:status], card_number_last4: row[:last4], expires_on: expires_on,
              issued_on: expires_on - 1095, permission_for_activity: false } ]
  seed_staff(org_b, attrs, cards)
end

# =====================================================================
# シード実行の最後に、両サービスを同期で呼ぶ（ジョブの perform_now は使わない）
# =====================================================================
result = DailyCheckRunner.call
puts "シード完了：新規通知 #{result.notifications_created}件／期限切れに更新した書類 #{result.documents_expired}件"
raise "シード後の期限チェックに失敗しました: #{result.errors.join(', ')}" unless result.ok?
