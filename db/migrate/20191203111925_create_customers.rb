class CreateCustomers < ActiveRecord::Migration[6.0]
  def change
    create_table :customers do |t|
      t.string :name
      t.string :first_name
      t.string :email
      t.string :accepts_marketing
      t.string :account_activation_url
      t.references :shop, null: false, foreign_key: true

      t.timestamps
    end
  end
end
