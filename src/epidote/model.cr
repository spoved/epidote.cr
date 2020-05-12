require "json"
require "spoved/logger"
require "./attributes"

abstract class Epidote::Model
  include JSON::Serializable

  abstract def logger

  # Internal method to insert a new record
  protected abstract def _insert_record
  # Internal method to delete a record
  protected abstract def _delete_record
  # Internal methoid to update a record
  protected abstract def _update_record

  # This will save the record to the database but will raise any errors encountered
  # ```
  # model = MyModel.new(name: "one", unique_name: "model1")
  # model.save!
  # dupe_model = MyModel.new(name: "two", unique_name: "model1")
  # dupe_model.save! # Raises error
  # ```
  def save!
    self._insert_record
  end

  # This will save the record to the database but will suppress and log any errors encountered
  # ```
  # model = MyModel.new(name: "one", unique_name: "model1")
  # model.save
  # dupe_model = MyModel.new(name: "two", unique_name: "model1")
  # dupe_model.save # logs error only
  # ```
  def save
    self.save!
  rescue ex
    logger.error { ex }
  end

  # This will delete the record but will raise any errors encountered
  # ```
  # model = MyModel.new(name: "one", unique_name: "model1")
  # model.save!
  # model.destroy!
  # model.destroy! # Raises error
  # ```
  def destroy!
    self._delete_record
  end

  # This will delete the record but will suppress and log any errors encountered
  # ```
  # model = MyModel.new(name: "one", unique_name: "model1")
  # model.save!
  # model.destroy
  # model.destroy # logs error only
  # ```
  def destroy
    self.destroy!
  rescue ex
    logger.error { ex }
  end

  # This will update the record with any changes made to the instance. Raises any errors encountered
  # ```
  # model = MyModel.new(name: "one", unique_name: "model1")
  # model.save!
  # MyModel.new(name: "two", unique_name: "model2").save!
  # model.unique_name = "model2"
  # model.update! # Will raise an error
  # ```
  def update!
    self._update_record
  end

  # This will update the record with any changes made to the instance. Suppresses any errors encountered
  # ```
  # model = MyModel.new(name: "one", unique_name: "model1")
  # model.save!
  # MyModel.new(name: "two", unique_name: "model2").save!
  # model.unique_name = "model2"
  # model.update # logs error
  # ```
  def update
    self.update!
  rescue ex
    logger.error { ex }
  end
end
