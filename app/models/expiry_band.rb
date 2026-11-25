# 在留期限の残日数 → 区分。ダッシュボード・一覧・PDF・ジョブが同じ判定を使う。
module ExpiryBand
  BANDS = %i[expired d30 d60 d90 none].freeze

  LABELS = {
    expired: "期限切れ",
    d30: "30日以内",
    d60: "60日以内",
    d90: "90日以内",
    none: ""
  }.freeze

  # 通知の kind への対応
  NOTIFICATION_KINDS = {
    expired: "expired",
    d30: "expiry_30",
    d60: "expiry_60",
    d90: "expiry_90"
  }.freeze

  module_function

  def for(days_left)
    return :none if days_left.nil?

    if days_left.negative?
      :expired
    elsif days_left <= 30
      :d30
    elsif days_left <= 60
      :d60
    elsif days_left <= 90
      :d90
    else
      :none
    end
  end

  def label(band)
    LABELS.fetch(band)
  end

  # 残日数 = 期限日 - 今日（Tokyo）。当日は0、前日は-1
  def days_left(expires_on, today: Date.current)
    return nil if expires_on.nil?

    (expires_on - today).to_i
  end
end
