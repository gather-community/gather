# frozen_string_literal: true

module Admin
  # Operator dashboard for custom domains: whether each domain's mail DNS records (MX, SPF) are
  # correct and whether SMTP2GO has validated it for sending. Results are stored DomainMail::Check
  # rows (written by DomainMail::Checker), not fetched per request.
  class DomainsController < AdminController
    # Rough per-domain seconds for the refresh-all flash estimate: a few DNS lookups each, plus
    # fixed overhead for job pickup and the single SMTP2GO API call.
    REFRESH_OVERHEAD_SECONDS = 5
    REFRESH_SECONDS_PER_DOMAIN = 1

    def index
      authorize(%i[admin domain])
      prepare_lenses(:"admin/lists")
      domains = policy_scope([:admin, Domain]).custom.by_name
        .includes(:communities, :mail_check, :group_mailman_lists)
      if lenses[:lists].active?
        with_list_ids = Groups::Mailman::List.select(:domain_id)
        domains = if lenses[:lists].with_lists?
          domains.where(id: with_list_ids)
        else
          domains.where.not(id: with_list_ids)
        end
      end
      @report = DomainMail::Report.new(domains: domains)
      @smtp2go_configured = Smtp2go::Client.new.configured?
    end

    def show
      authorize(%i[admin domain])
      @domain = policy_scope([:admin, Domain]).custom
        .includes(:communities, :group_mailman_lists).find(params[:id])
      @status = DomainMail::Status.new(domain: @domain)
      @smtp2go_configured = Smtp2go::Client.new.configured?
    end

    # Re-checks one domain synchronously (member route) or all custom domains in a background
    # job (collection route).
    def refresh
      authorize(%i[admin domain])
      if params[:id]
        refresh_one
      else
        refresh_all
      end
      redirect_back(fallback_location: admin_domains_path)
    end

    private

    def refresh_one
      domain = policy_scope([:admin, Domain]).custom.find(params[:id])
      checker = DomainMail::Checker.new(domains: [domain])
      checker.run
      if checker.smtp2go_error == :request_failed
        flash[:error] = t("admin.domains.refresh_one_failed", domain: domain.name)
      else
        flash[:success] = t("admin.domains.refresh_one_success", domain: domain.name)
      end
    end

    def refresh_all
      DomainMail::RefreshJob.perform_later
      count = policy_scope([:admin, Domain]).custom.count
      seconds = REFRESH_OVERHEAD_SECONDS + REFRESH_SECONDS_PER_DOMAIN * count
      flash[:success] = t("admin.domains.refresh_all_started", count: count, seconds: seconds)
    end
  end
end
