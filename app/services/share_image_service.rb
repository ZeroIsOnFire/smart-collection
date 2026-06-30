# frozen_string_literal: true

require 'mini_magick'

class ShareImageService
  WIDTH = 1080
  HEIGHT = 1080
  PHOTO_HEIGHT = 620
  COLORS = {
    background: '#F6F1E8',
    teal: '#214F4A',
    muted: '#6B7280',
    gold: '#A56D32',
    white: '#FFFFFF'
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
    image = base_image
    annotate_image(image)
    image.format('png')
    image.write(output_path)
  end

  def base_image
    if photo_path
      image = MiniMagick::Image.open(photo_path)
      image.resize "#{WIDTH}x#{PHOTO_HEIGHT}^"
      image.gravity 'center'
      image.extent "#{WIDTH}x#{PHOTO_HEIGHT}"
      image.background COLORS[:background]
      image.gravity 'north'
      image.extent "#{WIDTH}x#{HEIGHT}"
      image
    else
      create_blank_image
    end
  rescue MiniMagick::Error, MiniMagick::Invalid
    create_blank_image
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

  def annotate_image(image)
    lines.each_with_index do |line, index|
      annotate_line(image, line.merge(top: line[:top] + (index * 72)))
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
      line(@record.name, 56, COLORS[:teal], 72, 690),
      line([@record.brand, @record.size, @record.year, @record.color].compact_blank.join(' | '), 34, COLORS[:muted], 72, 750),
      line(I18n.t('share_images.badges.collection'), 30, COLORS[:gold], 72, 810),
      line(I18n.t('share_images.brand'), 28, COLORS[:muted], 72, 900)
    ]
  end

  def wishlist_item_lines
    [
      line(@record.name, 56, COLORS[:teal], 72, 690),
      line([@record.brand, @record.scale].compact_blank.join(' | '), 34, COLORS[:muted], 72, 750),
      line([@record.priority_label, @record.status_label].compact_blank.join(' | '), 30, COLORS[:gold], 72, 810),
      line(I18n.t('share_images.badges.wishlist'), 28, COLORS[:muted], 72, 900)
    ]
  end

  def wishlist_lines
    items = @record.to_a
    [
      line(@title.presence || I18n.t('wishlist_items.index.title'), 54, COLORS[:teal], 72, 110),
      line(I18n.t('share_images.wishlist.total', count: items.count), 34, COLORS[:gold], 72, 178),
      line(items.first(6).map(&:name).join(' | '), 30, COLORS[:muted], 72, 270),
      line(I18n.t('share_images.brand'), 28, COLORS[:muted], 72, 900)
    ]
  end

  def line(text, size, color, left, top)
    { text: text.to_s, size: size, color: color, left: left, top: top }
  end

  def photo_path
    return nil unless @record.respond_to?(:photo)
    return nil unless @record.photo? && @record.photo.path && File.exist?(@record.photo.path)

    @record.photo.path
  end

  def safe_text(value)
    value.to_s.squish.gsub(/[^\p{Alnum}\p{Space}:.,+\-_|()]/, '').truncate(90)
  end
end
