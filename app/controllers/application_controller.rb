class ApplicationController < ActionController::Base
  include Authentication

  # 権限が無い（自組織内の画面なので存在は隠さず403にする。他組織のIDは404）
  class NotAuthorized < StandardError; end

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :tag_logs_with_organization

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from NotAuthorized, with: :render_forbidden

  private

  # Policy を引いて、許可されなければ NotAuthorized を投げる。
  # record_or_class にはレコード・クラス・シンボル（:report のような画面単位）を渡せる。
  def authorize!(record_or_class, action)
    policy_class_name =
      case record_or_class
      when Symbol then "#{record_or_class.to_s.camelize}Policy"
      when Class then "#{record_or_class.name}Policy"
      else "#{record_or_class.class.name}Policy"
      end
    policy = policy_class_name.constantize.new(Current.user, record_or_class)
    raise NotAuthorized, "#{policy_class_name}##{action}?" unless policy.public_send("#{action}?")
  end

  def current_organization
    Current.organization
  end
  helper_method :current_organization

  def current_user
    Current.user
  end
  helper_method :current_user

  # ログに request_id（log_tags）と組織IDを同じ行で出す
  def tag_logs_with_organization(&block)
    Rails.logger.tagged("org=#{Current.organization&.id}", &block)
  end

  def render_not_found
    render "errors/not_found", status: :not_found, formats: :html
  end

  def render_forbidden
    render "errors/forbidden", status: :forbidden, formats: :html
  end
end
