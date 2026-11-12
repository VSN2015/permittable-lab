class AddCancelReasonAndRemindAfterToOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :orders, :cancel_reason, :integer
    add_column :orders, :remind_after, :integer
  end
end
