class ObjClassAttr < RailsConnector::CmsBaseModel
  belongs_to :obj_class, foreign_key: "obj_class_id", class_name: "ObjClass"
  belongs_to :attr, foreign_key: "attribute_id", class_name: "Attribute"
end
