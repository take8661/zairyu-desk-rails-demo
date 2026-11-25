module Pdf
  # 在留期限一覧PDF。A4横。active なスタッフごとに
  # 社員コード・氏名・在留資格・在留期間満了日・残日数・区分ラベル（色分け。ラベル文字を併記）。
  # 並びは expires_on の昇順。call がバイナリ文字列を返す。
  class ExpiryList
    TITLE = "在留期限一覧".freeze
    CREATOR = "Zairyu Desk demo".freeze

    BAND_COLORS = {
      expired: "FDE8E6",
      d30: "FDD9D6",
      d60: "FFECD1",
      d90: "FFF6C2",
      none: "FFFFFF"
    }.freeze

    # A4横（841.89pt）から左右の余白36ptずつを引いた769.89pt に収まる合計にする
    COLUMN_WIDTHS = [ 85, 160, 185, 125, 100, 100 ].freeze

    def self.call(organization, today: Date.current)
      new(organization, today: today).call
    end

    def initialize(organization, today: Date.current)
      @organization = organization
      @today = today
    end

    def call
      pdf = Prawn::Document.new(
        page_size: "A4", page_layout: :landscape, margin: 36,
        info: { Title: TITLE, Creator: CREATOR }
      )
      PdfFont.apply(pdf)
      render_header(pdf)
      render_table(pdf)
      render_footer(pdf)
      pdf.render
    end

    private

    def render_header(pdf)
      pdf.text "#{TITLE}　#{@organization.name}", size: 16
      pdf.move_down 4
      pdf.text "出力日：#{@today.strftime('%Y-%m-%d')}　架空のデータによるデモです。行政の正式様式ではありません。", size: 9
      pdf.move_down 10
    end

    def render_table(pdf)
      rows = staff_rows
      data = [ %w[社員コード 氏名 在留資格 在留期間満了日 残日数 区分] ]
      band_by_row = []
      rows.each do |row|
        data << [
          row[:staff].employee_code, row[:staff].full_name, row[:card].status_of_residence,
          row[:card].expires_on.strftime("%Y-%m-%d"), days_left_text(row[:days_left]), ExpiryBand.label(row[:band]).presence || "—"
        ]
        band_by_row << row[:band]
      end

      pdf.table(data, header: true, column_widths: COLUMN_WIDTHS, cell_style: { size: 10, padding: [ 4, 6 ] }) do |table|
        table.row(0).background_color = "E3E8EF"
        band_by_row.each_with_index do |band, index|
          table.row(index + 1).background_color = BAND_COLORS.fetch(band)
        end
      end
      pdf.move_down 8
      pdf.text "対象：在籍中（active）のスタッフ #{rows.size}名。区分は色だけでなく文字ラベルでも示しています。", size: 9
    end

    def render_footer(pdf)
      pdf.number_pages "<page> / <total>", at: [ pdf.bounds.right - 80, 0 ], width: 80, align: :right, size: 9
    end

    def staff_rows
      @organization.staff_members.active.includes(:residence_cards).filter_map do |staff|
        card = staff.current_residence_card
        next if card.nil?

        days_left = ExpiryBand.days_left(card.expires_on, today: @today)
        { staff: staff, card: card, days_left: days_left, band: ExpiryBand.for(days_left) }
      end.sort_by { |row| [ row[:card].expires_on, row[:staff].employee_code ] }
    end

    def days_left_text(days_left)
      days_left.negative? ? "#{days_left.abs}日超過" : "あと#{days_left}日"
    end
  end
end
