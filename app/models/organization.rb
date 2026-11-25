class Organization < ApplicationRecord
  include Auditable

  has_many :users, dependent: :destroy
  has_many :staff_members, dependent: :destroy
  has_many :document_types, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :audit_logs, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
end
