# frozen_string_literal: true

require 'mini_magick'

class ShareImageService
  WIDTH = 1080
  HEIGHT = 1350
  MARGIN = 72
  PHOTO_BOX_WIDTH = 936
  PHOTO_BOX_HEIGHT = 760
  PHOTO_BOX_TOP = 76
  TEXT_TOP = 910
  COLORS = {
    background: '#0F1417',
    panel: '#171F23',
    teal: '#9FCBC4',
    muted: '#B8C0C2',
    gold: '#D6A85D',
    line: '#2A363B',
    soft: '#151B1F'
  }.freeze
  FONT_PATHS = [
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
    '/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf',
    '/usr/share/fonts/truetype/freefont/FreeSans.ttf',
    '/System/Library/Fonts/Supplemental/Arial.ttf',
    'C:/Windows/Fonts/arial.ttf'
  ].freeze

  def self.font_path
    @font_path ||= FONT_PATHS.find { |path| File.exist?(path) }
  end

  def initialize(record:, kind:, title: nil)
    @record = record
    @kind = kind
    @title = title
  end

  def generate
    Tempfile.create(['share_image', '.png'], Rails.root.join('tmp')) do |file|
      file.binmode
      build_image(file.path)
      file.rewind
      file.read
    end
  end

  private

  def build_image(output_path)
    image = individual_image? ? image_with_photo_panel : create_blank_image
    decorate_image(image)
    image = compose_footer_logo(image)
    annotate_image(image)
    image.format('png')
    image.write(output_path)
  end

  def image_with_photo_panel
    image = create_blank_image
    draw_panel(image, MARGIN, PHOTO_BOX_TOP, PHOTO_BOX_WIDTH, PHOTO_BOX_HEIGHT)
    return image unless photo_path

    compose_photo(image)
  rescue MiniMagick::Error, MiniMagick::Invalid
    create_blank_image
  end

  def compose_photo(image)
    photo = MiniMagick::Image.open(photo_path)
    photo.resize "#{PHOTO_BOX_WIDTH - 48}x#{PHOTO_BOX_HEIGHT - 48}"

    left = MARGIN + ((PHOTO_BOX_WIDTH - photo.width) / 2)
    top = PHOTO_BOX_TOP + ((PHOTO_BOX_HEIGHT - photo.height) / 2)

    image.composite(photo) do |composite|
      composite.compose 'Over'
      composite.geometry "+#{left}+#{top}"
    end
  end

  def create_blank_image
    Tempfile.create(['share_blank', '.png'], Rails.root.join('tmp')) do |file|
      MiniMagick::Tool.new('convert') do |convert|
        convert.size "#{WIDTH}x#{HEIGHT}"
        convert.xc COLORS[:background]
        convert << file.path
      end
      MiniMagick::Image.open(file.path)
    end
  end

  def decorate_image(image)
    image.combine_options do |convert|
      convert.fill COLORS[:soft]
      convert.draw "roundrectangle #{MARGIN},#{HEIGHT - 150} #{WIDTH - MARGIN},#{HEIGHT - 76} 26,26"
      convert.fill COLORS[:gold]
      convert.draw "rectangle #{MARGIN},#{HEIGHT - 150} #{MARGIN + 8},#{HEIGHT - 76}"
      convert.fill '#E8F1EF'
      convert.draw "roundrectangle #{MARGIN + 20},#{HEIGHT - 138} #{MARGIN + 84},#{HEIGHT - 88} 18,18"
    end
  end

  def compose_footer_logo(image)
    return image unless File.exist?(footer_logo_path)

    logo = MiniMagick::Image.open(footer_logo_path)
    logo.resize '56x56'

    image.composite(logo) do |composite|
      composite.compose 'Over'
      composite.geometry "+#{MARGIN + 24}+#{HEIGHT - 141}"
    end
  rescue MiniMagick::Error, MiniMagick::Invalid
    image
  end

  def draw_panel(image, left, top, width, height)
    image.combine_options do |convert|
      convert.fill COLORS[:panel]
      convert.stroke COLORS[:line]
      convert.strokewidth 2
      convert.draw "roundrectangle #{left},#{top} #{left + width},#{top + height} 28,28"
    end
  end

  def annotate_image(image)
    lines.each do |line|
      annotate_line(image, line)
    end
  end

  def annotate_line(image, line)
    image.combine_options do |convert|
      convert.gravity 'NorthWest'
      convert.font self.class.font_path if self.class.font_path
      convert.fill line[:color]
      convert.pointsize line[:size]
      convert.annotate "+#{line[:left]}+#{line[:top]}", safe_text(line[:text])
    end
  end

  def lines
    case @kind
    when :car
      car_lines
    when :wishlist_item
      wishlist_item_lines
    else
      wishlist_lines
    end
  end

  def car_lines
    text_top = PHOTO_BOX_TOP + PHOTO_BOX_HEIGHT + 24
    [
      line(@record.name, 50, COLORS[:teal], MARGIN, text_top),
      *car_metadata_lines(text_top),
      *car_observation_lines(text_top),
      footer_line
    ].reject { |line| line[:text].blank? }
  end

  def wishlist_item_lines
    text_top = PHOTO_BOX_TOP + PHOTO_BOX_HEIGHT + 24
    [
      line(@record.name, 50, COLORS[:teal], MARGIN, text_top),
      *wishlist_item_metadata_lines(text_top),
      *wishlist_item_observation_lines(text_top),
      footer_line
    ].reject { |line| line[:text].blank? }
  end

  def wishlist_lines
    items = @record.to_a
    [
      line(@title.presence || I18n.t('wishlist_items.index.title'), 58, COLORS[:teal], MARGIN, 116),
      line(I18n.t('share_images.wishlist.total', count: items.count), 36, COLORS[:gold], MARGIN, 196),
      line(items.first(8).map(&:name).join(' | '), 32, COLORS[:muted], MARGIN, 304),
      footer_line
    ]
  end

  def footer_line
    line(I18n.t('share_images.footer_brand', year: Date.current.year), 28, COLORS[:muted], MARGIN + 104, HEIGHT - 128)
  end

  def car_metadata_lines(text_top)
    metadata = car_metadata_entries.map { |label, value| "#{label} #{value}" }.join('  |  ')
    [line(metadata, 22, COLORS[:muted], MARGIN, text_top + 66)]
  end

  def car_metadata_entries
    [
      [I18n.t('share_images.car_fields.brand'), @record.brand],
      [I18n.t('share_images.car_fields.scale'), @record.size],
      [I18n.t('share_images.car_fields.year'), @record.year],
      [I18n.t('share_images.car_fields.color'), @record.color],
      [I18n.t('share_images.car_fields.tags'), @record.tags.to_a.join(', ')]
    ].filter_map do |label, value|
      text = value.to_s.squish
      [label, text] if text.present?
    end
  end

  def car_observation_lines(text_top)
    return [] if @record.observations.blank?

    top = text_top + 112
    [
      line(I18n.t('share_images.car_fields.observations'), 24, COLORS[:gold], MARGIN, top),
      *wrapped_lines(@record.observations, max_chars: 74, max_lines: 5).map.with_index do |text, index|
        line(text, 24, COLORS[:muted], MARGIN, top + 34 + (index * 30))
      end
    ]
  end

  def wishlist_item_metadata_lines(text_top)
    metadata = wishlist_item_metadata_entries.map { |label, value| "#{label} #{value}" }.join('  |  ')
    [line(metadata, 22, COLORS[:muted], MARGIN, text_top + 66)]
  end

  def wishlist_item_metadata_entries
    [
      [I18n.t('share_images.car_fields.brand'), @record.brand],
      [I18n.t('share_images.car_fields.scale'), @record.scale]
    ].filter_map do |label, value|
      text = value.to_s.squish
      [label, text] if text.present?
    end
  end

  def wishlist_item_observation_lines(text_top)
    return [] if @record.observations.blank?

    top = text_top + 112
    [
      line(I18n.t('share_images.car_fields.observations'), 24, COLORS[:gold], MARGIN, top),
      *wrapped_lines(@record.observations, max_chars: 74, max_lines: 5).map.with_index do |text, index|
        line(text, 24, COLORS[:muted], MARGIN, top + 34 + (index * 30))
      end
    ]
  end

  def wrapped_lines(text, max_chars:, max_lines:)
    words = text.to_s.squish.split
    lines = []
    current = +''

    words.each do |word|
      candidate = current.blank? ? word : "#{current} #{word}"
      if candidate.length <= max_chars
        current = candidate
      else
        lines << current if current.present?
        current = word
      end
      break if lines.size == max_lines
    end

    lines << current if current.present? && lines.size < max_lines
    return lines if lines.size < max_lines || words.join(' ').length <= lines.join(' ').length

    lines[0...(max_lines - 1)] + ["#{lines[max_lines - 1].truncate(max_chars - 1, omission: '')}..."]
  end

  def line(text, size, color, left, top)
    { text: text.to_s, size: size, color: color, left: left, top: top }
  end

  def individual_image?
    %i[car wishlist_item].include?(@kind)
  end

  def photo_path
    return nil unless @record.respond_to?(:photo)
    return nil unless @record.photo? && @record.photo.path && File.exist?(@record.photo.path)

    @record.photo.path
  end

  def footer_logo_path
    Rails.public_path.join('logo/logo-no-bg.png')
  end

  def safe_text(value)
    value.to_s.squish.gsub(/[^\p{Alnum}\p{Space}:.,+\-_|()]/, '').truncate(90)
  end
end
