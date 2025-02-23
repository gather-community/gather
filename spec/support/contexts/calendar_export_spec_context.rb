# frozen_string_literal: true

shared_context "calendar exports" do
  let(:signature) { Calendars::IcalGenerator::UID_SIGNATURE }
  let(:community) { Defaults.community }
  let(:communityB) { create(:community) }
  let(:user) { create(:user, community: community) }

  private

  def expect_calendar_name(name)
    expect(ical_data).to match(/X-WR-CALNAME:#{name}/)
  end

  def expect_events(*events)
    blocks = ical_data.scan(/BEGIN:VEVENT.+?END:VEVENT/m)
    expect(blocks.size).to eq(events.size)
    events.each_with_index do |event, i|
      expect_event(event, blocks[i])
    end
  end

  def expect_event(event, block)
    event.each do |key, value|
      if value.nil?
        expect(block).not_to match(/^#{key.to_s.dasherize.upcase}:/)
      else
        key = key.to_s.dasherize.upcase if key.is_a?(Symbol)
        value = Regexp.quote(value) unless value.is_a?(Regexp)
        expect(block).to match(/^#{key}:#{value}/)
      end
    end
  end
end
