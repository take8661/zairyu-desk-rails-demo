# 子テーブルの organization_id が親と一致していることをモデルで保証する。
# organization_id が空なら親（staff_member など）から補い、食い違えば検証エラーにする。
module OrganizationScoped
  extend ActiveSupport::Concern

  class_methods do
    # parents: organization_id を持つ親の関連名（例: %i[staff_member document_type]）
    def organization_scoped_by(*parents)
      @organization_parents = parents
      before_validation :fill_organization_from_parents
      validate :organization_matches_parents
    end

    def organization_parents
      @organization_parents || []
    end
  end

  private

  def fill_organization_from_parents
    return if organization_id.present?

    self.class.organization_parents.each do |name|
      parent = public_send(name)
      if parent&.organization_id
        self.organization_id = parent.organization_id
        return
      end
    end
  end

  def organization_matches_parents
    self.class.organization_parents.each do |name|
      parent = public_send(name)
      next if parent.nil?

      if parent.organization_id != organization_id
        errors.add(:organization_id, "が#{self.class.human_attribute_name(name)}の組織と一致しません")
      end
    end
  end
end
