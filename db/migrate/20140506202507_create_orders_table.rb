class CreateOrdersTable < ActiveRecord::Migration
  def change
    create_table :orders do |t|
      t.string :order_id
      t.string :description

      t.timestamps null: true
    end
  end
end
