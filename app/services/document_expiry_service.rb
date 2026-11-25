# 提出済み・承認済みで有効期限が今日より前の書類を expired にするサービス。
# active なスタッフのみ対象。audit_logs に update を残す（Current.user が無ければ user_id は NULL）。
# 戻り値は更新件数。
class DocumentExpiryService
  def self.call(organization_id = nil, today: Date.current)
    new(organization_id, today: today).call
  end

  def initialize(organization_id = nil, today: Date.current)
    @organization_id = organization_id
    @today = today
  end

  def call
    updated = 0
    organizations.find_each do |organization|
      organization.staff_members.active.find_each do |staff_member|
        targets = staff_member.staff_documents
                              .where(state: StaffDocument::SYSTEM_TRANSITIONS.keys)
                              .where("expires_on < ?", today)
        targets.find_each do |document|
          document.skip_transition_check = true
          document.update!(state: "expired")
          updated += 1
        end
      end
    end
    updated
  end

  private

  attr_reader :organization_id, :today

  def organizations
    organization_id ? Organization.where(id: organization_id) : Organization.all
  end
end
