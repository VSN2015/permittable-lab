StatusChange = Permittable::Contract.define do
  required :status, :string, in: Order.statuses
  optional :cancel_reason, :string, normalize: :squish, in: Order.cancel_reasons
  optional :remind_after, :string, format: /\A\d{1,4}\z/, transform: ->(minutes) { minutes.to_i * 60 }, default: 1800
end
