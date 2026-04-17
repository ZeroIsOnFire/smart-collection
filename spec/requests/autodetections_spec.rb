require 'rails_helper'

RSpec.describe "Autodetections", type: :request do
  let(:user) { create(:user) }
  let(:valid_params) do
    { autodetection: { photo: Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png') } }
  end

  before do
    sign_in user
    ActiveJob::Base.queue_adapter = :test
  end

  describe "POST /create" do
    it "creates an autodetection and redirects or responds with turbo stream" do
      expect {
        post autodetections_path, params: valid_params, as: :turbo_stream
      }.to change(Autodetection, :count).by(1)
       .and enqueue_job(AutodetectJob)
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    let(:autodetection) { create(:autodetection, :completed, user: user) }

    it "renders the show template" do
      get autodetection_path(autodetection)
      expect(response).to be_successful
    end
  end

  describe "PATCH /retry" do
    let(:autodetection) { create(:autodetection, :error, user: user) }

    it "retries the job and redirects" do
      expect {
        patch retry_autodetection_path(autodetection)
      }.to enqueue_job(AutodetectJob)
      
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("Processo reiniciado.")
    end
  end
  describe "DELETE /destroy" do
    let!(:autodetection) { create(:autodetection, user: user) }

    it "removes the autodetection and responds with turbo stream" do
      expect {
        delete autodetection_path(autodetection), as: :turbo_stream
      }.to change(Autodetection, :count).by(-1)
      
      expect(response).to be_successful
      expect(response.body).to include("turbo-stream action=\"remove\" target=\"autodetection_#{autodetection.id}\"")
    end

    it "redirects if format is html" do
      expect {
        delete autodetection_path(autodetection)
      }.to change(Autodetection, :count).by(-1)
      
      expect(response).to redirect_to(cars_path)
    end
  end
end
