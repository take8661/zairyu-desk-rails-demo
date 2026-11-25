require "rails_helper"
require "csv"

RSpec.describe "出力（PDF・CSV）" do
  let(:organization) { create(:organization, name: "出力テスト製作所") }
  let!(:admin) { create(:user, :admin, organization: organization) }
  let!(:member) { create(:user, organization: organization) }
  let!(:staff) { create(:staff_member, organization: organization, employee_code: "X-1", full_name: "出力 太郎", expires_on: Date.current + 12) }

  describe "出力ページ" do
    it "admin には CSV のリンクが出る" do
      sign_in_as(admin)
      get reports_path
      expect(response.body).to include("在留期限一覧", "提出用CSV", "行政の正式様式ではありません")
      expect(response.body).to include("sjis", "utf8", "wareki")
    end

    it "member には CSV のリンクは出ず、PDFのリンクだけが出る" do
      sign_in_as(member)
      get reports_path
      expect(response.body).to include("在留期限一覧")
      expect(response.body).not_to include("提出用CSV")
    end
  end

  describe "在留期限一覧PDF" do
    it "admin・member とも、inline の application/pdf を expiry_list_YYYYMMDD.pdf で返す" do
      [ admin, member ].each do |user|
        delete session_path
        sign_in_as(user)
        get expiry_list_report_path(format: :pdf)
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("application/pdf")
        expect(response.headers["Content-Disposition"]).to include("inline")
        expect(response.headers["Content-Disposition"]).to include("expiry_list_#{Date.current.strftime('%Y%m%d')}.pdf")
        expect(response.body.byteslice(0, 5)).to eq("%PDF-")
      end
    end

    it "本文に自組織のスタッフが日本語で出る" do
      sign_in_as(admin)
      get expiry_list_report_path(format: :pdf)
      text = PDF::Reader.new(StringIO.new(response.body)).pages.map(&:text).join("\n")
      expect(text).to include("出力 太郎", "X-1", "出力テスト製作所")
    end

    it "拡張子なしの /reports/expiry_list でも pdf が返る（既定の format）" do
      sign_in_as(admin)
      get "/reports/expiry_list"
      expect(response.media_type).to eq("application/pdf")
    end
  end

  describe "提出用CSV" do
    before { sign_in_as(admin) }

    it "既定は Shift_JIS・西暦で、attachment の staff_YYYYMMDD.csv" do
      get staff_report_path(format: :csv)
      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to match(%r{text/csv.*shift_jis}i)
      expect(response.headers["Content-Disposition"]).to include("attachment", "staff_#{Date.current.strftime('%Y%m%d')}.csv")
      body = response.body.dup.force_encoding("Windows-31J")
      expect(body).to be_valid_encoding
      rows = CSV.parse(body.encode("UTF-8"))
      expect(rows.first).to eq(StaffCsvExport::HEADERS)
      expect(rows[1][0..1]).to eq([ "X-1", "出力 太郎" ])
      expect(rows[1][6]).to match(%r{\A\d{4}/\d{2}/\d{2}\z})
    end

    it "encoding=utf8 は BOM 付き UTF-8" do
      get staff_report_path(format: :csv, encoding: "utf8")
      expect(response.headers["Content-Type"]).to match(/utf-8/i)
      expect(response.body.bytes.first(3)).to eq([ 0xEF, 0xBB, 0xBF ])
    end

    it "era=wareki は和暦で出る" do
      get staff_report_path(format: :csv, encoding: "utf8", era: "wareki")
      body = response.body.dup.force_encoding("UTF-8").delete_prefix("﻿")
      expect(CSV.parse(body)[1][6]).to match(/\A令和\d+年\d+月\d+日\z/)
    end

    it "改行は CRLF" do
      get staff_report_path(format: :csv, encoding: "utf8")
      expect(response.body.scan(/(?<!\r)\n/)).to be_empty
    end

    it "member は403" do
      delete session_path
      sign_in_as(member)
      get staff_report_path(format: :csv)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
