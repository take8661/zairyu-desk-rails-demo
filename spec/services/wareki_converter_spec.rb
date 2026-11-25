require "rails_helper"

RSpec.describe WarekiConverter do
  {
    Date.new(2019, 4, 30) => "平成31年4月30日",
    Date.new(2019, 5, 1) => "令和元年5月1日",
    Date.new(1989, 1, 7) => "昭和64年1月7日",
    Date.new(1989, 1, 8) => "平成元年1月8日",
    Date.new(2026, 11, 25) => "令和8年11月25日",
    Date.new(1926, 12, 24) => "1926/12/24"
  }.each do |date, expected|
    it "#{date} は「#{expected}」" do
      expect(described_class.format(date)).to eq(expected)
    end
  end

  it "昭和の最初の日（1926-12-25）は昭和元年" do
    expect(described_class.format(Date.new(1926, 12, 25))).to eq("昭和元年12月25日")
  end

  it "nil は空文字" do
    expect(described_class.format(nil)).to eq("")
  end
end
