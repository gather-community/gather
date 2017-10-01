prefix = Rails.env.test? ? "/test" : ""
Paperclip::Attachment.default_options.merge!(
  path: ":rails_root/public/system#{prefix}/:class/:attachment/:id_partition/:style/:filename",
  url: "/system#{prefix}/:class/:attachment/:id_partition/:style/:filename"
)
