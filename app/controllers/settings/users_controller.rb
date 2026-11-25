module Settings
  # ユーザー管理（admin のみ）。自分自身の削除・自分の role の変更は不可。
  class UsersController < ApplicationController
    before_action :set_user, only: %i[edit update destroy]

    def index
      authorize! User, :index
      @users = current_organization.users.order(:email_address)
    end

    def new
      authorize! User, :create
      @user = current_organization.users.build(role: "member")
    end

    def create
      authorize! User, :create
      @user = current_organization.users.build(user_params)
      if @user.save
        redirect_to settings_users_path, notice: "ユーザーを追加しました"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize! @user, :update
    end

    def update
      authorize! @user, :update
      attributes = user_params
      attributes = attributes.except(:password) if attributes[:password].blank?
      if @user == current_user && attributes[:role].present? && attributes[:role] != @user.role
        @user.assign_attributes(attributes)
        @user.errors.add(:role, "は自分自身では変更できません")
        @user.role = @user.role_was
        render :edit, status: :unprocessable_entity
      elsif @user.update(attributes)
        redirect_to settings_users_path, notice: "ユーザーを更新しました"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize! @user, :destroy
      @user.destroy!
      redirect_to settings_users_path, notice: "ユーザーを削除しました", status: :see_other
    end

    private

    def set_user
      @user = current_organization.users.find(params[:id])
    end

    # organization_id は permit しない
    def user_params
      params.require(:user).permit(:email_address, :role, :password)
    end
  end
end
