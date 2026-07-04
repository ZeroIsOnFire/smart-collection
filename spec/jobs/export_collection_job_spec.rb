# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExportCollectionJob, type: :job do
  it 'generates wishlist CSV exports in the background' do
    user = create(:user)
    create(:wishlist_item, user: user, name: 'Background wish')
    export = CollectionExport.create!(user: user, format_type: 'csv', export_type: 'wishlist')

    described_class.perform_now(export.id.to_s)

    export.reload
    expect(export.status).to eq('completed')
    expect(export[:file]).to be_present
    expect(export[:file]).to end_with('.csv')
  end

  it 'generates wishlist PDF exports in the background' do
    user = create(:user)
    create(:wishlist_item, user: user)
    export = CollectionExport.create!(user: user, format_type: 'pdf', export_type: 'wishlist')

    described_class.perform_now(export.id.to_s)

    export.reload
    expect(export.status).to eq('completed')
    expect(export[:file]).to be_present
    expect(export[:file]).to end_with('.pdf')
  end
end
