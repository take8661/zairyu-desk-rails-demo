class DocumentType < ApplicationRecord
  include Auditable

  belongs_to :organization
  # 削除前の確認は dependent より先に走らせる
  before_destroy :ensure_no_progressed_documents, prepend: true
  has_many :staff_documents, dependent: :delete_all

  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :renew_interval_months, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true

  # 書類種別の新規作成時は、その組織の active なスタッフ全員に missing の行を作る
  after_create :create_missing_staff_documents

  private

  # missing 以外（提出済み・承認済み・期限切れ）の書類が紐づく種別は削除できない（missing の行だけなら一緒に消す）
  def ensure_no_progressed_documents
    return unless staff_documents.where.not(state: "missing").exists?

    errors.add(:base, "提出済み・承認済み・期限切れの書類が紐づいているため削除できません")
    throw :abort
  end

  def create_missing_staff_documents
    organization.staff_members.active.find_each do |staff_member|
      staff_documents.create!(staff_member: staff_member, organization_id: organization_id, state: "missing")
    end
  end
end
