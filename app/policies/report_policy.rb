# 出力：PDFは admin・member とも可。提出用CSVは admin のみ。
class ReportPolicy < ApplicationPolicy
  def index? = signed_in?
  def expiry_list_pdf? = signed_in?
  def employment_terms_pdf? = signed_in?
  def staff_csv? = admin?
end
