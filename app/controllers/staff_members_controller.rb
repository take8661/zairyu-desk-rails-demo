class StaffMembersController < ApplicationController
  STATUS_FILTERS = %w[active left all].freeze

  def index
    authorize! StaffMember, :index
    @status = STATUS_FILTERS.include?(params[:status]) ? params[:status] : "active"
    @status_of_residence = params[:status_of_residence].presence
    @query = params[:q].to_s.strip

    scope = current_organization.staff_members.with_current_card.search(@query)
    scope = scope.where(status: @status) unless @status == "all"
    scope = scope.with_current_status_of_residence(@status_of_residence) if @status_of_residence
    @staff_members = scope.order_by_current_expiry.includes(:residence_cards, staff_documents: :document_type)
  end

  def show
    @staff_member = find_staff_member
    authorize! @staff_member, :show
    @residence_cards = @staff_member.residence_cards.sort_by { |card| [ card.expires_on, card.id ] }.reverse
  end

  def new
    authorize! StaffMember, :create
    @staff_member = current_organization.staff_members.build(preferred_language: "ja", status: "active")
    @staff_member.residence_cards.build
  end

  def create
    authorize! StaffMember, :create
    # organization_id はフォームから受け取らず、必ず自組織で作る
    @staff_member = current_organization.staff_members.build(create_params)
    if @staff_member.save
      redirect_to @staff_member, notice: "スタッフを登録しました"
    else
      @staff_member.residence_cards.build if @staff_member.residence_cards.empty?
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @staff_member = find_staff_member
    authorize! @staff_member, :update
  end

  def update
    @staff_member = find_staff_member
    authorize! @staff_member, :update
    if @staff_member.update(update_params)
      redirect_to @staff_member, notice: "スタッフ情報を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def find_staff_member
    current_organization.staff_members.find(params[:id])
  end

  BASIC_ATTRIBUTES = %i[
    employee_code full_name full_name_kana birth_on nationality preferred_language
    hired_on left_on status job_title workplace hourly_wage_yen weekly_hours
  ].freeze
  CARD_ATTRIBUTES = %i[status_of_residence card_number_last4 issued_on expires_on permission_for_activity].freeze

  # 作成時のみ在留カードを同時入力できる。organization_id は permit しない。
  def create_params
    params.require(:staff_member).permit(*BASIC_ATTRIBUTES, residence_cards_attributes: CARD_ATTRIBUTES)
  end

  def update_params
    params.require(:staff_member).permit(*BASIC_ATTRIBUTES)
  end
end
