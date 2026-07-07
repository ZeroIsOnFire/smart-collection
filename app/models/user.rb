# frozen_string_literal: true

class User
  include Mongoid::Document
  include Mongoid::Timestamps

  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  ## Database authenticatable
  field :email,              type: String, default: ''
  field :encrypted_password, type: String, default: ''

  ## Recoverable
  field :reset_password_token,   type: String
  field :reset_password_sent_at, type: Time

  ## Rememberable
  field :remember_created_at, type: Time

  ## Profile
  field :name, type: String, default: ''
  field :share_token, type: String
  field :sharing_enabled, type: Boolean, default: false
  field :wishlist_share_token, type: String
  field :wishlist_sharing_enabled, type: Boolean, default: false
  field :wishlist_public_title, type: String
  field :wishlist_public_show_status, type: Boolean, default: true
  field :wishlist_public_show_priority, type: Boolean, default: true
  field :ai_upscaling_enabled, type: Boolean, default: true
  field :bulk_ai_upscaling_enabled, type: Boolean, default: false
  field :initial_setup_completed, type: Boolean, default: true
  field :locale, type: String, default: 'en'

  index({ sharing_enabled: 1 }, { background: true })
  index({ wishlist_sharing_enabled: 1 }, { background: true })
  index({ name: 'text', email: 'text' }, { name: 'UserTextIndex', background: true })

  index({ share_token: 1 }, { unique: true, sparse: true, background: true })
  index({ wishlist_share_token: 1 }, { unique: true, sparse: true, background: true })

  ## Admin flag
  field :admin, type: Boolean, default: false

  validates :name, presence: true
  validates :locale, inclusion: { in: ->(_user) { I18n.available_locales.map(&:to_s) } }

  before_save :ensure_share_token, if: :sharing_enabled?
  before_save :ensure_wishlist_share_token, if: :wishlist_sharing_enabled?
  after_create :track_creation

  def initial_setup_pending?
    !admin? && initial_setup_completed == false
  end

  private

  def ensure_share_token
    self.share_token ||= SecureRandom.uuid
  end

  def ensure_wishlist_share_token
    self.wishlist_share_token ||= SecureRandom.uuid
  end

  def track_creation
    UsageMetric.record!('users_created')
  end

  has_many :cars, class_name: 'Car', dependent: :destroy
  has_many :wishlist_items, dependent: :destroy
  has_many :autodetections, dependent: :destroy
  has_many :collection_exports, dependent: :destroy

  index({ email: 1 }, { unique: true, background: true })
  index({ reset_password_token: 1 }, { unique: true, sparse: true, background: true })
  index({ created_at: -1 }, { background: true })
end
