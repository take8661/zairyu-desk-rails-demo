require "rails_helper"

RSpec.describe ExpiryBand do
  describe ".for（残日数→区分の境界値）" do
    {
      -1 => :expired,
      0 => :d30,
      30 => :d30,
      31 => :d60,
      60 => :d60,
      61 => :d90,
      90 => :d90,
      91 => :none
    }.each do |days_left, expected|
      it "残日数#{days_left}は#{expected}" do
        expect(described_class.for(days_left)).to eq(expected)
      end
    end

    it "nil（期限なし）は none" do
      expect(described_class.for(nil)).to eq(:none)
    end
  end

  describe ".days_left" do
    it "期限日当日は0、前日は-1" do
      today = Date.new(2026, 11, 25)
      expect(described_class.days_left(today, today: today)).to eq(0)
      expect(described_class.days_left(today - 1, today: today)).to eq(-1)
      expect(described_class.days_left(today + 90, today: today)).to eq(90)
    end

    it "既定の今日は Date.current（Tokyo）を使う" do
      travel_to Time.zone.local(2026, 11, 25, 0, 30) do
        expect(described_class.days_left(Date.new(2026, 11, 26))).to eq(1)
      end
    end
  end

  describe ".label" do
    it "区分ごとの文字ラベルを返す（色だけに頼らない）" do
      expect(described_class.label(:expired)).to eq("期限切れ")
      expect(described_class.label(:d30)).to eq("30日以内")
      expect(described_class.label(:d60)).to eq("60日以内")
      expect(described_class.label(:d90)).to eq("90日以内")
    end
  end
end
