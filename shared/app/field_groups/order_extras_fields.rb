OrderExtrasFields = Permittable.fields do
  optional :coupon_code, :string, format: /\A[A-Z]{3}\d{3}\z/
  optional :note, :string, length: 1..200, normalize: :squish, nullable: true
  array :services, of: :string, length: 0..3
end
