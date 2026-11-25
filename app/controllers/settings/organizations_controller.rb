module Settings
  # 組織設定（admin のみ）。組織名の変更ができる。ジョブの「今すぐ実行」ボタンもここに置く。
  class OrganizationsController < ApplicationController
    def show
      authorize! current_organization, :show
      @organization = current_organization
    end

    def edit
      authorize! current_organization, :update
      @organization = current_organization
    end

    def update
      authorize! current_organization, :update
      @organization = current_organization
      if @organization.update(params.require(:organization).permit(:name))
        redirect_to settings_organization_path, notice: "組織名を更新しました"
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end
end
