namespace :zairyu do
  desc "期限チェックを同期で実行する（通知の作成と書類の期限切れ更新）。失敗したら終了コード1"
  task daily: :environment do
    result = DailyCheckRunner.call
    puts "新規通知: #{result.notifications_created}件／期限切れに更新した書類: #{result.documents_expired}件"
    unless result.ok?
      warn "期限チェックに失敗しました（詳細はログと audit_logs の job.failed）: #{result.errors.join(', ')}"
      exit 1
    end
  end
end
