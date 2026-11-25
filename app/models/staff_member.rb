class StaffMember < ApplicationRecord
  include Auditable

  LANGUAGES = %w[ja en vi zh ne id tl my].freeze
  STATUSES = %w[active left].freeze

  LANGUAGE_NAMES = {
    "ja" => "日本語", "en" => "英語", "vi" => "ベトナム語", "zh" => "中国語",
    "ne" => "ネパール語", "id" => "インドネシア語", "tl" => "タガログ語", "my" => "ミャンマー語"
  }.freeze

  # スタッフの current の在留カード（expires_on が最大。同日は id が大きい方）を取る相関サブクエリ
  def self.current_card_sql(column)
    "(SELECT rc.#{column} FROM residence_cards rc WHERE rc.staff_member_id = staff_members.id " \
      "ORDER BY rc.expires_on DESC, rc.id DESC LIMIT 1)"
  end

  belongs_to :organization
  has_many :residence_cards, dependent: :destroy
  has_many :staff_documents, dependent: :destroy
  has_many :notifications, dependent: :destroy

  # 作成時のみ在留カードを同時入力できる（更新では permit しない）
  accepts_nested_attributes_for :residence_cards

  validates :employee_code, presence: true, uniqueness: { scope: :organization_id }
  validates :full_name, :birth_on, :nationality, :hired_on, presence: true
  validates :preferred_language, inclusion: { in: LANGUAGES }
  validates :status, inclusion: { in: STATUSES }
  validates :hourly_wage_yen, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :weekly_hours, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 168 }, allow_nil: true
  validate :residence_card_required_on_create, on: :create

  after_create :create_missing_staff_documents

  scope :active, -> { where(status: "active") }

  # 一覧用：current の在留期限・在留資格を列として足す（相関サブクエリ）
  scope :with_current_card, lambda {
    select(
      "staff_members.*",
      "#{current_card_sql(:expires_on)} AS current_expires_on",
      "#{current_card_sql(:status_of_residence)} AS current_status_of_residence"
    )
  }

  scope :with_current_status_of_residence, lambda { |value|
    where("#{current_card_sql(:status_of_residence)} = ?", value)
  }

  scope :order_by_current_expiry, lambda {
    order(Arel.sql("#{current_card_sql(:expires_on)} ASC"), :employee_code)
  }

  # 社員コード・氏名・カナの部分一致
  scope :search, lambda { |query|
    if query.blank?
      all
    else
      pattern = "%#{sanitize_sql_like(query.to_s.strip)}%"
      where("employee_code LIKE :p OR full_name LIKE :p OR full_name_kana LIKE :p", p: pattern)
    end
  }

  def current_residence_card
    if residence_cards.loaded?
      residence_cards.reject(&:marked_for_destruction?).max_by { |card| [ card.expires_on || Date.new(0), card.id || 0 ] }
    else
      residence_cards.order(expires_on: :desc, id: :desc).first
    end
  end

  def days_left(today: Date.current)
    ExpiryBand.days_left(current_residence_card&.expires_on, today: today)
  end

  def expiry_band(today: Date.current)
    ExpiryBand.for(days_left(today: today))
  end

  def active?
    status == "active"
  end

  # 必須書類で missing の件数
  def missing_required_documents_count
    staff_documents.select { |doc| doc.state == "missing" && doc.document_type.required }.size
  end

  def language_name
    LANGUAGE_NAMES[preferred_language]
  end

  private

  def residence_card_required_on_create
    errors.add(:base, "在留カードを1枚以上入力してください") if residence_cards.reject(&:marked_for_destruction?).empty?
  end

  # スタッフ作成時に、その組織の全書類種別について missing の行を作る
  def create_missing_staff_documents
    organization.document_types.find_each do |document_type|
      staff_documents.create!(document_type: document_type, organization_id: organization_id, state: "missing")
    end
  end
end
