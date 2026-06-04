# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutodetectionService do
  let(:user) { create(:user) }
  let(:valid_params) do
    { photo: Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png') }
  end

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  describe '#create' do
    it 'falls back to 1080 when the autodetection minimum side env var is invalid' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('AUTODETECTION_MINIMUM_SIDE', nil).and_return('0')

      expect(described_class.autodetection_minimum_side).to eq(1080)
    end

    it 'creates an autodetection for the user and enqueues the job' do
      expect do
        service = described_class.new(user)
        autodetection = service.create(valid_params)
        expect(autodetection).to be_persisted
        expect(autodetection.status).to eq('pending')
      end.to change { user.reload.autodetections.count }.by(1)
                                                        .and enqueue_job(AutodetectJob)
    end

    it 'does not run image upscaling before enqueueing the background job' do
      expect(ImageUpscalerService).not_to receive(:upscale_if_needed)

      autodetection = described_class.new(user).create(valid_params)

      expect(autodetection).to be_persisted
    end
  end

  describe '#retry' do
    let(:autodetection) { create(:autodetection, :error, user: user) }

    it 'resets the status and re-enqueues the job' do
      expect do
        described_class.new(user).retry(autodetection.id.to_s)
      end.to enqueue_job(AutodetectJob).with(autodetection.id.to_s)

      expect(autodetection.reload.status).to eq('pending')
      expect(autodetection.error_message).to be_nil
    end
  end
end
