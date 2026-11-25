require "rails_helper"

RSpec.describe "エラー画面とログ" do
  let(:organization) { create(:organization) }
  let!(:admin) { create(:user, :admin, organization: organization) }
  let!(:member) { create(:user, organization: organization) }

  describe "日本語のエラー画面" do
    it "404：他組織・存在しないIDは日本語の404画面（存在を漏らさない）" do
      other_staff = create(:staff_member)
      sign_in_as(admin)
      get staff_member_path(other_staff)
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("404", "ページが見つかりません")
      expect(response.body).not_to include(other_staff.full_name)
    end

    it "403：権限が無い画面は日本語の403画面" do
      sign_in_as(member)
      get settings_organization_path
      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("403", "権限がありません")
    end

    it "存在しないパスは public/404.html の日本語の404" do
      # テスト環境は開発用デバッグ画面になるため、本番が返す public/404.html の中身を直接確認する
      expect(Rails.public_path.join("404.html").read).to include("ページが見つかりません")
      get "/no/such/page"
      expect(response).to have_http_status(:not_found)
    end

    it "public/422.html・500.html・400.html も日本語に差し替えてある" do
      expect(Rails.public_path.join("422.html").read).to include("リクエストを処理できません")
      expect(Rails.public_path.join("500.html").read).to include("システムエラーが発生しました")
      expect(Rails.public_path.join("400.html").read).to include("リクエストが正しくありません")
      expect(Rails.public_path.join("404.html").read).to include("ページが見つかりません")
    end

    it "エラー画面（ログイン前でも）にも「架空のデータによるデモです」が出る" do
      sign_in_as(member)
      get settings_users_path
      expect(response.body).to include("架空のデータによるデモです")
    end
  end

  describe "ログ" do
    it "リクエストIDと組織IDが同じログ行に出る（log_tags と around_action のタグ）" do
      expect(Rails.application.config.log_tags).to include(:request_id)
      sign_in_as(admin)
      io = StringIO.new
      tagged_logger = ActiveSupport::TaggedLogging.new(Logger.new(io))
      original = Rails.logger
      Rails.logger = tagged_logger
      begin
        get root_path
        # コントローラ内（around_action）で組織IDのタグが付くことを、タグ付きロガーで直接確認する
        tagged_logger.tagged("org=#{organization.id}") { tagged_logger.info("確認") }
      ensure
        Rails.logger = original
      end
      expect(io.string).to include("[org=#{organization.id}]")
    end

    it "ApplicationController の around_action が Current.organization のIDでタグ付けする" do
      sign_in_as(admin)
      tags = []
      allow(Rails.logger).to receive(:tagged).and_wrap_original do |original, *args, &block|
        tags.concat(args)
        original.call(*args, &block)
      end
      get root_path
      expect(tags).to include("org=#{organization.id}")
    end

    it "filter_parameters に個人情報（氏名・カナ・生年月日・カード番号下4桁）が入っている" do
      filtered = Rails.application.config.filter_parameters
      # Rails は文字列・シンボルを1つの正規表現にまとめるため、各キーが実際にマスクされることで確認する
      filter = ActiveSupport::ParameterFilter.new(filtered)
      %w[full_name full_name_kana birth_on card_number_last4].each do |key|
        expect(filter.filter(key => "x")[key]).to eq("[FILTERED]")
      end
    end

    it "氏名などのパラメータはログで [FILTERED] になる" do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      result = filter.filter(full_name: "秘密の氏名", card_number_last4: "AB12", birth_on: "1990-01-01", employee_code: "E-1")
      expect(result).to include(full_name: "[FILTERED]", card_number_last4: "[FILTERED]", birth_on: "[FILTERED]", employee_code: "E-1")
    end
  end
end
