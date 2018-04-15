# frozen_string_literal: true

module Work
  # Builds the topline string for the shifts page.
  class ToplineDecorator < WorkDecorator
    delegate_all

    # Takes a summary data structure like and converts to nice string.
    # See spec for data structure examples.
    def to_s
      return @to_s if defined?(@to_s)
      return (@to_s = nil) if summary.nil?
      sentences = %i[self household].map do |who|
        next unless summary[who]
        chunks = summary[who].map { |i| chunk_for_item(i) }
        h.t("work.topline.#{who}") << " " << join_chunks(chunks)
      end
      sentences << (summary[:done] ? h.t("work.topline.done") : nil)
      @to_s = sentences.compact.join(" ").html_safe
    end

    private

    def chunk_for_item(item)
      got = round_next_half(item[:got])
      ttl = round_next_half(item[:ttl])
      fraction = h.content_tag(item[:ok] ? :i : :b, "#{got}/#{ttl}")
      h.t("work.topline.chunk.#{item_count}", title: h.sanitize(item[:bucket].title), fraction: fraction)
    end

    def join_chunks(chunks)
      left = chunks.size > 2 ? chunks[0..-2].join(", ") << "," : chunks[0]
      right = chunks.size > 1 ? chunks[-1] : nil
      [left, right].compact.join(" and ") << "."
    end

    def item_count
      @item_count ||= summary[:self].size == 1 ? :single : :multiple
    end
  end
end
