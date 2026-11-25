class User < ApplicationRecord
  include Auditable

  ROLES = %w[admin member].freeze

  has_secure_password
  belongs_to :organization
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }
  validates :password, length: { minimum: 8 }, allow_nil: true

  def admin?
    role == "admin"
  end

  def member?
    role == "member"
  end
end
