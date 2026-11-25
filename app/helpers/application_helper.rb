module ApplicationHelper
  # 区分バッジ。色だけに頼らず、文字ラベルを必ず併記する
  def expiry_badge(band)
    return "".html_safe if band == :none

    tag.span(ExpiryBand.label(band), class: "badge badge-#{band}")
  end

  # 残日数の表示（期限切れは「N日超過」）
  def days_left_text(days_left)
    return "—" if days_left.nil?

    days_left.negative? ? "#{days_left.abs}日超過" : "あと#{days_left}日"
  end

  def date_text(date)
    date ? date.strftime("%Y-%m-%d") : "—"
  end

  def residence_status_options
    ResidenceCard::RESIDENCE_STATUSES
  end

  def language_options
    StaffMember::LANGUAGE_NAMES.map { |code, name| [ name, code ] }
  end

  def state_badge(state)
    tag.span(StaffDocument::STATE_LABELS[state], class: "badge badge-doc-#{state}")
  end
end
