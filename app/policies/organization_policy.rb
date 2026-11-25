# 組織設定：admin のみ
class OrganizationPolicy < ApplicationPolicy
  def show? = admin?
  def update? = admin?
end
