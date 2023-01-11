require "active_support/all"
require 'dotenv/load'

require_relative "rest_api"

class ScrivitoImport
  def import(dir_name:)
    base_url = ENV.fetch("SCRIVITO_BASE_URL") { "https://api.scrivito.com" }
    tenant = ENV.fetch("SCRIVITO_TENANT")
    api_key = ENV.fetch("SCRIVITO_API_KEY")
    api = RestApi.new(base_url, tenant, api_key)

    workspace_id = api.post("workspaces", "workspace" => { "title" => "loader (do not touch)"})["id"]
    puts("Created loader working copy #{workspace_id}")
    old_obj_ids = get_obj_ids(api, workspace_id)
    puts("Deleting #{old_obj_ids.size} old objs")
    old_obj_ids.each do |id|
      api.delete("workspaces/#{workspace_id}/objs/#{id}")
    end

    puts("Creating objs")
    File.foreach(File.join(dir_name, "objs.json")).with_index do |line, line_num|
      obj = JSON.load(line)
      puts("[##{line_num}] Creating obj: #{obj['_obj_class']} #{obj['_path']}")
      attrs = import_attrs(api, obj, dir_name)
      retry_command { api.post("workspaces/#{workspace_id}/objs", "obj" => attrs) }
    end

    api.put("workspaces/#{workspace_id}/publish", nil)
  end

  private

  def retry_command(&block)
    begin
      retries ||= 0
      block.call
    rescue => e
      puts "  command failed: #{e}"
      if (retries += 1) < 3
        puts "  retrying"
        retry
      end
      puts "  ignoring error"
    end
  end

  def import_attrs(api, attrs, dir_name)
    obj_id = attrs["_id"]
    attrs.inject({}) do |h, (k, v)|
      h[k] =
        if k == "_widget_pool"
          v.inject({}) do |h1, (k1, v1)|
            h1[k1] = import_attrs(api, v1, dir_name)
            h1
          end
        elsif k.starts_with?("_")
          v
        else
          case v.first
          when "binary"
            if (blob_attrs = v.last)
              ["binary", import_binary(api, blob_attrs["file"], obj_id, dir_name)]
            else
              ["binary", nil]
            end
          else
            v
          end
        end
      h
    end
  end

  def import_binary(api, filename, obj_id, dir_name)
    path = File.join(dir_name, filename)
    mime_type = %x(file --brief --mime-type #{path}).strip
    file = File.new(path)
    retry_command {
      api.upload_future_binary(file, File.basename(file), obj_id, content_type: mime_type)
    }
  end

  def get_obj_ids(api, workspace_id)
    continuation = nil
    ids = []
    begin
      w = api.get("workspaces/#{workspace_id}/objs/search", "continuation" => continuation)
      ids += w["results"].map {|r| r["id"]}
    end while (continuation = w["continuation"]).present?
    ids
  end
end

dir_name = ARGV.first or raise "missing dir_name param"
ScrivitoImport.new.import(dir_name: dir_name)
