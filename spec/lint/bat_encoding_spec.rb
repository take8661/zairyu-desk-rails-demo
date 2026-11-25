require "rails_helper"

# 起動.bat・テスト実行.bat のバイト列検査。
# CRLF・Windows-31J として正しく読める・BOM無し・CP932外の文字を含まない・bundle は call 付き。
RSpec.describe "バッチファイルのエンコーディング" do
  let(:bat_files) { Rails.root.glob("*.bat") }

  it "起動バッチとテスト実行バッチの2つが Gemfile と同じ階層にある" do
    expect(bat_files.size).to eq(2)
    expect(Rails.root.join("Gemfile")).to exist
  end

  it "BOMが無い" do
    bat_files.each do |path|
      expect(path.binread[0, 3].bytes).not_to eq([ 0xEF, 0xBB, 0xBF ]), "#{path.basename}: UTF-8 BOM があります"
    end
  end

  it "改行はすべて CRLF（LF 単独の改行が無い）" do
    bat_files.each do |path|
      bytes = path.binread
      lone_lf = bytes.scan(/(?<!\r)\n/).size
      expect(lone_lf).to eq(0), "#{path.basename}: LF単独の改行が#{lone_lf}箇所あります"
      expect(bytes).to include("\r\n")
    end
  end

  it "Windows-31J として正しく読め、CP932外の文字を含まない" do
    bat_files.each do |path|
      bytes = path.binread
      expect(bytes.dup.force_encoding("Windows-31J")).to be_valid_encoding, "#{path.basename}: Windows-31J として不正なバイト列があります"
      if bytes.bytes.any? { |byte| byte > 0x7F }
        # 日本語を含むなら、UTF-8 で保存してしまっていないこと（UTF-8 として有効だと文字化けの原因になる）
        expect(bytes.dup.force_encoding("UTF-8")).not_to be_valid_encoding, "#{path.basename}: UTF-8 で保存されています"
      end
      # UTF-8 の文字を CP932 に変換できる＝CP932外の文字が無い、の裏返しとして往復で一致することを確認
      text = bytes.dup.force_encoding("Windows-31J")
      expect(text.encode("UTF-8").encode("Windows-31J").bytes).to eq(bytes.bytes)
    end
  end

  it "bundle の呼び出しには call が付いている（bundle は .bat のため、無いとバッチが途中で終わる）" do
    bat_files.each do |path|
      text = path.binread.force_encoding("Windows-31J").encode("UTF-8")
      text.each_line.with_index(1) do |line, number|
        stripped = line.strip
        next if stripped.match?(/\A(rem|echo)\b/i)
        next unless stripped.match?(/(^|\s)bundle(\s|$)/)

        expect(stripped).to match(/call\s+bundle/), "#{path.basename}:#{number}: call 無しの bundle: #{stripped}"
      end
    end
  end

  it "環境変数を設定する行は set \"X=1\" の引用符形式（値の末尾に空白が入らない）" do
    bat_files.each do |path|
      text = path.binread.force_encoding("Windows-31J").encode("UTF-8")
      text.each_line.with_index(1) do |line, number|
        stripped = line.strip
        next unless stripped.match?(/\Aset\s/i)

        expect(stripped).to match(/\Aset\s+"[A-Z_]+=.*"\z/), "#{path.basename}:#{number}: 引用符の無い set: #{stripped}"
      end
    end
  end

  it "日本語パスでも動くよう cd /d \"%~dp0\" で始めている" do
    bat_files.each do |path|
      expect(path.binread).to include('cd /d "%~dp0"')
    end
  end
end
