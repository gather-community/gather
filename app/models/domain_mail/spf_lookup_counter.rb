# frozen_string_literal: true

module DomainMail
  # Statically counts the DNS lookups an SPF evaluation of a record would need. RFC 7208 allows
  # at most 10: each include, redirect, a, mx, ptr, and exists term costs one, and include /
  # redirect recurse into the referenced domain's own SPF record, whose terms count against the
  # same budget. ip4 / ip6 / all cost nothing. Returns the counted terms as a tree in evaluation
  # order — each include/redirect term carries the terms of the record it pulls in as "children"
  # — so the show page can render the nesting; the lookup count is the total number of nodes.
  class SpfLookupCounter
    # Hard stop for pathological or circular include chains, comfortably past the point where
    # the record has already failed the RFC limit.
    MAX_TERMS = 30

    def initialize(dns_checker:)
      @dns_checker = dns_checker
    end

    def count_terms(spf_record)
      @count = 0
      @visited = Set.new
      walk(spf_record)
    end

    private

    def walk(record)
      terms = []
      record.to_s.split(/\s+/).each do |raw|
        break if @count >= MAX_TERMS
        term = raw.sub(/\A[+\-~?]/, "")
        case term
        when /\A(?:include:|redirect=)(\S+)\z/i
          @count += 1
          terms << {"term" => term, "children" => recurse(Regexp.last_match(1))}
        when /\Aa(?::[^\s\/]+)?(?:\/\d+)?\z/i, /\Amx(?::[^\s\/]+)?(?:\/\d+)?\z/i,
          /\Aptr(?::\S+)?\z/i, /\Aexists:\S+\z/i
          @count += 1
          terms << {"term" => term, "children" => []}
        end
      end
      terms
    end

    # Macros (%{...}) can't be resolved statically, and a domain already visited would loop
    # forever, so neither is descended into (the include itself is still counted above).
    def recurse(target)
      target = target.downcase.delete_suffix(".")
      return [] if target.include?("%") || @visited.include?(target)
      @visited << target
      nested = @dns_checker.spf_record(target)
      nested ? walk(nested) : []
    end
  end
end
