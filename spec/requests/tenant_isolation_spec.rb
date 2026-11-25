require "rails_helper"

# テナント分離専用テスト。
# 「Aのadminでログインして叩く」。期待値の「404」は HTTP 404 かつ本文にBのデータを含まないこと。
# #8・#9 は O1（お知らせ文作成）・O2（雇用条件確認書PDF）に着手した場合のみで、今回は未着手のため対象外。
# #10 のPDF／CSV系は tenant_isolation_exports_spec.rb。
RSpec.describe "テナント分離" do
  include_context "two organizations"

  let(:secrets) { [ "ORG_B_SECRET_NAME_1", "ORG_B_SECRET_NAME_2", "ORG_B_CODE_1", "ORG_B_CODE_2", "ORG_B_SECRET_DOC" ] }

  def expect_not_found_without_b_data
    expect(response).to have_http_status(:not_found)
    secrets.each { |secret| expect(response.body).not_to include(secret) }
  end

  describe "Aのadminでログインして、Bのデータを叩く" do
    before { sign_in_as(admin_a) }

    it "#1 スタッフの詳細・編集・更新は404（更新してもBの行は変わらない）" do
      get staff_member_path(staff_b1)
      expect_not_found_without_b_data
      get edit_staff_member_path(staff_b1)
      expect_not_found_without_b_data
      patch staff_member_path(staff_b1), params: { staff_member: { full_name: "乗っ取り", status: "left" } }
      expect_not_found_without_b_data
      expect(staff_b1.reload.full_name).to eq("ORG_B_SECRET_NAME_1")
      expect(staff_b1.status).to eq("active")
    end

    it "#2 在留カードの追加フォーム・追加は404（在留カードが増えない）" do
      get new_staff_member_residence_card_path(staff_b1)
      expect_not_found_without_b_data
      expect do
        post staff_member_residence_cards_path(staff_b1),
             params: { residence_card: { status_of_residence: "留学", card_number_last4: "HACK", expires_on: "2030-01-01" } }
      end.not_to change(ResidenceCard, :count)
      expect_not_found_without_b_data
    end

    it "#3 書類チェックリストの表示・更新は404（状態が変わらない）" do
      get staff_member_staff_documents_path(staff_b1)
      expect_not_found_without_b_data
      expect do
        patch staff_member_staff_document_path(staff_b1, doc_b), params: { staff_document: { state: "submitted", submitted_on: "2026-01-01" } }
      end.not_to(change { doc_b.reload.state })
      expect_not_found_without_b_data
    end

    it "#4 親子の組織が食い違う（Aのスタッフ × Bの書類）更新は404" do
      expect do
        patch staff_member_staff_document_path(staff_a, doc_b), params: { staff_document: { state: "submitted", submitted_on: "2026-01-01" } }
      end.not_to(change { doc_b.reload.state })
      expect_not_found_without_b_data
    end

    it "#5 Bのユーザーの編集・更新・削除は404（ユーザーが残っている）" do
      get edit_settings_user_path(member_b)
      expect_not_found_without_b_data
      patch settings_user_path(member_b), params: { user: { role: "admin", email_address: "hijack@test.example" } }
      expect_not_found_without_b_data
      expect { delete settings_user_path(member_b) }.not_to change(User, :count)
      expect_not_found_without_b_data
      expect(member_b.reload.role).to eq("member")
    end

    it "#6 Bの書類種別の編集・更新・削除は404（種別が残っている）" do
      get edit_settings_document_type_path(doc_type_b1)
      expect_not_found_without_b_data
      patch settings_document_type_path(doc_type_b1), params: { document_type: { name: "乗っ取り" } }
      expect_not_found_without_b_data
      expect { delete settings_document_type_path(doc_type_b1) }.not_to change(DocumentType, :count)
      expect_not_found_without_b_data
      expect(doc_type_b1.reload.name).to eq("ORG_B_SECRET_DOC_1")
    end

    it "#7 POST /staff_members に organization_id: B を混ぜても、Aの組織で作られる（Bに増えない）" do
      expect do
        post staff_members_path, params: { organization_id: org_b.id, staff_member: {
          organization_id: org_b.id, employee_code: "MIX-1", full_name: "混入テスト", birth_on: "1995-01-01",
          nationality: "ベトナム", hired_on: "2025-04-01",
          residence_cards_attributes: { "0" => { organization_id: org_b.id, status_of_residence: "留学", card_number_last4: "MX01", expires_on: "2027-01-01" } }
        } }
      end.to change { org_a.staff_members.count }.by(1).and(not_change { org_b.staff_members.count })
      created = StaffMember.find_by!(employee_code: "MIX-1")
      expect(created.organization_id).to eq(org_a.id)
      expect(created.residence_cards.sole.organization_id).to eq(org_a.id)
      expect(created.staff_documents.pluck(:organization_id).uniq).to eq([ org_a.id ])
    end

    it "#7（補足）ユーザー・書類種別・在留カードの作成でも organization_id は無視される" do
      post settings_users_path, params: { user: { organization_id: org_b.id, email_address: "new@org-a.example", role: "member", password: "password-1234" } }
      expect(User.find_by!(email_address: "new@org-a.example").organization_id).to eq(org_a.id)
      post settings_document_types_path, params: { document_type: { organization_id: org_b.id, name: "A専用の種別" } }
      expect(DocumentType.find_by!(name: "A専用の種別").organization_id).to eq(org_a.id)
      post staff_member_residence_cards_path(staff_a),
           params: { residence_card: { organization_id: org_b.id, status_of_residence: "留学", card_number_last4: "AA11", expires_on: "2030-01-01" } }
      expect(staff_a.residence_cards.find_by!(card_number_last4: "AA11").organization_id).to eq(org_a.id)
    end

    it "#10（画面系）スタッフ一覧・ダッシュボード・通知一覧に、Bの氏名・社員コードが含まれない" do
      [ staff_members_path, root_path, notifications_path ].each do |path|
        get path
        expect(response).to have_http_status(:ok)
        secrets.each { |secret| expect(response.body).not_to include(secret), "#{path} に #{secret} が含まれています" }
      end
    end

    it "#10（補足）スタッフ一覧の検索で、Bの社員コード・氏名はヒットしない" do
      get staff_members_path, params: { q: "ORG_B", status: "all" }
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("ORG_B_SECRET_NAME_1")
    end

    it "書類種別・ユーザー一覧にもBのデータは出ない" do
      get settings_document_types_path
      expect(response.body).not_to include("ORG_B_SECRET_DOC")
      get settings_users_path
      expect(response.body).not_to include("org-b.example")
    end
  end

  describe "#11 ログアウト状態では、上記の各URLは302（ログイン画面へ）" do
    it "全URLがログイン画面へリダイレクトされる" do
      paths = [
        [ :get, staff_member_path(staff_b1) ], [ :get, edit_staff_member_path(staff_b1) ],
        [ :patch, staff_member_path(staff_b1) ], [ :get, new_staff_member_residence_card_path(staff_b1) ],
        [ :post, staff_member_residence_cards_path(staff_b1) ], [ :get, staff_member_staff_documents_path(staff_b1) ],
        [ :patch, staff_member_staff_document_path(staff_b1, doc_b) ], [ :get, edit_settings_user_path(member_b) ],
        [ :patch, settings_user_path(member_b) ], [ :delete, settings_user_path(member_b) ],
        [ :get, edit_settings_document_type_path(doc_type_b1) ], [ :patch, settings_document_type_path(doc_type_b1) ],
        [ :delete, settings_document_type_path(doc_type_b1) ], [ :post, staff_members_path ],
        [ :get, staff_members_path ], [ :get, root_path ], [ :get, notifications_path ]
      ]
      paths.each do |verb, path|
        public_send(verb, path)
        expect(response).to have_http_status(:found), "#{verb.upcase} #{path}: #{response.status}"
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "#12 Aのmemberで管理系を叩く" do
    before { sign_in_as(member_a) }

    it "/settings/*・/reports/staff.csv・POST /settings/jobs/run は403（自組織の画面なので404ではない）" do
      [
        [ :get, settings_organization_path ], [ :get, settings_users_path ], [ :get, settings_document_types_path ],
        [ :get, staff_report_path(format: :csv) ], [ :post, settings_run_jobs_path ]
      ].each do |verb, path|
        public_send(verb, path)
        expect(response).to have_http_status(:forbidden), "#{verb.upcase} #{path}: #{response.status}"
      end
    end
  end

  describe "Bのadminが自組織を見ても、Aのデータは出ない（逆方向の確認）" do
    it "スタッフ一覧にAの氏名・社員コードが出ない" do
      sign_in_as(admin_b)
      get staff_members_path
      expect(response.body).to include("ORG_B_SECRET_NAME_1")
      expect(response.body).not_to include("組織Aの太郎")
      expect(response.body).not_to include("A-TEST-1")
      get staff_member_path(staff_a)
      expect(response).to have_http_status(:not_found)
    end
  end
end
