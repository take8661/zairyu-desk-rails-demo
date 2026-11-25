# ジョブの「今すぐ実行」：admin のみ
class JobPolicy < ApplicationPolicy
  def run? = admin?
end
