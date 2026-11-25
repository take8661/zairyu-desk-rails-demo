# 在留期限の通知を作るサービス。
# organization_id が nil なら全組織。Current は使わず、組織から staff_members を辿る。
# 同じ日に何度実行しても通知は増えない（(residence_card_id, kind) の一意制約で冪等）。
# 戻り値は新規作成した通知の件数。
class ExpiryAlertService
  def self.call(organization_id = nil, today: Date.current)
    new(organization_id, today: today).call
  end

  def initialize(organization_id = nil, today: Date.current)
    @organization_id = organization_id
    @today = today
  end

  def call
    created = 0
    organizations.find_each do |organization|
      organization.staff_members.active.includes(:residence_cards).find_each do |staff_member|
        created += 1 if notify(organization, staff_member)
      end
    end
    created
  end

  private

  attr_reader :organization_id, :today

  def organizations
    organization_id ? Organization.where(id: organization_id) : Organization.all
  end

  # その時点の最も厳しい区分の1件だけ作る（過去の緩い区分は遡って作らない）
  def notify(organization, staff_member)
    card = staff_member.current_residence_card
    return false if card.nil?

    days_left = ExpiryBand.days_left(card.expires_on, today: today)
    kind = ExpiryBand::NOTIFICATION_KINDS[ExpiryBand.for(days_left)]
    return false if kind.nil?
    return false if Notification.exists?(residence_card_id: card.id, kind: kind)

    Notification.create!(
      organization_id: organization.id,
      staff_member: staff_member,
      residence_card: card,
      kind: kind,
      notified_on: today,
      message: message_for(staff_member, days_left),
      mail_subject: "【在留期限のお知らせ（デモ）】#{message_for(staff_member, days_left)}",
      mail_body: mail_body_for(organization, staff_member, card, days_left)
    )
    true
  rescue ActiveRecord::RecordNotUnique
    # 同時実行などで既に作られていた場合は握りつぶして次へ（冪等）
    false
  end

  def message_for(staff_member, days_left)
    if days_left.negative?
      "#{staff_member.full_name}さんの在留期間が#{days_left.abs}日前に終了しています"
    else
      "#{staff_member.full_name}さんの在留期間があと#{days_left}日です"
    end
  end

  def mail_body_for(organization, staff_member, card, days_left)
    <<~BODY
      #{organization.name} ご担当者さま

      #{message_for(staff_member, days_left)}。
      在留資格：#{card.status_of_residence}
      在留期間満了日：#{card.expires_on.strftime('%Y-%m-%d')}

      期限までに在留期間更新の手続きが必要かご確認ください。
      ※このメールは送信されません（架空のデータによるデモ表示です）。
    BODY
  end
end
