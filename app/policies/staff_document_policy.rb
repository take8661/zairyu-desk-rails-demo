# 書類チェックリスト：admin・member とも閲覧と更新ができる
class StaffDocumentPolicy < ApplicationPolicy
  def index? = signed_in?
  def update? = signed_in?
end
