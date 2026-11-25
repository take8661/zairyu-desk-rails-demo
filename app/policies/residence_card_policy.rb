# 在留カード：履歴の追加のみ（編集・削除は無い）
class ResidenceCardPolicy < ApplicationPolicy
  def create? = signed_in?
end
