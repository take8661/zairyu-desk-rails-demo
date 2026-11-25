# 在留カード履歴の追加（在留期間更新のたびに新しい行。編集・削除はしない）
class ResidenceCardsController < ApplicationController
  before_action :set_staff_member

  def new
    authorize! ResidenceCard, :create
    latest = @staff_member.current_residence_card
    @residence_card = @staff_member.residence_cards.build(
      status_of_residence: latest&.status_of_residence, card_number_last4: latest&.card_number_last4
    )
  end

  def create
    authorize! ResidenceCard, :create
    # organization_id は受け取らない（モデルが親のスタッフから補う）
    @residence_card = @staff_member.residence_cards.build(card_params)
    if @residence_card.save
      redirect_to @staff_member, notice: "在留カード（在留期間の更新）を追加しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_staff_member
    @staff_member = current_organization.staff_members.find(params[:staff_member_id])
  end

  def card_params
    params.require(:residence_card).permit(:status_of_residence, :card_number_last4, :issued_on, :expires_on, :permission_for_activity)
  end
end
