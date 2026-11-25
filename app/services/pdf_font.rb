# PDFで使う日本語フォントのパスを決める1か所。
# Prawn は可変フォントと CFF アウトラインの OpenType（.otf）を扱えないため、
# Noto Sans JP の「静的インスタンスの .ttf」を vendor/fonts に同梱している（ライセンス全文も同じフォルダ）。
module PdfFont
  FAMILY = "NotoSansJP".freeze
  PATH = Rails.root.join("vendor", "fonts", "NotoSansJP-Regular.ttf").to_s.freeze

  # 文書にフォントを登録して選択する
  def self.apply(pdf)
    pdf.font_families.update(FAMILY => { normal: PATH, bold: PATH })
    pdf.font(FAMILY)
  end
end
