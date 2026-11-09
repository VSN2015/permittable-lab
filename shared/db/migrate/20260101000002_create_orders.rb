class CreateOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :orders do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :code, null: false
      t.string :status, null: false, default: "pending"
      t.string :priority, null: false, default: "standard"
      t.date :delivery_on, null: false
      t.datetime :pickup_at
      t.time :delivery_slot
      t.string :coupon_code
      t.string :note
      t.json :services, null: false, default: []
      t.json :shipping_address, null: false, default: {}
      t.timestamps
    end
    add_index :orders, :code, unique: true
  end
end
