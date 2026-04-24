require 'rails_helper'

RSpec.describe "Cars", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:car) { create(:car, user: user) }
  
  let(:valid_attributes) do
    {
      name: 'Civic',
      brand: 'Hot Wheels',
      manufacturer: 'Honda',
      year: 2020
    }
  end

  before do
    sign_in user
  end

  describe "GET /index" do
    it "renders a successful response and shows only user's cars" do
      car # create
      other_car = create(:car, user: other_user)
      get cars_path
      expect(response).to be_successful
    end

    context "with search parameter" do
      before(:each) do
        Car.create_indexes
      end

      let!(:car_matching) { create(:car, user: user, name: 'Searchable Car') }
      let!(:car_not_matching) { create(:car, user: user, name: 'Other Car') }

      it "filters cars by name" do
        get cars_path, params: { q: 'Searchable' }
        expect(response.body).to include('Searchable Car')
        expect(response.body).not_to include('Other Car')
      end

      it "filters cars by brand" do
        car_matching.update!(brand: 'Toyota')
        get cars_path, params: { q: 'Toyota' }
        expect(response.body).to include('Searchable Car')
      end

      it "filters cars by manufacturer" do
        car_matching.update!(manufacturer: 'Burago')
        get cars_path, params: { q: 'Burago' }
        expect(response.body).to include('Searchable Car')
      end

      it "filters cars by tags" do
        car_matching.update!(tags: ['match'])
        get cars_path, params: { q: 'match' }
        expect(response.body).to include('Searchable Car')
      end

    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_car_path
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Car" do
        expect {
          post cars_path, params: { car: valid_attributes }
        }.to change(Car, :count).by(1)
      end

      it "redirects to the created car" do
        post cars_path, params: { car: valid_attributes }
        expect(response).to redirect_to(car_url(Car.last))
      end

      it "creates a car with a photo" do
        attributes_with_photo = valid_attributes.merge(
          photo: fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
        )
        expect {
          post cars_path, params: { car: attributes_with_photo }
        }.to change(Car, :count).by(1)
        
        expect(Car.last.photo).to be_present
      end
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      get edit_car_path(car)
      expect(response).to be_successful
    end

    it "redirects if trying to edit another user's car" do
      other_car = create(:car, user: other_user)
      get edit_car_path(other_car)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) { { name: 'New Name' } }

      it "updates the requested car" do
        patch car_path(car), params: { car: new_attributes }
        car.reload
        expect(car.name).to eq('New Name')
      end

      it "redirects to the car list" do
        patch car_path(car), params: { car: new_attributes }
        car.reload
        expect(response).to redirect_to(car_url(car))
      end

      it "removes the photo when remove_photo is '1'" do
        car_with_photo = create(:car, user: user)
        # Give it a photo first
        car_with_photo.photo = fixture_file_upload(
          Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png'
        )
        car_with_photo.save!
        expect(car_with_photo.reload.photo).to be_present

        patch car_path(car_with_photo), params: { car: { remove_photo: '1' } }
        expect(response).to redirect_to(car_url(car_with_photo))
        expect(Car.find(car_with_photo.id).photo).not_to be_present
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested car" do
      car_to_destroy = create(:car, user: user)
      expect {
        delete car_path(car_to_destroy)
      }.to change(Car, :count).by(-1)
    end

    it "redirects to the cars list" do
      delete car_path(car)
      expect(response).to redirect_to(cars_path)
    end
  end
end
