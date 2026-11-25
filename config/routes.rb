Rails.application.routes.draw do
  # 認証（標準認証。パスワード再設定は使わない）
  resource :session, only: %i[ new create destroy ]

  # ダッシュボード
  root "dashboard#show"

  # スタッフ（削除なし。退職は status を left に更新）
  resources :staff_members, except: :destroy do
    resources :residence_cards, only: %i[ new create ]
    resources :staff_documents, only: %i[ index update ]
  end

  # 通知
  resources :notifications, only: :index

  # 出力（/reports は一覧ページ。PDF・CSV は拡張子付きのパス）
  get "reports", to: "reports#index", as: :reports
  get "reports/expiry_list", to: "reports#expiry_list", defaults: { format: "pdf" }, as: :expiry_list_report
  get "reports/staff", to: "reports#staff", defaults: { format: "csv" }, as: :staff_report

  # 組織設定（admin のみ）
  namespace :settings do
    resource :organization, only: %i[ show edit update ]
    resources :users, except: :show
    resources :document_types, except: :show
    post "jobs/run", to: "jobs#run", as: :run_jobs
  end

  # ヘルスチェック（Rails 8 標準）
  get "up" => "rails/health#show", as: :rails_health_check
end
