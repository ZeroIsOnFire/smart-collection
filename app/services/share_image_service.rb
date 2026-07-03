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
    [
      line(@record.name, 54, COLORS[:teal], MARGIN, TEXT_TOP - 20),
      line(I18n.t('share_images.badges.collection'), 28, COLORS[:gold], MARGIN, TEXT_TOP + 48),
      *car_detail_lines,
      footer_line
    ].reject { |line| line[:text].blank? }
  end

  def wishlist_item_lines
    [
      line(@record.name, 58, COLORS[:teal], MARGIN, TEXT_TOP),
      line([@record.brand, @record.scale].compact_blank.join(' | '), 34, COLORS[:muted], MARGIN, TEXT_TOP + 78),
      line(@record.observations, 30, COLORS[:gold], MARGIN, TEXT_TOP + 142),
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

  def car_detail_lines
    car_detail_attributes.each_with_index.map do |(label, value), index|
      line("#{label}: #{value}", 28, COLORS[:muted], MARGIN, TEXT_TOP + 92 + (index * 34))
    end
  end

  def car_detail_attributes
    [
      [I18n.t('activerecord.attributes.car.brand'), @record.brand],
      [I18n.t('activerecord.attributes.car.size'), @record.size],
      [I18n.t('activerecord.attributes.car.year'), @record.year],
      [I18n.t('activerecord.attributes.car.color'), @record.color],
      [I18n.t('activerecord.attributes.car.tags'), @record.tags.to_a.join(', ')],
      [I18n.t('activerecord.attributes.car.observations'), @record.observations]
    ].filter_map do |label, value|
      text = value.to_s.squish
      [label, text] if text.present?
    end
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
