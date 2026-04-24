require 'rails_helper'

RSpec.describe ExportPdfService do
  let(:user) { create(:user, name: "Test User") }
  let(:cars) { create_list(:car, 2, user: user) }
  let(:service) { ExportPdfService.new(user, cars) }

  describe "#generate" do
    it "generates a PDF content" do
      pdf_content = service.generate
      expect(pdf_content).to be_a(String)
      expect(pdf_content).to start_with("%PDF")
    end

    it "handles users with special characters in name" do
      user.update(name: "João Ações")
      pdf_content = service.generate
      expect(pdf_content).to be_a(String)
    end
  end
end
