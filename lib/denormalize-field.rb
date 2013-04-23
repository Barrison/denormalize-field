require 'active_record'
require 'active_support'
require 'active_support/inflector'

class DenormalizeUpdater
  def self.sync_all
    DenormalizeFields::UPDATE_STATEMENTS.each do |sql|
      DenormalizeFields::CLASSES.first.connection.execute sql
    end
  end
end

module DenormalizeFields
  UPDATE_STATEMENTS = []
  CLASSES = []

  def denormalizes(hash)
    hash.keys.each do |key|
      _field_name = hash[key]
      _original_klass = self
      _denormalized_field_name = "#{key}_#{_field_name}"

      before_save do
        if self.send(key)
          self.send "#{_denormalized_field_name}=", self.send(key).send(_field_name)
        end
      end

      _klass = key.to_s.camelize.constantize
      update_sql = "UPDATE #{table_name} SET #{_denormalized_field_name} = c2.#{_field_name} FROM #{table_name} c1 INNER JOIN #{_klass.table_name} c2 on c2.id = c1.#{key}_id"

      _klass.after_save do
        if self.send "#{_field_name}_changed?"
          self.connection.execute update_sql
        end
      end

      self.class.class_eval <<-EVAL
        def out_of_sync
          #{self.name}.where("id in (SELECT c1.id FROM #{table_name} c1 INNER JOIN #{_klass.table_name} c2 on c2.id = c1.#{key}_id where c1.#{_denormalized_field_name} != c2.#{_field_name})")
        end
        EVAL

      UPDATE_STATEMENTS.push update_sql
      CLASSES.push self
    end
  end
end

ActiveRecord::Base.send :extend, DenormalizeFields
