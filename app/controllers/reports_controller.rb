# 出力（在留期限一覧PDF・提出用CSV）。PDFは admin・member とも可、CSVは admin のみ。
# 他組織のデータは出力に含まれない（current_organization のスタッフだけを対象にする）。
class ReportsController < ApplicationController
  def index
    authorize! :report, :index
  end

  def expiry_list
    authorize! :report, :expiry_list_pdf
    data = Pdf::ExpiryList.call(current_organization)
    send_data data, filename: "expiry_list_#{Date.current.strftime('%Y%m%d')}.pdf",
                    type: "application/pdf", disposition: "inline"
  end

  def staff
    authorize! :report, :staff_csv
    encoding = params[:encoding] == "utf8" ? "utf8" : "sjis"
    era = params[:era] == "wareki" ? "wareki" : "seireki"
    data = StaffCsvExport.call(current_organization, encoding: encoding, era: era)
    charset = encoding == "utf8" ? "UTF-8" : "Shift_JIS"
    send_data data, filename: "staff_#{Date.current.strftime('%Y%m%d')}.csv",
                    type: "text/csv; charset=#{charset}", disposition: "attachment"
  end
end
