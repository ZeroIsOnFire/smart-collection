require 'rails_helper'

RSpec.describe "Authentications", type: :request do
  let(:user) { User.create(email: "user@example.com", password: "password123", admin: false) }
  let(:admin) { User.create(email: "admin@example.com", password: "password123", admin: true) }

  describe "POST /users/sign_in" do
    it "redirects a normal user to root" do
      post user_session_path, params: { user: { email: user.email, password: "password123" } }
      expect(response).to redirect_to(root_path)
    end

    it "redirects an admin user to admin dashboard" do
      post user_session_path, params: { user: { email: admin.email, password: "password123" } }
      expect(response).to redirect_to(admin_dashboard_path)
    end
  end

  describe "Accessing Admin Dashboard" do
    it "prevents normal user from accessing admin dashboard" do
      sign_in user
      get admin_dashboard_path
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Not authorized")
    end

    it "allows admin user to access admin dashboard" do
      sign_in admin
      get admin_dashboard_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Admin Dashboard")
    end
  end
end
