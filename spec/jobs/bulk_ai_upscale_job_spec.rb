# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BulkAiUpscaleJob do
  let(:user) { create(:user, bulk_ai_upscaling_enabled: true) }

  def attach_photo!(car, width: 240, height: 240)
    tempfile = Tempfile.new(['bulk_photo', '.jpg'], Rails.root.join('tmp'))
    image = MiniMagick::Image.open(Rails.root.join('spec/fixtures/files/test_image.png'))
    image.resize "#{width}x#{height}!"
    image.write(tempfile.path)

    car.photo = Rack::Test::UploadedFile.new(tempfile.path, 'image/jpeg')
    car.save!
    car
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(ImageUpscalerService).to receive(:service_configured?).and_return(true)
  end

  it 'enqueues at most three eligible cars for the current user' do
    create_list(:car, 4, user: user).each { |car| attach_photo!(car) }
    other_user_car = attach_photo!(create(:car))

    expect do
      described_class.new.perform(user.id.to_s)
    end.to have_enqueued_job(CarImageProcessingJob).exactly(3).times

    expect(other_user_car.reload.photo_processing_status).to be_nil
  end

  it 'does not enqueue cars that already have an enhanced photo' do
    car = attach_photo!(create(:car, user: user))
    car.enhanced_photo = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/car_sample.jpg'), 'image/jpeg')
    car.save!

    expect do
      described_class.new.perform(user.id.to_s)
    end.not_to have_enqueued_job(CarImageProcessingJob)
  end

  it 'does not enqueue cars whose photo already meets the minimum side' do
    attach_photo!(create(:car, user: user), width: 420, height: 420)

    expect do
      described_class.new.perform(user.id.to_s)
    end.not_to have_enqueued_job(CarImageProcessingJob)
  end

  it 'does not enqueue when the user disables bulk upscaling' do
    user.update!(bulk_ai_upscaling_enabled: false)
    attach_photo!(create(:car, user: user))

    expect do
      described_class.new.perform(user.id.to_s)
    end.not_to have_enqueued_job(CarImageProcessingJob)
  end
end
