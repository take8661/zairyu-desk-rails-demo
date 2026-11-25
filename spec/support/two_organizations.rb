# テナント分離テストの前提：
# 組織A（admin・member 各1）と組織B（admin1。スタッフ2名、書類種別2件、書類、在留カード、通知、ユーザー2名）。
# Bの氏名・社員コードは検出しやすい固定の文字列にする。
RSpec.shared_context "two organizations" do
  let!(:org_a) { create(:organization, name: "組織A（テスト）", slug: "org-a") }
  let!(:org_b) { create(:organization, name: "組織B（テスト）", slug: "org-b") }

  let!(:admin_a) { create(:user, :admin, organization: org_a, email_address: "admin@org-a.example") }
  let!(:member_a) { create(:user, organization: org_a, email_address: "member@org-a.example") }
  let!(:admin_b) { create(:user, :admin, organization: org_b, email_address: "admin@org-b.example") }
  let!(:member_b) { create(:user, organization: org_b, email_address: "member@org-b.example") }

  let!(:doc_type_a) { create(:document_type, organization: org_a, name: "パスポート写し（A）") }
  let!(:doc_type_b1) { create(:document_type, organization: org_b, name: "ORG_B_SECRET_DOC_1") }
  let!(:doc_type_b2) { create(:document_type, organization: org_b, name: "ORG_B_SECRET_DOC_2") }

  let!(:staff_a) { create(:staff_member, organization: org_a, employee_code: "A-TEST-1", full_name: "組織Aの太郎") }
  let!(:staff_b1) { create(:staff_member, organization: org_b, employee_code: "ORG_B_CODE_1", full_name: "ORG_B_SECRET_NAME_1") }
  let!(:staff_b2) { create(:staff_member, organization: org_b, employee_code: "ORG_B_CODE_2", full_name: "ORG_B_SECRET_NAME_2", expires_on: Date.current + 10) }

  let(:doc_b) { staff_b1.staff_documents.find_by!(document_type: doc_type_b1) }
  let(:doc_a) { staff_a.staff_documents.find_by!(document_type: doc_type_a) }
  let(:card_b) { staff_b1.current_residence_card }

  let!(:notification_b) do
    create(:notification, organization: org_b, staff_member: staff_b2, residence_card: staff_b2.current_residence_card,
                          message: "ORG_B_SECRET_NAME_2さんの在留期間があと10日です")
  end
end
