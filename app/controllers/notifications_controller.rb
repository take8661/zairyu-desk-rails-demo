# 通知一覧。メールは実配信せず、「送信予定メール（デモ表示）」として件名・本文を出す。
class NotificationsController < ApplicationController
  def index
    authorize! Notification, :index
    @notifications = current_organization.notifications.includes(:staff_member).order(notified_on: :desc, id: :desc)
  end
end
