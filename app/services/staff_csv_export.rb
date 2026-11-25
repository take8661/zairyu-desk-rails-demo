require "csv"

# 提出用CSV（admin のみ）。
# 公的な外国人雇用状況の届出で求められる項目の並びを参考にした独自のCSVで、行政の正式様式ではない。
# 対象は自組織の全スタッフ（退職者を含み、状態列で区別）。行は employee_code の昇順。
class StaffCsvExport
  HEADERS = [
    "社員コード", "氏名", "氏名（カナ）", "生年月日", "国籍・地域", "在留資格", "在留期間満了日",
    "資格外活動許可の有無", "在留カード番号（下4桁）", "雇用開始日", "状態"
  ].freeze

  # CSVインジェクション対策：先頭がこれらの文字のセルは、先頭に ' を付けて数式として解釈させない
  FORMULA_PREFIXES = [ "=", "+", "-", "@", "\t", "\r" ].freeze

  ENCODINGS = %w[sjis utf8].freeze
  ERAS = %w[seireki wareki].freeze

  def self.call(organization, encoding: "sjis", era: "seireki")
    new(organization, encoding: encoding, era: era).call
  end

  def initialize(organization, encoding: "sjis", era: "seireki")
    @organization = organization
    @encoding = ENCODINGS.include?(encoding.to_s) ? encoding.to_s : "sjis"
    @era = ERAS.include?(era.to_s) ? era.to_s : "seireki"
  end

  # 戻り値はバイナリ文字列（Shift_JIS の場合は Windows-31J、UTF-8 の場合は BOM 付き）
  def call
    text = CSV.generate(row_sep: "\r\n") do |csv|
      csv << HEADERS
      @organization.staff_members.includes(:residence_cards).order(:employee_code).each do |staff|
        csv << row_for(staff).map { |cell| sanitize(cell) }
      end
    end
    encode(text)
  end

  private

  def row_for(staff)
    card = staff.current_residence_card
    [
      staff.employee_code,
      staff.full_name,
      staff.full_name_kana,
      format_date(staff.birth_on),
      staff.nationality,
      card&.status_of_residence,
      format_date(card&.expires_on),
      card&.permission_for_activity ? "有" : "無",
      card&.card_number_last4,
      format_date(staff.hired_on),
      staff.status == "active" ? "在籍" : "退職"
    ]
  end

  def format_date(date)
    return "" if date.nil?

    @era == "wareki" ? WarekiConverter.format(date) : date.strftime("%Y/%m/%d")
  end

  def sanitize(cell)
    value = cell.to_s
    FORMULA_PREFIXES.any? { |prefix| value.start_with?(prefix) } ? "'#{value}" : value
  end

  def encode(text)
    if @encoding == "utf8"
      "﻿#{text}".b
    else
      # 表現できない文字は ? に置き換える
      text.encode("Windows-31J", invalid: :replace, undef: :replace, replace: "?")
    end
  end
end
