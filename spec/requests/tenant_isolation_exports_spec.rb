require "rails_helper"
require "csv"

# テナント分離（出力系）：PDF／CSV で他組織のデータが出ないこと。
RSpec.describe "テナント分離（PDF・CSV）" do
  include_context "two organizations"

  let(:secrets) { [ "ORG_B_SECRET_NAME_1", "ORG_B_SECRET_NAME_2", "ORG_B_CODE_1", "ORG_B_CODE_2" ] }

  before { sign_in_as(admin_a) }

  it "#10 在留期限一覧PDFの本文（pdf-reader で抽出）に、Bの氏名・社員コードが含まれない（自組織分のみ出力）" do
    get expiry_list_report_path(format: :pdf)
    expect(response).to have_http_status(:ok)
    text = PDF::Reader.new(StringIO.new(response.body)).pages.map(&:text).join("\n")
    secrets.each { |secret| expect(text).not_to include(secret) }
    expect(text).to include("A-TEST-1")
    expect(text).to include("組織Aの太郎")
  end

  it "#10 提出用CSV（utf8）に、Bの氏名・社員コードが含まれない（自組織分のみ出力）" do
    get staff_report_path(format: :csv, encoding: "utf8")
    expect(response).to have_http_status(:ok)
    body = response.body.dup.force_encoding("UTF-8")
    secrets.each { |secret| expect(body).not_to include(secret) }
    expect(body).to include("A-TEST-1")
  end

  it "#10 提出用CSV（sjis・和暦）にも、Bのデータが含まれない" do
    get staff_report_path(format: :csv, encoding: "sjis", era: "wareki")
    expect(response).to have_http_status(:ok)
    body = response.body.dup.force_encoding("Windows-31J")
    expect(body).to be_valid_encoding
    secrets.each { |secret| expect(body).not_to include(secret) }
  end

  it "Bのadminが出力すると、Bのデータだけでありえない組織Aのデータは含まれない" do
    delete session_path
    sign_in_as(admin_b)
    get staff_report_path(format: :csv, encoding: "utf8")
    body = response.body.dup.force_encoding("UTF-8")
    expect(body).to include("ORG_B_CODE_1")
    expect(body).not_to include("A-TEST-1")
    get expiry_list_report_path(format: :pdf)
    text = PDF::Reader.new(StringIO.new(response.body)).pages.map(&:text).join("\n")
    expect(text).not_to include("組織Aの太郎")
  end

  it "出力に在留カード番号の全桁が出ない（下4桁のみ）" do
    get staff_report_path(format: :csv, encoding: "utf8")
    body = response.body.dup.force_encoding("UTF-8")
    expect(body).to include("AB12")
    expect(body).not_to match(/[A-Z]{2}\d{8}[A-Z]{2}/)
  end
end
