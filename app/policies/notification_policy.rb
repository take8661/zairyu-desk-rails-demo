# 通知一覧：admin・member とも閲覧できる
class NotificationPolicy < ApplicationPolicy
  def index? = signed_in?
end
