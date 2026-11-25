class AuditLog < ApplicationRecord
  ACTIONS = %w[create update destroy job.failed].freeze

  belongs_to :organization
  belongs_to :user, optional: true

  validates :action, inclusion: { in: ACTIONS }
  validates :target_type, presence: true
end
