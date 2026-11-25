# 権限の基底クラス。既定はすべて拒否（許可するものだけ各Policyで true にする）。
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = false
  def show? = false
  def create? = false
  def update? = false
  def destroy? = false

  def new? = create?
  def edit? = update?

  private

  def signed_in?
    user.present?
  end

  def admin?
    user&.admin? || false
  end
end
