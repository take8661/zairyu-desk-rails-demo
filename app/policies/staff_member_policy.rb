# スタッフ：admin・member とも閲覧・登録・編集ができる（削除は無い。退職は status を left に更新する）
class StaffMemberPolicy < ApplicationPolicy
  def index? = signed_in?
  def show? = signed_in?
  def create? = signed_in?
  def update? = signed_in?
end
