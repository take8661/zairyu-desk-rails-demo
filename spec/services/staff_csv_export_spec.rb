require "rails_helper"
require "csv"

RSpec.describe StaffCsvExport do
  let(:organization) { create(:organization) }

  def parse(data, encoding)
    text = encoding == "utf8" ? data.dup.force_encoding("UTF-8") : data.dup.force_encoding("Windows-31J").encode("UTF-8")
    text = text.delete_prefix("﻿")
    CSV.parse(text)
  end

  let!(:staff_b) do
    create(:staff_member, organization: organization, employee_code: "B-2", full_name: "鈴木次郎", full_name_kana: "スズキジロウ",
                          nationality: "ネパール", expires_on: Date.new(2027, 3, 31), status_of_residence: "留学")
  end
  let!(:staff_a) do
    create(:staff_member, organization: organization, employee_code: "A-1", full_name: "山田太郎", full_name_kana: "ヤマダタロウ",
                          birth_on: Date.new(1990, 5, 1), hired_on: Date.new(2019, 5, 1), expires_on: Date.new(2026, 12, 31))
  end

  it "列と順序は固定で、行は社員コードの昇順" do
    rows = parse(described_class.call(organization, encoding: "utf8"), "utf8")
    expect(rows.first).to eq(described_class::HEADERS)
    expect(rows.drop(1).map(&:first)).to eq(%w[A-1 B-2])
  end

  it "西暦（既定）：YYYY/MM/DD" do
    row = parse(described_class.call(organization, encoding: "utf8"), "utf8")[1]
    expect(row).to eq([ "A-1", "山田太郎", "ヤマダタロウ", "1990/05/01", "ベトナム", "特定技能1号", "2026/12/31", "無", "AB12", "2019/05/01", "在籍" ])
  end

  it "和暦：令和元年などの表記になる" do
    row = parse(described_class.call(organization, encoding: "utf8", era: "wareki"), "utf8")[1]
    expect(row[3]).to eq("平成2年5月1日")
    expect(row[9]).to eq("令和元年5月1日")
    expect(row[6]).to eq("令和8年12月31日")
  end

  it "UTF-8 は BOM 付き、Shift_JIS は BOM 無しで Windows-31J として読める" do
    utf8 = described_class.call(organization, encoding: "utf8")
    expect(utf8.bytes.first(3)).to eq([ 0xEF, 0xBB, 0xBF ])
    sjis = described_class.call(organization, encoding: "sjis")
    expect(sjis.bytes.first(3)).not_to eq([ 0xEF, 0xBB, 0xBF ])
    expect(sjis.dup.force_encoding("Windows-31J")).to be_valid_encoding
    expect(parse(sjis, "sjis")[1][1]).to eq("山田太郎")
  end

  it "改行は CRLF" do
    data = described_class.call(organization, encoding: "utf8")
    expect(data.scan(/(?<!\r)\n/)).to be_empty
    expect(data).to include("\r\n")
  end

  it "Shift_JIS で表現できない文字は ? に置き換わる" do
    staff_a.update!(full_name: "山田😀太郎")
    row = parse(described_class.call(organization, encoding: "sjis"), "sjis")[1]
    expect(row[1]).to eq("山田?太郎")
  end

  it "退職者も含み、状態列で区別する。資格外活動許可は有／無" do
    staff_b.residence_cards.first.update!(permission_for_activity: true)
    create(:staff_member, :left, organization: organization, employee_code: "C-3")
    rows = parse(described_class.call(organization, encoding: "utf8"), "utf8").drop(1)
    expect(rows.map { |row| row[10] }).to eq(%w[在籍 在籍 退職])
    expect(rows.find { |row| row[0] == "B-2" }[7]).to eq("有")
  end

  it "CSVインジェクション対策：先頭が = + - @ のセルは ' を付けて無害化する" do
    staff_a.update!(full_name: "=cmd|' /C calc'!A0", workplace: "+1", nationality: "@SUM(1)", full_name_kana: "-2+3")
    row = parse(described_class.call(organization, encoding: "utf8"), "utf8")[1]
    expect(row[1]).to start_with("'=")
    expect(row[2]).to eq("'-2+3")
    expect(row[4]).to eq("'@SUM(1)")
  end

  it "在留カード番号は下4桁だけで、全桁は出力に現れない" do
    data = described_class.call(organization, encoding: "utf8").force_encoding("UTF-8")
    expect(data).to include("AB12")
    expect(data).not_to match(/[A-Z]{2}\d{8}[A-Z]{2}/)
  end

  it "他組織のスタッフは含まれない" do
    other = create(:staff_member, full_name: "別組織の人", employee_code: "Z-9")
    data = described_class.call(organization, encoding: "utf8").force_encoding("UTF-8")
    expect(data).not_to include(other.full_name)
    expect(data).not_to include("Z-9")
  end

  it "不正な encoding / era 指定は既定値にフォールバックする" do
    expect { described_class.call(organization, encoding: "bogus", era: "bogus") }.not_to raise_error
  end
end
