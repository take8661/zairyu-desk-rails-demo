class StaffDocument < ApplicationRecord
  include Auditable
  include OrganizationScoped

  STATES = %w[missing submitted approved expired].freeze

  STATE_LABELS = {
    "missing" => "未提出", "submitted" => "提出済み（確認待ち）", "approved" => "承認済み", "expired" => "期限切れ"
  }.freeze

  # 人が行える遷移（これ以外は422）
  TRANSITIONS = {
    "missing" => %w[submitted],
    "submitted" => %w[approved missing],
    "approved" => %w[submitted],
    "expired" => %w[submitted]
  }.freeze

  # DocumentExpiryService だけが行う遷移（skip_transition_check を立てて更新する）
  SYSTEM_TRANSITIONS = {
    "approved" => %w[expired],
    "submitted" => %w[expired]
  }.freeze

  # システム（期限切れ処理・シード）が遷移規則を迂回するためのフラグ
  attr_accessor :skip_transition_check

  belongs_to :organization
  belongs_to :staff_member
  belongs_to :document_type

  organization_scoped_by :staff_member, :document_type

  validates :state, inclusion: { in: STATES }
  validates :submitted_on, presence: { message: "を入力してください（提出済みにする場合は必須です）" }, if: -> { state == "submitted" }
  validate :valid_transition, on: :update

  before_validation :apply_default_expires_on

  def state_label
    STATE_LABELS[state]
  end

  private

  def valid_transition
    return unless state_changed?
    return if skip_transition_check

    allowed = TRANSITIONS.fetch(state_was, [])
    return if allowed.include?(state)

    errors.add(:state, "は「#{STATE_LABELS[state_was]}」から「#{STATE_LABELS[state]}」へは変更できません")
  end

  # 有効期限が空で、書類種別に更新間隔があれば、提出日に月数を足した日を既定値にする（手入力が優先）。
  # 期限切れの書類を再提出する際、古い期限をそのまま残さない。
  def apply_default_expires_on
    if persisted? && state_changed?(to: "submitted") && !expires_on_changed? && expired_date?(expires_on)
      self.expires_on = nil
    end
    return if expires_on.present? || submitted_on.blank?

    months = document_type&.renew_interval_months
    self.expires_on = submitted_on >> months if months
  end

  def expired_date?(date)
    date.present? && date < Date.current
  end
end
