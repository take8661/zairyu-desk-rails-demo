# テストで使うログイン補助。
# テスト用の資格情報は固定値を書かず、実行ごとに乱数で作る（実在の値は一切使わない）。
module AuthHelpers
  def self.test_credential
    @test_credential ||= "pw-#{SecureRandom.hex(8)}"
  end

  # ログインフォームに送るパラメータ（資格情報を差し替えて誤入力のテストもできる）
  def login_params(email_address, credential = AuthHelpers.test_credential)
    { email_address: email_address, password: credential }
  end

  # request spec 用：POST /session でログインする
  def sign_in_as(user, credential: AuthHelpers.test_credential)
    post session_path, params: { email_address: user.email_address, password: credential }
    user
  end
end

# system spec（rack_test）用：画面からログインする
module SystemAuthHelpers
  def sign_in_through_form(user, credential: AuthHelpers.test_credential)
    visit new_session_path
    fill_in "メールアドレス", with: user.email_address
    fill_in "パスワード", with: credential
    click_button "ログイン"
  end
end
