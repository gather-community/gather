# frozen_string_literal: true

module Work
  # Builds the synopsis string for the shifts page.
  class SynopsisDecorator < WorkDecorator
    delegate_all

    # Takes a summary data structure and converts to nice string.
    # See spec for data structure examples.
    def to_s
      return @to_s if defined?(@to_s)
      return (@to_s = nil) if data.nil?
      sentences = %i[self household].map do |who|
        next unless data[who]
        chunks = data[who].map { |i| chunk_for_item(i) }
        safe_str << h.t("work.synopsis.#{who}") << " " << join_chunks(chunks)
      end
      sentences << (data[:done] ? h.content_tag(:i, h.t("work.synopsis.done")) : nil)
      @to_s = h.safe_join(sentences.compact, " ")
    end

    private

    def chunk_for_item(item)
      got = round_next_half(item[:got])
      ttl = round_next_half(item[:ttl])
      fraction = h.content_tag(item[:ok] ? :i : :b, "#{got}/#{ttl}")
      h.t("work.synopsis.chunk.#{item_count}_html",
        title: h.sanitize(item[:bucket].title), fraction: fraction)
    end

    def join_chunks(chunks)
      left = chunks.size > 2 ? h.safe_join(chunks[0..-2], ", ") << "," : chunks[0]
      right = chunks.size > 1 ? chunks[-1] : nil
      h.safe_join([left, right].compact, " and ") << "."
    end

    def item_count
      @item_count ||= data[:self].size == 1 ? :single : :multiple
    end
  end
end
