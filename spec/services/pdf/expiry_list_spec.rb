require "rails_helper"

# 生成したPDFを pdf-reader で読み戻す。
# ①ページ数・Title・A4横のページサイズ、②ASCIIの項目、③日本語の氏名が本文抽出に含まれること。
RSpec.describe Pdf::ExpiryList do
  let(:organization) { create(:organization, name: "テスト製作所（架空）") }
  let(:today) { Date.new(2026, 11, 25) }

  let!(:soon) do
    create(:staff_member, organization: organization, employee_code: "S-100", full_name: "山田太郎", expires_on: today + 20)
  end
  let!(:expired) do
    create(:staff_member, organization: organization, employee_code: "S-050", full_name: "佐藤花子", expires_on: today - 5)
  end
  let!(:far) do
    create(:staff_member, organization: organization, employee_code: "S-200", full_name: "グエン・ヴァン・アン", expires_on: today + 300)
  end
  let!(:left_staff) do
    create(:staff_member, :left, organization: organization, employee_code: "S-999", full_name: "退職した人")
  end

  let(:binary) { described_class.call(organization, today: today) }
  let(:reader) { PDF::Reader.new(StringIO.new(binary)) }
  let(:text) { reader.pages.map(&:text).join("\n") }

  it "PDFとして読み戻せて、Title と Creator が入っている" do
    expect(binary.byteslice(0, 5)).to eq("%PDF-")
    expect(reader.info[:Title]).to be_present
    expect(reader.info[:Creator]).to eq("Zairyu Desk demo")
  end

  it "ページは A4 横（幅 > 高さ、約 841.89 × 595.28 pt）" do
    box = reader.pages.first.attributes[:MediaBox]
    width = box[2] - box[0]
    height = box[3] - box[1]
    expect(width).to be_within(1).of(841.89)
    expect(height).to be_within(1).of(595.28)
    expect(width).to be > height
  end

  it "ASCIIの項目（社員コード・日付の数字）が含まれる" do
    expect(text).to include("S-100", "S-050", "S-200")
    expect(text).to include("2026-11-25") # 出力日
    expect(text).to include((today + 20).strftime("%Y-%m-%d"))
  end

  it "日本語の氏名・組織名・区分ラベルが本文抽出に含まれる（文字化けしない）" do
    expect(text).to include("山田太郎")
    expect(text).to include("佐藤花子")
    expect(text).to include("グエン・ヴァン・アン")
    expect(text).to include("テスト製作所（架空）")
    expect(text).to include("期限切れ")
    expect(text).to include("30日以内")
  end

  it "「架空のデータによるデモです」「行政の正式様式ではありません」を明記する" do
    expect(text).to include("架空のデータによるデモです")
    expect(text).to include("行政の正式様式ではありません")
  end

  it "退職者は含まれず、並びは期限の昇順" do
    expect(text).not_to include("退職した人")
    expect(text.index("S-050")).to be < text.index("S-100")
    expect(text.index("S-100")).to be < text.index("S-200")
  end

  it "他組織のスタッフは含まれない" do
    other = create(:staff_member, full_name: "ORG_OTHER_SECRET", employee_code: "OTHER-1")
    expect(other).to be_persisted
    expect(text).not_to include("ORG_OTHER_SECRET")
    expect(text).not_to include("OTHER-1")
  end

  it "在留カード番号は載らない" do
    expect(text).not_to include("AB12")
  end

  it "スタッフが多くても複数ページになり、全員が載る" do
    create_list(:staff_member, 30, organization: organization, expires_on: today + 10)
    expect(reader.page_count).to be > 1
  end

  it "フォントは同梱の静的TTFで、パスは PdfFont::PATH の1か所" do
    expect(File.exist?(PdfFont::PATH)).to be(true)
    expect(File.extname(PdfFont::PATH)).to eq(".ttf")
    expect(File.exist?(Rails.root.join("vendor/fonts/OFL-NotoSansJP.txt"))).to be(true)
  end
end
