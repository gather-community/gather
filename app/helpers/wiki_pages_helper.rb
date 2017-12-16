module WikiPagesHelper
  include Irwi::Support::TemplateFinder
  include Irwi::Helpers::WikiPageAttachmentsHelper

  def wiki_page_attachments(page = @page)
    return unless Irwi::config.page_attachment_class_name

    page.attachments.each do |attachment|
      concat image_tag(attachment.wiki_page_attachment.url(:thumb))
      concat "Attachment_#{attachment.id}"
      concat link_to(wt('Remove'), wiki_remove_page_attachment_path(attachment.id), method: :delete)
    end

    form_for(Irwi.config.page_attachment_class.new,
             as: :wiki_page_attachment,
             url: wiki_add_page_attachment_path(page),
             html: { multipart: true }) do |form|
      concat form.file_field :wiki_page_attachment
      concat form.hidden_field :page_id, value: page.id
      concat form.submit 'Add Attachment'
    end
  end
end
