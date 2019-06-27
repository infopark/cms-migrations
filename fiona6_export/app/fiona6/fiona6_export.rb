require "addressable/uri"
require "fileutils"

class Fiona6Export
  def analyze(output_config:)
    renamed_obj_classes = analyze_obj_classes
    renamed_attributes_per_obj_class = analyze_attributes

    File.open(output_config, "w") do |file|
      file.write(JSON.pretty_generate({
        "rename_obj_classes" => renamed_obj_classes,
        "rename_attributes" => renamed_attributes_per_obj_class,
      }))
      file.write("\n")
    end
  end

  def export(config:, dir_name:)
  end

  private

  # analyze_obj_classes returns a map of renamed obj classes (old name => new name).
  def analyze_obj_classes
    obj_class_mappings = [] # we'll collect pairs [old name, new name]

    ObjClass.all.order(:obj_class_name).each do |obj_class|
      old_name = obj_class.obj_class_name
      new_name = determine_new_obj_class_name(old_name)
      obj_class_mappings << [old_name, new_name]
    end

    # If the obj class is not renamed, old name and new name are the same. We'll report duplicate
    # new names because renaming could result in multiple obj classes having the same name.
    dups = find_duplicates(obj_class_mappings.map(&:last))
    if dups.present?
      puts "Warning: possible conflict: duplicate obj classes after renaming: #{dups}"
    end

    # We only want to record renamings where the new name differs. So we clean up the mappings.
    obj_class_mappings.delete_if {|old_name, new_name| old_name == new_name}
    Hash[obj_class_mappings]
  end

  # analyze_attributes returns a map of renamed attributes (old name => new name).
  def analyze_attributes
    renamed_attributes_per_obj_class = {}
    ObjClass.all.order(:obj_class_name).each do |obj_class|
      rename_attributes = analyze_attributes_for_obj_class(obj_class)
      if rename_attributes.present?
        renamed_attributes_per_obj_class[obj_class.obj_class_name] = rename_attributes
      end
    end
    renamed_attributes_per_obj_class
  end

  # analyze_attributes returns a map of renamed attributes (old name => new name) for an obj class.
  def analyze_attributes_for_obj_class(obj_class)
    attr_mappings = [] # we'll collect pairs [old name, new name]

    obj_class.attrs.order(:attribute_name).each do |attr|
      old_name = attr.attribute_name
      new_name = determine_new_attribute_name(old_name)
      attr_mappings << [old_name, new_name]
    end

    # If the attribute is not renamed, old name and new name are the same. We'll report duplicate
    # new names because renaming could result in multiple attributes having the same name.
    dups = find_duplicates(attr_mappings.map(&:last))
    if dups.present?
      puts "Warning: obj class #{obj_class.obj_class_name}: possible conflict: duplicate attributes after renaming: #{dups}"
    end

    # We only want to record renamings where the new name differs. So we clean up the mappings.
    attr_mappings.delete_if {|old_name, new_name| old_name == new_name}
    Hash[attr_mappings]
  end

  def determine_new_obj_class_name(name)
    new_name = name
    unless new_name =~ /^[A-Z]/
      new_name = new_name.camelcase
    end
    if new_name.starts_with?("_")
      new_name = "X#{new_name}"
    end
    new_name
  end

  def determine_new_attribute_name(name)
    new_name = name
    if new_name =~ /[A-Z]/
      new_name = new_name.underscore
    end
    if new_name.starts_with?("_")
      new_name = "x#{new_name}"
    end
    new_name
  end

  def find_duplicates(array)
    array.select {|item| array.count(item) > 1 }.uniq
  end
end
