# frozen_string_literal: true

require 'rails_helper'
require 'rake'

Rails.application.load_tasks

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe Rake::Task do
  subject(:task) { described_class['data:normalize_color_keys'] }

  let(:user) { create(:user) }
  let(:autodetection) { create(:autodetection, user: user) }

  before do
    task.reenable
  end

  it 'converts legacy values for cars and detected items without changing unknown values' do
    legacy_car = create(:car, user: user, color: 'Azul')
    normalized_car = create(:car, user: user, color: 'blue')
    unknown_car = create(:car, user: user, color: 'custom-color')
    legacy_item = create(:detected_item, autodetection: autodetection, color: 'Prata')
    normalized_item = create(:detected_item, autodetection: autodetection, color: 'silver')
    unknown_item = create(:detected_item, autodetection: autodetection, color: 'custom-color')

    task.invoke

    expect(legacy_car.reload.color).to eq('blue')
    expect(normalized_car.reload.color).to eq('blue')
    expect(unknown_car.reload.color).to eq('custom-color')
    expect(legacy_item.reload.color).to eq('silver')
    expect(normalized_item.reload.color).to eq('silver')
    expect(unknown_item.reload.color).to eq('custom-color')
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
