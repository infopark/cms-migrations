Fiona7.configure do |config|
  config.instance = ENV['FIONA7_INSTANCE']
  config.mode     = :standalone
end

Fiona7.custom_attribute_types = {
  child_order: :text
}
