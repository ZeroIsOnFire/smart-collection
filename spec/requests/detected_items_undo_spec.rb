# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DetectedItems Undo', type: :request do
  before do
    @user = create(:user)
    @autodetection = create(:autodetection, user: @user)
    @car = create(:car, user: @user)
    @detected_item = create(:detected_item, autodetection: @autodetection, status: 'saved', car_id: @car.id)
    sign_in @user
  end

  describe 'PATCH /undo' do
    it 'removes the associated car and sets item to pending' do
      @autodetection.update(status: 'completed')

      expect do
        patch undo_detected_item_path(@detected_item)
      end.to change(Car, :count).by(-1)

      @detected_item.reload
      expect(@detected_item.status).to eq('pending')
      expect(@detected_item.car_id).to be_nil

      @autodetection.reload
      expect(@autodetection.status).to eq('to_verify')
    end

    it 'handles cases where the car is already deleted (no crash)' do
      @car.destroy

      expect do
        patch undo_detected_item_path(@detected_item)
      end.not_to change(Car, :count)

      @detected_item.reload
      expect(@detected_item.status).to eq('pending')
      expect(@detected_item.car_id).to be_nil
    end
  end
end
