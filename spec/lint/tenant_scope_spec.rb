require "rails_helper"

# テナント分離の検出テスト。
# コントローラが「素の」モデルクラスからレコードを取ると、他組織のデータに届いてしまう。
# 必ず Current.organization（current_organization）経由で取得する規則を、コードの文字列検査で守る。
RSpec.describe "テナントスコープの検出" do
  FORBIDDEN_PATTERN = /\b(StaffMember|ResidenceCard|StaffDocument|DocumentType|Notification|AuditLog|User)\.(find|find_by|find_by!|where|all|first|last|order|count|create|create!|new)\b/

  # 例外を足す場合は「ファイルパス（app/ からの相対）=> [許可する行の部分文字列, 理由]」で書く。
  # SessionsController の User.authenticate_by はこの一覧に含まれないため、現在は例外なし。
  ALLOWLIST = {}.freeze

  let(:controller_files) { Rails.root.glob("app/controllers/**/*.rb") }

  it "コントローラ配下のファイルが存在する（検査対象が空でない）" do
    expect(controller_files).not_to be_empty
  end

  it "コントローラが素のモデルクラスから find / where / new などを呼んでいない" do
    violations = controller_files.flat_map do |path|
      relative = path.relative_path_from(Rails.root).to_s
      allowed = ALLOWLIST.fetch(relative, [])
      path.each_line.with_index(1).filter_map do |line, number|
        next unless line.match?(FORBIDDEN_PATTERN)
        next if allowed.any? { |part, _reason| line.include?(part) }

        "#{relative}:#{number}: #{line.strip}"
      end
    end
    expect(violations).to be_empty, "テナント分離の規則違反：\n#{violations.join("\n")}"
  end

  it "検出パターン自体が、規則違反の例を正しく拾える（検査の検査）" do
    expect("@staff = StaffMember.find(params[:id])").to match(FORBIDDEN_PATTERN)
    expect("DocumentType.where(required: true)").to match(FORBIDDEN_PATTERN)
    expect("current_organization.staff_members.find(params[:id])").not_to match(FORBIDDEN_PATTERN)
    expect("User.authenticate_by(params)").not_to match(FORBIDDEN_PATTERN)
  end
end
