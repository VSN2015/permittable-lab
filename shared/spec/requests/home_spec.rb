# README: Compatibility
RSpec.describe "Home", type: :request, covers: %w[] do
  it "shows the gem label and navbar links" do
    get "/"
    expect(response).to have_http_status(200)
    doc = Nokogiri::HTML(response.body)
    expect(doc.css("#lab-gem-label").text).to eq "#{Lab::GemSource.current.label(Permittable::VERSION)}, Rails #{Rails.version}"
    hrefs = doc.css("a").map { |a| a["href"] }
    expect(hrefs).to include("/orders?locale=vi", "/orders/new?locale=vi")
  end
end
