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

  def build_temp_image(width:, height:, filename: 'autodetection.jpg')
    tempfile = Tempfile.new(['upscaled', '.jpg'], Rails.root.join('tmp'))
    image = MiniMagick::Image.open(Rails.root.join('spec/fixtures/files/test_image.png'))
    image.resize "#{width}x#{height}!"
    image.write(tempfile.path)
    tempfile.define_singleton_method(:original_filename) { filename }
    tempfile.define_singleton_method(:content_type) { 'image/jpeg' }
    tempfile
  end

  describe '#create' do
    it 'creates an autodetection for the user and enqueues the job' do
      expect do
        service = described_class.new(user)
        autodetection = service.create(valid_params)
        expect(autodetection).to be_persisted
        expect(autodetection.status).to eq('pending')
      end.to change { user.reload.autodetections.count }.by(1)
                                                        .and enqueue_job(AutodetectJob)
    end

    it 'persists the autodetection photo upscaled to 1080px minimum side' do
      upscaled_file = build_temp_image(width: 1080, height: 1080)
      allow(ImageUpscalerService).to receive(:upscale_if_needed).and_return(upscaled_file)

      autodetection = described_class.new(user).create(valid_params)

      saved_image = MiniMagick::Image.open(autodetection.photo.path)
      expect(saved_image.width).to eq(1080)
      expect(saved_image.height).to eq(1080)
    ensure
      upscaled_file&.close
      upscaled_file&.unlink
    end

    it 'uses simple local fallback for autodetection photos when the user disables AI upscaling' do
      user.update!(ai_upscaling_enabled: false)
      upscaled_file = build_temp_image(width: 1080, height: 1080)

      expect(ImageUpscalerService).to receive(:upscale_if_needed)
        .with(valid_params[:photo], minimum_side: 1080, use_ai: false, local_fallback: true)
        .and_return(upscaled_file)

      autodetection = described_class.new(user).create(valid_params)

      expect(autodetection).to be_persisted
    ensure
      upscaled_file&.close
      upscaled_file&.unlink
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
