class ObjClass < RailsConnector::CmsBaseModel
  has_many :obj_class_attrs
  has_many :attrs, class_name: "Attribute", through: :obj_class_attrs
end
