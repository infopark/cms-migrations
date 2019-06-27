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
    conf = JSON.load(File.read(config))
    renamed_obj_classes = conf["rename_obj_classes"] || {}
    renamed_attrs = conf["rename_attributes"] || {}

    raise "file '#{dir_name}' exists" if File.exist?(dir_name)
    FileUtils.mkdir_p(dir_name)

    obj_count = 0
    File.open(File.join(dir_name, "objs.json"), "w") do |file|
      get_objs.each do |obj|
        obj_attrs = export_attrs(obj, dir_name, renamed_obj_classes, renamed_attrs)
        puts "Exporting: #{obj_attrs['_path']} (#{obj_attrs['_obj_class']})"
        file.write(JSON.generate(obj_attrs))
        file.write("\n")
        obj_count += 1
      end
    end
    puts "Exported #{obj_count} objects to #{dir_name}/objs.json"
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

  def get_objs
    Obj.all
  end

  def export_attrs(obj, dir_name, renamed_obj_classes, renamed_attrs)
    attrs = {
      "_id" => fiona8_id(obj.id),
      "_last_changed" => fiona8_attr_pair("date", obj.last_changed_before_type_cast),
      "_obj_class" => renamed_obj_classes[obj.obj_class] || obj.obj_class,
      "_path" => obj.path,
      "_permalink" => fiona8_attr_pair("string", obj.permalink),
      "permitted_groups" => fiona8_attr_pair("stringlist", obj.permitted_groups),
      "suppress_export" => fiona8_attr_pair("string", (obj.suppress_export == 1 ? "yes" : "no")),
      "title" => fiona8_attr_pair("string", obj.title),
      "valid_from" => fiona8_attr_pair("date", obj.valid_from_before_type_cast),
      "valid_until" => fiona8_attr_pair("date", obj.valid_until_before_type_cast),
    }
    unless obj.binary?
      attrs["body"] = fiona8_attr_pair("html", export_html(obj, obj["body"]))
    end
    obj.attr_defs.each do |attr_name, attr_def|
      new_attr_name = (renamed_attrs[obj.obj_class] || {})[attr_name] || attr_name
      case t = attr_def["type"]
      when "string", "text", "enum"
        attrs[new_attr_name] ||= fiona8_attr_pair("string", obj[attr_name])
      when "multienum"
        attrs[new_attr_name] ||= fiona8_attr_pair("stringlist", obj[attr_name])
      when "linklist"
        attrs[new_attr_name] ||= fiona8_attr_pair("linklist",
            obj[attr_name].to_a.map{|link| export_link(link) })
      when "html"
        attrs[new_attr_name] ||= fiona8_attr_pair("html", export_html(obj, obj[attr_name]))
      else
        puts "unknown attr type: #{t}"
      end
    end
    attrs.compact
  end

  def fiona8_id(id)
    return nil unless id
    case id
    when /\A[0-9a-f]{16}\z/
      id
    else
      id.to_s.rjust(16, "0")
    end
  end

  def fiona8_attr_pair(type, value)
    [type, value] if value.present?
  end

  def export_link(link)
    return unless link
    {
      "fragment" => link.fragment,
      "obj_id" => fiona8_id(link.destination_object_id),
      "query" => link.query,
      "target" => link.target,
      "title" => link.title,
      "url" => link.url,
    }.compact
  end

  def export_html(obj, html)
    return unless html.present?
    link_map = obj.text_links.each_with_object({}) do |link, map|
      map[link.id.to_s] = link
    end
    html.gsub(/\binternallink:(\d+)\b/) do
      link = link_map[$1.to_s]
      if link.blank?
        ""
      else
        if link.external?
          link.url.gsub("external:")
        else
          dest_obj_id = link.destination_object_id
          "objid:#{fiona8_id(dest_obj_id)}"
        end
      end
    end
  end
end
