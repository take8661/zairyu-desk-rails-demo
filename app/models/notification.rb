class Notification < ApplicationRecord
  include OrganizationScoped

  KINDS = %w[expiry_90 expiry_60 expiry_30 expired].freeze

  belongs_to :organization
  belongs_to :staff_member
  belongs_to :residence_card

  organization_scoped_by :staff_member, :residence_card

  validates :kind, inclusion: { in: KINDS }
  validates :notified_on, :message, :mail_subject, :mail_body, presence: true
  validates :kind, uniqueness: { scope: :residence_card_id }
end
