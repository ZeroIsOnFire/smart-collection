require 'rails_helper'

RSpec.describe User, type: :model do
  it 'is valid with valid attributes' do
    user = User.new(email: 'test@example.com', password: 'password123')
    expect(user).to be_valid
  end

  it 'defaults admin to false' do
    user = User.new(email: 'test@example.com', password: 'password123')
    expect(user.admin).to be false
  end

  it 'can be an admin' do
    user = User.new(email: 'admin@example.com', password: 'password123', admin: true)
    expect(user.admin).to be true
  end
end
