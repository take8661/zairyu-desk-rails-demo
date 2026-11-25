# 書類チェックリスト（状態遷移は StaffDocument モデルの規則に従い、不正な遷移は422）
class StaffDocumentsController < ApplicationController
  before_action :set_staff_member

  def index
    authorize! StaffDocument, :index
    load_documents
  end

  def update
    authorize! StaffDocument, :update
    # 親（スタッフ）経由で取得するので、他組織・他スタッフの書類は404になる
    @document = @staff_member.staff_documents.find(params[:id])
    if @document.update(document_params)
      redirect_to staff_member_staff_documents_path(@staff_member), notice: "「#{@document.document_type.name}」を更新しました"
    else
      load_documents
      # エラーを持つレコードを一覧側にも差し替える（再読込した別オブジェクトにはエラーが載らないため）
      @documents = @documents.map { |doc| doc.id == @document.id ? @document : doc }
      render :index, status: :unprocessable_entity
    end
  end

  private

  def set_staff_member
    @staff_member = current_organization.staff_members.find(params[:staff_member_id])
  end

  def load_documents
    @documents = @staff_member.staff_documents.includes(:document_type).sort_by { |doc| doc.document_type.name }
  end

  def document_params
    params.require(:staff_document).permit(:state, :submitted_on, :expires_on, :note)
  end
end
