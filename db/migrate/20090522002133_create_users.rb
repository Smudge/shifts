class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.string :login
      t.string :first_name
      t.string :last_name
      t.string :nick_name
      t.string :employee_id #optional, but pretty standard, and can be used under any id system (not just Yale)
      t.string :email
      t.references :default_department
      t.timestamps
    end
  end

  def self.down
    drop_table :users
  end
end

