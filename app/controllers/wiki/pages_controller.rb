module Wiki
  class PagesController < ApplicationController
    include Irwi::Extensions::Controllers::WikiPageAttachments
    include Irwi::Support::TemplateFinder

    before_action :find_page, only: [:history, :compare, :edit, :update, :destroy]
    before_action -> { nav_context(:wiki) }

    decorates_assigned :page, :pages, :versions

    def index
      skip_policy_scope
      redirect_to home_path
    end

    def show
      @page = Page.find_by(slug: params[:slug])
      if @page.nil?
        if params[:slug] == Page.reserved_slug(:home)
          @page = Page.create_home_page(community: current_community, creator: current_user)
        else
          raise ActiveRecord::RecordNotFound
        end
      end
      authorize @page
    end

    def new
      if params[:title]
        flash.now[:notice] = t("wiki.not_found_create", title: params[:title])
      end
      @page = Page.new(title: params[:title], community: current_community)
      authorize @page
    end

    def edit
      authorize @page
    end

    def create
      @page = Page.new(community: current_community)
      authorize @page
      @page.assign_attributes(page_params)
      @page.creator = @page.updator = current_user
      redirect_on_success_or_rerender_on_error_or_preview(:new)
    end

    def update
      authorize @page
      @page.attributes = page_params
      @page.updator = current_user
      redirect_on_success_or_rerender_on_error_or_preview(:edit)
    end

    def destroy
      authorize @page
      @page.destroy
      redirect_to home_path
    end

    def all
      authorize sample_page
      @pages = policy_scope(Page).in_community(current_community).by_title
    end

    def history
      authorize @page
      @versions = @page.versions
      render_not_found if @page.new_record?
    end

    def compare
      authorize @page
      if @page.new_record?
        render_not_found
      else
        new_num = params[:new].to_i || @page.last_version_number # Last version number
        old_num = params[:old].to_i || 1 # First version number

        old_num, new_num = new_num, old_num if new_num < old_num # Swapping them if last < first

        versions = @page.versions.between(old_num, new_num)
        @versions = Irwi.config.paginator.paginate(versions, page: params[:page])
        @new_version = @versions.first.number == new_num ? @versions.first : versions.first
        @old_version = @versions.last.number == old_num ? @versions.last : versions.last
      end
    end

    private

    def home_path
      wiki_page_path(slug: Page.reserved_slug(:home))
    end

    # Pundit built-in helper doesn't work due to namespacing
    def page_params
      params.require(:wiki_page).permit(policy(@page).permitted_attributes)
    end

    def find_page
      @page = Page.find_by!(slug: params[:slug])
    end

    def sample_page
      Page.new(community: current_community)
    end

    def redirect_on_success_or_rerender_on_error_or_preview(action)
      if !params[:preview] && (params[:cancel] || @page.save)
        redirect_to wiki_page_path(@page)
      else
        render action
      end
    end
  end
end
