module Settings
  # 書類種別の管理（admin のみ）。missing 以外の書類が紐づく種別の削除は422＋メッセージ。
  class DocumentTypesController < ApplicationController
    before_action :set_document_type, only: %i[edit update destroy]

    def index
      authorize! DocumentType, :index
      load_document_types
    end

    def new
      authorize! DocumentType, :create
      @document_type = current_organization.document_types.build(required: true)
    end

    def create
      authorize! DocumentType, :create
      @document_type = current_organization.document_types.build(document_type_params)
      if @document_type.save
        redirect_to settings_document_types_path, notice: "書類種別を追加しました"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize! @document_type, :update
    end

    def update
      authorize! @document_type, :update
      if @document_type.update(document_type_params)
        redirect_to settings_document_types_path, notice: "書類種別を更新しました"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize! @document_type, :destroy
      if @document_type.destroy
        redirect_to settings_document_types_path, notice: "書類種別を削除しました", status: :see_other
      else
        load_document_types
        flash.now[:alert] = @document_type.errors.full_messages.to_sentence
        render :index, status: :unprocessable_entity
      end
    end

    private

    def set_document_type
      @document_type = current_organization.document_types.find(params[:id])
    end

    def load_document_types
      @document_types = current_organization.document_types.order(:name)
    end

    def document_type_params
      params.require(:document_type).permit(:name, :required, :renew_interval_months)
    end
  end
end
