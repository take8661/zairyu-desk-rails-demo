class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  # ログイン試行の制限（標準認証の rate_limit。開発・テストのキャッシュは null_store のため実質無効）
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: "試行回数が多すぎます。しばらくしてからやり直してください" }

  def new
  end

  def create
    if (user = User.authenticate_by(params.permit(:email_address, :password)))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "メールアドレスまたはパスワードが違います"
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
