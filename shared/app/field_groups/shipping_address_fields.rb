ShippingAddressFields = Permittable.fields do
  required :line1, :string, length: 1..100, normalize: :squish
  required :city, :string, length: 1..80, normalize: :squish
  required :postcode, :string, length: 3..10, normalize: :upcase
end
