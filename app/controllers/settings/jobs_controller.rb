module Settings
  # ジョブの「今すぐ実行」（admin のみ）。サービスを同期で呼び、押した組織だけを対象に件数を表示する。
  # perform_later は使わない（結果を件数で返すため）。失敗時は job.failed とログに残り、画面にも失敗を出す。
  class JobsController < ApplicationController
    def run
      authorize! :job, :run
      result = DailyCheckRunner.call(current_organization.id)
      if result.ok?
        redirect_to settings_organization_path, status: :see_other,
          notice: "期限チェックを実行しました。新規通知 #{result.notifications_created}件／期限切れに更新した書類 #{result.documents_expired}件"
      else
        redirect_to settings_organization_path, status: :see_other, alert: "実行に失敗しました（詳細はログ）"
      end
    end
  end
end
