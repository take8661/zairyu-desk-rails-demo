require "rails_helper"

RSpec.describe "在留カード履歴の追加" do
  let(:organization) { create(:organization) }
  let!(:admin) { create(:user, :admin, organization: organization) }
  let!(:staff) { create(:staff_member, organization: organization, expires_on: Date.current + 10) }

  before { sign_in_as(admin) }

  it "追加フォームが表示され、現在の在留資格が初期値に入る" do
    get new_staff_member_residence_card_path(staff)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("在留期間の更新", "特定技能1号")
  end

  it "新しい行として追加され（過去の行は残る）、current が新しい期限に変わる" do
    expect do
      post staff_member_residence_cards_path(staff), params: {
        residence_card: { status_of_residence: "特定技能1号", card_number_last4: "NE77", issued_on: "2026-11-01", expires_on: (Date.current + 400).to_s }
      }
    end.to change { staff.residence_cards.count }.from(1).to(2)
    expect(response).to redirect_to(staff_member_path(staff))
    expect(staff.reload.current_residence_card.card_number_last4).to eq("NE77")
    expect(staff.days_left).to eq(400)
  end

  it "期限が交付日より前なら422で、行は増えない" do
    expect do
      post staff_member_residence_cards_path(staff), params: {
        residence_card: { status_of_residence: "留学", card_number_last4: "AB12", issued_on: "2026-12-01", expires_on: "2026-11-01" }
      }
    end.not_to change(ResidenceCard, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("入力内容を確認してください")
  end

  it "編集・削除のルートは無い（履歴は変更しない）" do
    card = staff.current_residence_card
    patch "/staff_members/#{staff.id}/residence_cards/#{card.id}", params: { residence_card: { expires_on: "2030-01-01" } }
    expect(response).to have_http_status(:not_found)
    delete "/staff_members/#{staff.id}/residence_cards/#{card.id}"
    expect(response).to have_http_status(:not_found)
    expect(card.reload.expires_on).to eq(Date.current + 10)
  end

  it "追加すると audit_logs に create が残る" do
    post staff_member_residence_cards_path(staff), params: {
      residence_card: { status_of_residence: "留学", card_number_last4: "LG01", expires_on: (Date.current + 50).to_s }
    }
    log = AuditLog.where(target_type: "ResidenceCard", action: "create").last
    expect(log.user_id).to eq(admin.id)
  end
end
