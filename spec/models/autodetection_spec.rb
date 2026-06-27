# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Autodetection, type: :model do
  describe 'broadcasts' do
    let(:user) { create(:user) }

    before do
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    end

    it 'replaces the user autodetections panel when created' do
      autodetection = create(:autodetection, user: user)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        "autodetections_#{user.id}",
        target: 'autodetections_panel',
        partial: 'autodetections/panel',
        locals: {
          autodetections: satisfy { |records| records.map(&:id) == [autodetection.id] }
        }
      )
    end

    it 'replaces the panel without completed autodetections after status changes' do
      autodetection = create(:autodetection, user: user)

      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
        "autodetections_#{user.id}",
        target: 'autodetections_panel',
        partial: 'autodetections/panel',
        locals: {
          autodetections: satisfy { |records| records.map(&:id).empty? }
        }
      )

      autodetection.update!(status: 'completed')
    end
  end
end
