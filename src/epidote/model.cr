require "json"
require "spoved/logger"
require "./attributes"
require "./error"
require "./adapter"

abstract class Epidote::Model
  include JSON::Serializable

  abstract def logger

  # Internal method to insert a new record
  protected abstract def _insert_record
  # Internal method to delete a record
  protected abstract def _delete_record
  # Internal methoid to update a record
  protected abstract def _update_record

  # Will check if the record is valid and return `false` if it is not
  abstract def valid? : Bool
  # Will check if the record is valid and raise an error if it is not
  abstract def valid! : Bool

  abstract def adapter : Epidote::Adapter.class

  @[JSON::Field(ignore: true)]
  protected property saved : Bool = false

  @[JSON::Field(ignore: true)]
  protected property dirty : Bool = false

  # Indicates if the record has been saved to the database or is a new record
  def saved?
    saved
  end

  # Indicates if the record has been modified and changes have not been saved
  def dirty?
    !saved? || dirty
  end

  protected def mark_dirty
    self.dirty = true
  end

  # This will save the record to the database but will raise any errors encountered
  # ```
  # model = MyModel.new(name: "one", unique_name: "model1")
  # model.save!
  # dupe_model = MyModel.new(name: "two", unique_name: "model1")
  # dupe_model.save! # Raises error
  # ```
  def save!
    self._insert_record
    self.saved = true
    self.dirty = false
    self
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
  def destroy! : Nil
    self._delete_record
    self.saved = false
    mark_dirty
  end

  # This will delete the record but will suppress and log any errors encountered
  # ```
  # model = MyModel.new(name: "one", unique_name: "model1")
  # model.save!
  # model.destroy
  # model.destroy # logs error only
  # ```
  def destroy : Nil
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
    self.dirty = false
    self
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
