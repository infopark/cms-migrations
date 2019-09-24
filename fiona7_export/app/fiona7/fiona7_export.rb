require "addressable/uri"
require "fileutils"

class Fiona7Export
  def export(dir_name:, options: {path: "/", edited: false})
    raise "file '#{dir_name}' exists" if File.exist?(dir_name)
    FileUtils.mkdir_p(dir_name)
    FileUtils.mkdir_p(Rails.root + "tmp/cache")
    obj_count = 0
    File.open(File.join(dir_name, "objs.json"), "w") do |file|
      workspace_name = options['edited'] ? "rtc" : "published"
      get_obj_ids(workspace_name, options).each do |id|
        # The fiona7 gem redefines the Scrivito REST API in lib/fiona7/routers/rest_api.rb
        # by mapping it to database lookups in the rails connector tables.
        obj = Scrivito::CmsRestApi.task_unaware_request(:get, "workspaces/#{workspace_name}/objs/#{id}", {})
        next if obj["_obj_class"] =~ /Widget$/
        obj_attrs = export_attrs(obj["_id"], obj, dir_name)
        puts "Exporting: #{obj_attrs['_path']} (#{obj_attrs['_obj_class']})"
        file.write(JSON.generate(obj_attrs))
        file.write("\n")
        obj_count += 1
      end
    end
    puts "Exported #{obj_count} objects to #{dir_name}/objs.json"
  end

  private

  def fiona8_id(id)
    case id
    when /\A[0-9a-f]{16}\z/
      id
    else
      id.to_s.rjust(16, "0")
    end
  end

  def export_attrs(obj_id, attrs, dir_name)
    attrs.each_with_object({}) do |(k, v), h|
      if k == "_widget_pool"
        h[k] = v.each_with_object({}) do |(k1, v1), h1|
          h1[k1] = export_attrs(obj_id, v1, dir_name)
        end
      elsif k == "_id"
        h[k] = fiona8_id(v)
      elsif k.starts_with?("_")
        h[k] = v
      elsif k =~ /[A-Z]/
        # skip because Scrivito/Fiona8 does not allow uppercase letters in attribute names
        case v.first
        when "referencelist", "linklist", "stringlist"
          if v.last.present?
            puts "Warning: obj #{obj_id} contains an uppercase attribute #{k} (type #{v.first}, value #{v.last.inspect})"
          end
        else
          puts "Warning: obj #{obj_id} contains an uppercase attribute #{k} (type #{v.first}, value #{v.last.inspect})"
        end
      else
        case v.first
        when "reference"
          h[k] = ["reference", fiona8_id(v.last)] if v.last.present?
        when "referencelist"
          h[k] = ["referencelist", v.last.map{|ref| fiona8_id(ref)}] if v.last.present?
        when "link"
          h[k] = ["link", export_link(v.last)] if v.last.present?
        when "linklist"
          h[k] = ["linklist", v.last.map{|link| export_link(link)}] if v.last.present?
        when "binary"
          if (blob_attrs = v.last) && (filename = export_binary(blob_attrs["id"], dir_name))
            h[k] = ["binary", {"file" => filename}]
          else
            h[k] = ["binary", nil]
          end
        when "html"
          h[k] = ["html", export_html(v.last)] if v.last.present?
        when "enum"
          h[k] = ["string", v.last] if v.last.present?
        when "multienum"
          h[k] = ["stringlist", v.last] if v.last.present?
        else
          h[k] = v if v.last.present?
        end
      end
    end
  end

  def export_link(link)
    return unless link
    link = link.except("destination")
    if link["obj_id"].present?
      link["obj_id"] = fiona8_id(link["obj_id"])
    end
    link
  end

  def export_html(html)
    return unless html
    html.gsub(/\bobjid:(-?\d+)\b/) do
      "objid:#{fiona8_id($1.to_i)}"
    end
  end

  def export_binary(binary_id, dir_name)
    blob_id = normalize_path_component(binary_id)
    blob = Fiona7::BinaryHandling::MetaBinary.new(blob_id, false)
    return nil unless blob.present? && blob.filepath
    out_filename = "#{blob_id.parameterize}-#{blob.filename}"
    FileUtils.cp(blob.filepath, File.join(dir_name, out_filename))
    out_filename
  end

  def get_obj_ids(workspace_name, options)
    continuation = nil
    ids = []
    puts "get_obj_ids: "
    begin
      STDOUT.write("."); STDOUT.flush
      w = Scrivito::CmsRestApi.task_unaware_request(
        :get,
        "workspaces/#{workspace_name}/objs/search",
        {
          continuation: continuation,
          query: search_query(options)
        },
      )
      ids += w["results"].map {|r| r["id"]}
    end while (continuation = w["continuation"]).present?
    puts " DONE"
    ids
  end

  def normalize_path_component(s)
    Addressable::URI.normalize_component(s, Addressable::URI::CharacterClasses::UNRESERVED)
  end

  def search_query(options)
    if options[:path]
      return [{
        field: :_path,
        operator: :starts_with,
        value: options[:path],
      }]
    elsif options[:obj_class]
      return [{
        field: :_obj_class,
        operator: :equals,
        value: options[:obj_class],
      }]
    elsif options[:id]
      return [{
        field: :id,
        operator: :equals,
        value: options[:id],
      }]
    else
      raise "No options are set."
    end
  end
end
