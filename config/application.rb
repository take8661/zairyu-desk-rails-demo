require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ZairyuDesk
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    config.autoload_lib(ignore: %w[assets tasks])

    # 日本語化・タイムゾーン
    config.time_zone = "Tokyo"
    config.i18n.default_locale = :ja
    config.i18n.available_locales = %i[ja en]
    config.i18n.fallbacks = [ :en ]

    # ログにリクエストIDを付ける（組織IDは ApplicationController が追加でタグ付けする）
    config.log_tags = [ :request_id ]

    # ジョブは開発・デモでは async アダプタ（Windowsでは Solid Queue の既定モードが使えないため）
    config.active_job.queue_adapter = :async

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
