# frozen_string_literal: true

module Work
  # Builds the synopsis string for the shifts page.
  class SynopsisDecorator < WorkDecorator
    delegate_all

    # Converts Synopsis to nice string. See spec for data examples.
    def to_s
      return @to_s if defined?(@to_s)
      return (@to_s = nil) if empty?

      sentences = %i[for_user for_household].map do |who|
        next unless send(who)

        chunks = send(who).map { |i| chunk_for_item(i) }
        safe_str << h.t("work.synopsis.#{who}") << " " << join_chunks(chunks)
      end
      sentences << (done? ? youre_all_set : staggering_plan)
      @to_s = h.safe_join(sentences.compact, " ")
    end

    def user_regular_got
      round_next_half(for_user[0][:got])
    end

    def user_adjusted_quota
      round_next_half(for_user[0][:ttl])
    end

    def user_need
      round_next_half([for_user[0][:ttl] - for_user[0][:got], 0].max)
    end

    def user_full_community_hours
      for_user[1..-1].map { |bucket| [bucket[:bucket], round_next_half(bucket[:ttl])] }.to_h
    end

    private

    def youre_all_set
      h.tag.i(h.t("work.synopsis.done"))
    end

    def chunk_for_item(item)
      got = round_next_half(item[:got])
      ttl = round_next_half(item[:ttl])
      fraction_str = "#{got}/#{ttl}"
      fraction = item[:ok] ? h.tag(:i, fraction_str) : h.tag(:b, fraction_str)
      h.t("work.synopsis.chunk.#{item_count}_html",
          title: h.sanitize(item[:bucket].title), fraction: fraction)
    end

    def join_chunks(chunks)
      left = chunks.size > 2 ? h.safe_join(chunks[0..-2], ", ") << "," : chunks[0]
      right = chunks.size > 1 ? chunks[-1] : nil
      h.safe_join([left, right].compact, " and ") << "."
    end

    def item_count
      @item_count ||= for_user.size == 1 ? :single : :multiple
    end

    def staggering_plan
      return unless staggering.present? && staggering[:prev_limit].present?

      if staggering[:prev_limit].zero?
        h.t("work.synopsis.start_choosing", at_or_on_time: next_round_time)
      elsif staggering[:next_limit].nil?
        h.t("work.synopsis.round_limit_until",
            prev: staggering[:prev_limit], until_time: next_round_time(preposition: "until"))
      else # prev_limit and next_limit both present
        h.t("work.synopsis.round_limit_with_next",
            prev: staggering[:prev_limit], next: staggering[:next_limit], at_or_on_time: next_round_time)
      end
    end

    def next_round_time(preposition: nil)
      return if staggering[:next_starts_at].nil?

      preposition ||= staggering[:next_starts_at].today? ? "at" : "on"
      format = preposition == "on" ? :wday_no_year : :time_only
      time = h.l(staggering[:next_starts_at], format: format)
      h.t("common.time_with_preposition.#{preposition}", t: time).strip.gsub("  ", " ")
    end
  end
end
