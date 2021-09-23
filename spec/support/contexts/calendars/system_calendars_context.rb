# frozen_string_literal: true

shared_context "system calendars" do
  def expect_events(events, *attribs)
    expect(events.size).to eq(attribs.size)
    events.each_with_index do |event, i|
      expect_event(event, attribs[i])
    end
  end

  def expect_event(event, attribs)
    attribs = {kind: nil, note: nil, sponsor_id: nil, calendar_id: calendar.id}.merge(attribs)
    attribs.each do |k, v|
      if v.is_a?(Time)
        expect(event[k]).to eq_time(v)
      else
        expect(event[k]).to eq(v)
      end
    end
  end
end
