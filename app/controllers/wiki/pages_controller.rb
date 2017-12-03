module Wiki
  class PagesController < ApplicationController
    include Irwi::Extensions::Controllers::WikiPageAttachments
    include Irwi::Support::TemplateFinder

    before_action :setup_page,
      only: [:show, :history, :compare, :new, :edit, :update, :destroy, :add_attachment]
    before_action :set_community, only: [:show, :new, :update]
    before_action -> { nav_context(:wiki) }
    before_action :setup_current_user # Setup @current_user instance variable before each action

    decorates_assigned :page

    def self.page_class
      @page_class ||= Irwi.config.page_class
    end

    def self.set_page_class(arg)
      @page_class = arg
    end

    def all
      authorize sample_page
      @pages = policy_scope(Page).in_community(current_community).by_title
    end

    def show
      authorize @page
      render_template(@page.new_record? ? 'no' : 'show')
    end

    def history
      authorize @page
      @versions = Irwi.config.paginator.paginate(@page.versions, page: params[:page])
      render_template(@page.new_record? ? 'no' : 'history')
    end

    def compare
      authorize @page
      if @page.new_record?
        render_template("no")
      else
        new_num = params[:new].to_i || @page.last_version_number # Last version number
        old_num = params[:old].to_i || 1 # First version number

        old_num, new_num = new_num, old_num if new_num < old_num # Swapping them if last < first

        versions = @page.versions.between( old_num, new_num ) # Loading all versions between first and last

        @versions = Irwi.config.paginator.paginate( versions, page: params[:page] ) # Paginating them

        @new_version = @versions.first.number == new_num ? @versions.first : versions.first # Loading next version
        @old_version = @versions.last.number == old_num ? @versions.last : versions.last # Loading previous version

        render_template("compare")
      end
    end

    def new
      authorize @page
      render_template("new")
    end

    def edit
      authorize @page
      render_template("edit")
    end

    def update
      authorize @page
      @page.attributes = permitted_page_params
      @page.updator = current_user
      @page.creator = current_user if @page.new_record?

      if !params[:preview] && (params[:cancel] || @page.save)
        redirect_to url_for(action: :show, path: @page.path.split('/'))
      else
        render_template("edit")
      end
    end

    def destroy
      authorize @page
      @page.destroy
      redirect_to url_for( action: :show )
    end

    private

    def permitted_page_params
      params.require(:page).permit(:title, :content, :comment)
    end

    # Retrieves wiki_page_class for this controller
    def page_class
      self.class.page_class
    end

    # Renders user-specified or default template
    def render_template(template)
      render "#{template_dir template}/#{template}", status: (case template when 'no' then 404 when 'not_allowed' then 403 else 200 end)
    end

    # Initialize @current_user instance variable
    def setup_current_user
      @current_user = respond_to?( :current_user, true ) ? current_user : nil # Find user by current_user method or return nil
    end

    # Initialize @page instance variable
    def setup_page
      @page = page_class.find_by_path_or_new(params[:path] || '') # Find existing page by path or create new
    end

    def sample_page
      Page.new(community: current_community)
    end

    def set_community
      @page.community = current_community
    end
  end
end
