# 期限ダッシュボード（数え方は DashboardMetrics）
class DashboardController < ApplicationController
  def show
    @metrics = DashboardMetrics.new(current_organization)
  end
end
