class User
  include Mongoid::Document
  include Mongoid::Timestamps

  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  ## Database authenticatable
  field :email,              type: String, default: ""
  field :encrypted_password, type: String, default: ""

  ## Recoverable
  field :reset_password_token,   type: String
  field :reset_password_sent_at, type: Time

  ## Rememberable
  field :remember_created_at, type: Time

  ## Admin flag
  field :admin, type: Boolean, default: false

  index({ email: 1 }, { unique: true, background: true })
  index({ reset_password_token: 1 }, { unique: true, sparse: true, background: true })
end
