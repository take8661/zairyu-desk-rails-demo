class ResidenceCard < ApplicationRecord
  include Auditable
  include OrganizationScoped

  RESIDENCE_STATUSES = %w[
    技術・人文知識・国際業務 特定技能1号 特定技能2号 技能実習 留学
    家族滞在 永住者 特定活動 定住者 日本人の配偶者等
  ].freeze

  belongs_to :organization
  belongs_to :staff_member
  has_many :notifications, dependent: :destroy

  organization_scoped_by :staff_member

  # 在留カード番号は下4桁（英数字）だけ保存する（個人情報を持たない設計判断）
  normalizes :card_number_last4, with: ->(value) { value.to_s.strip.upcase }

  validates :status_of_residence, inclusion: { in: RESIDENCE_STATUSES }
  validates :card_number_last4, format: { with: /\A[A-Z0-9]{4}\z/, message: "は英数字4文字で入力してください" }
  validates :expires_on, presence: true
  validate :expires_on_not_before_issued_on

  private

  def expires_on_not_before_issued_on
    return if issued_on.blank? || expires_on.blank?

    errors.add(:expires_on, "は交付日以降の日付にしてください") if expires_on < issued_on
  end
end
