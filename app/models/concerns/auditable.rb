# create / update / destroy を audit_logs に残す。
# Current.user が無ければ user_id は NULL（ジョブ等のシステム操作）。
module Auditable
  extend ActiveSupport::Concern

  EXCLUDED_ATTRIBUTES = %w[password_digest updated_at].freeze

  included do
    after_create  { write_audit_log("create", saved_changes) }
    after_update  { write_audit_log("update", saved_changes) }
    after_destroy { write_audit_log("destroy", attributes) }
  end

  private

  def audit_organization_id
    is_a?(Organization) ? id : organization_id
  end

  def write_audit_log(action, changes)
    filtered = changes.to_h.except(*EXCLUDED_ATTRIBUTES)
    return if action == "update" && filtered.empty?

    AuditLog.create!(
      organization_id: audit_organization_id,
      user_id: Current.user&.id,
      action: action,
      target_type: self.class.name,
      target_id: id,
      changes_json: filtered
    )
  end
end
