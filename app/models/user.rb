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

  index({ share_token: 1 }, { unique: true, sparse: true, background: true })

  ## Admin flag
  field :admin, type: Boolean, default: false

  validates :name, presence: true

  before_save :ensure_share_token, if: :sharing_enabled?

  private

  def ensure_share_token
    self.share_token ||= SecureRandom.uuid
  end

  has_many :cars, class_name: 'Car', dependent: :destroy
  has_many :autodetections, dependent: :destroy
  has_many :collection_exports, dependent: :destroy

  index({ email: 1 }, { unique: true, background: true })
  index({ reset_password_token: 1 }, { unique: true, sparse: true, background: true })
end
