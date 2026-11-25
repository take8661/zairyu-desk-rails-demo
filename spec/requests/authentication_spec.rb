require "rails_helper"

RSpec.describe "認証" do
  let(:organization) { create(:organization) }
  let!(:user) { create(:user, organization: organization, email_address: "login@test.example") }

  describe "ログイン" do
    it "ログイン画面が表示され、デモであることが画面に出る" do
      get new_session_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ログイン", "架空のデータによるデモです")
    end

    it "正しい資格情報でログインするとダッシュボードへ移動する" do
      post session_path, params: login_params("login@test.example")
      expect(response).to redirect_to(root_url)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ダッシュボード")
    end

    it "メールアドレスは大文字・前後空白があっても同じユーザーとして扱う" do
      post session_path, params: login_params("  LOGIN@test.example ")
      expect(response).to redirect_to(root_url)
    end

    it "誤った入力では「メールアドレスまたはパスワードが違います」を表示する" do
      post session_path, params: login_params("login@test.example", "incorrect-input")
      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect(response.body).to include("メールアドレスまたはパスワードが違います")
    end

    it "存在しないメールアドレスでも同じメッセージ（ユーザーの存在を漏らさない）" do
      post session_path, params: login_params("nobody@test.example", "another-input")
      follow_redirect!
      expect(response.body).to include("メールアドレスまたはパスワードが違います")
    end

    it "ログイン前にアクセスしたURLへ、ログイン後に戻る" do
      get staff_members_path
      expect(response).to redirect_to(new_session_path)
      post session_path, params: login_params("login@test.example")
      expect(response).to redirect_to(staff_members_url)
    end
  end

  describe "ログアウト" do
    it "ログアウトするとセッションが破棄され、以降はログイン画面へ" do
      sign_in_as(user)
      expect { delete session_path }.to change(Session, :count).by(-1)
      expect(response).to redirect_to(new_session_path)
      get root_path
      expect(response).to redirect_to(new_session_path)
    end

    it "未ログインでのログアウトは302でログイン画面へ" do
      delete session_path
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "認証必須" do
    it "ログインしていないとダッシュボードはログイン画面へ302" do
      get root_path
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(new_session_path)
    end

    it "パスワード再設定の画面は存在しない" do
      get "/passwords/new"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "ヘルスチェック" do
    it "/up はログイン無しで200" do
      get "/up"
      expect(response).to have_http_status(:ok)
    end

    it "/up はログイン済みでも200" do
      sign_in_as(user)
      get "/up"
      expect(response).to have_http_status(:ok)
    end
  end
end
