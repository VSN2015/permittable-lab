OrderScheduleFields = Permittable.fields do
  required :delivery_on, :date
  optional :pickup_at, :datetime
  optional :delivery_slot, :datetime
  optional :priority, :string, in: Order::PRIORITIES, default: "standard"
end
