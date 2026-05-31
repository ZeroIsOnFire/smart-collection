# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  it 'is valid with valid attributes' do
    user = described_class.new(name: 'Test', email: 'test@example.com', password: 'password123')
    expect(user).to be_valid
  end

  it 'defaults admin to false' do
    user = described_class.new(name: 'Test', email: 'test@example.com', password: 'password123')
    expect(user.admin).to be false
  end

  it 'defaults AI upscaling to enabled' do
    user = described_class.new(name: 'Test', email: 'test@example.com', password: 'password123')
    expect(user.ai_upscaling_enabled).to be true
  end

  it 'can be an admin' do
    user = described_class.new(name: 'Admin', email: 'admin@example.com', password: 'password123', admin: true)
    expect(user.admin).to be true
  end
end
