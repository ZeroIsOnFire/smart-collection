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

  it 'defaults locale to English' do
    user = described_class.new(name: 'Test', email: 'test@example.com', password: 'password123')
    expect(user.locale).to eq('en')
  end

  it 'rejects unavailable locales' do
    user = described_class.new(name: 'Test', email: 'test@example.com', password: 'password123', locale: 'es')
    expect(user).not_to be_valid
    expect(user.errors[:locale]).to be_present
  end

  it 'treats existing users as setup-completed by default' do
    user = described_class.new(name: 'Test', email: 'test@example.com', password: 'password123')
    expect(user.initial_setup_completed).to be true
    expect(user.initial_setup_pending?).to be false
  end

  it 'detects pending setup for non-admin users only' do
    user = described_class.new(name: 'Test', email: 'test@example.com', password: 'password123',
                               initial_setup_completed: false)
    admin = described_class.new(name: 'Admin', email: 'admin@example.com', password: 'password123',
                                admin: true, initial_setup_completed: false)

    expect(user.initial_setup_pending?).to be true
    expect(admin.initial_setup_pending?).to be false
  end

  it 'can be an admin' do
    user = described_class.new(name: 'Admin', email: 'admin@example.com', password: 'password123', admin: true)
    expect(user.admin).to be true
  end
end
