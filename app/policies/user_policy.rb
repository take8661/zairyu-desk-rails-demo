# ユーザー管理：admin のみ。自分自身の削除・自分の role の変更は不可（コントローラ側でも422にする）
class UserPolicy < ApplicationPolicy
  def index? = admin?
  def create? = admin?
  def update? = admin?

  def destroy?
    admin? && record != user
  end
end
