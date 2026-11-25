# 書類種別の管理：admin のみ
class DocumentTypePolicy < ApplicationPolicy
  def index? = admin?
  def create? = admin?
  def update? = admin?
  def destroy? = admin?
end
