# ダッシュボードの数え方（実装・テストの正）。
# 対象は status が active のスタッフだけ（退職者は全指標から除く）。
# 各スタッフの在留期限は current の residence_cards の expires_on。
class DashboardMetrics
  Row = Struct.new(:staff_member, :card, :days_left, :band, keyword_init: true)

  attr_reader :organization, :today

  def initialize(organization, today: Date.current)
    @organization = organization
    @today = today
  end

  # 期限90日以内（0 ≤ 残日数 ≤ 90。期限当日と90日目を含む）のスタッフ数
  def expiring_within_90_days_count
    rows.count { |row| row.days_left && row.days_left >= 0 && row.days_left <= 90 }
  end

  # 期限切れ（残日数 < 0）のスタッフ数
  def expired_count
    rows.count { |row| row.days_left&.negative? }
  end

  # 書類未提出：必須書類で state が missing の件数
  def missing_documents_count
    required_documents_count("missing")
  end

  # 書類期限切れ：必須書類で state が expired の件数
  def expired_documents_count
    required_documents_count("expired")
  end

  # 期限の近い順の一覧：期限切れと90日以内のスタッフを expires_on の昇順（同日は employee_code）
  def upcoming_rows
    rows.select { |row| row.days_left && row.days_left <= 90 }
        .sort_by { |row| [ row.card.expires_on, row.staff_member.employee_code ] }
  end

  def rows
    @rows ||= organization.staff_members.active.includes(:residence_cards).filter_map do |staff_member|
      card = staff_member.current_residence_card
      next if card.nil?

      days_left = ExpiryBand.days_left(card.expires_on, today: today)
      Row.new(staff_member: staff_member, card: card, days_left: days_left, band: ExpiryBand.for(days_left))
    end
  end

  private

  def required_documents_count(state)
    StaffDocument.joins(:document_type, :staff_member)
                 .where(organization_id: organization.id, state: state)
                 .where(document_types: { required: true }, staff_members: { status: "active" })
                 .count
  end
end
