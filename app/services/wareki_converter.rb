# 西暦の日付を和暦（令和・平成・昭和）の文字列にする。
# 令和＝2019-05-01から、平成＝1989-01-08〜2019-04-30、昭和＝1926-12-25〜1989-01-07。
# 元年は「元年」と表記。範囲外（1926-12-24以前）は西暦の YYYY/MM/DD を返す。
class WarekiConverter
  ERAS = [
    { name: "令和", starts_on: Date.new(2019, 5, 1), base_year: 2018 },
    { name: "平成", starts_on: Date.new(1989, 1, 8), base_year: 1988 },
    { name: "昭和", starts_on: Date.new(1926, 12, 25), base_year: 1925 }
  ].freeze

  def self.format(date)
    return "" if date.nil?

    era = ERAS.find { |candidate| date >= candidate[:starts_on] }
    return date.strftime("%Y/%m/%d") if era.nil?

    year = date.year - era[:base_year]
    year_text = year == 1 ? "元" : year.to_s
    "#{era[:name]}#{year_text}年#{date.month}月#{date.day}日"
  end
end
