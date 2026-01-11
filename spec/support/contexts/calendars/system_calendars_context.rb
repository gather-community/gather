# frozen_string_literal: true

shared_context "system calendars" do
  def expect_events(events, *attribs)
    expect(events.size).to eq(attribs.size)
    events.each_with_index do |event, i|
      expect_event(event, attribs[i])
    end
  end

  def expect_event(event, attribs)
    attribs = {kind: nil, sponsor_id: nil, calendar_id: calendar.id}.merge(attribs)
    attribs.each do |k, v|
      if v.is_a?(Time)
        expect(event.send(k)).to eq_time(v)
      else
        expect(event.send(k)).to eq(v)
      end
    end
  end

  def expect_eventlets(eventlets, *attribs)
    expect(eventlets.size).to eq(attribs.size)
    eventlets.each_with_index do |eventlet, i|
      expect_eventlet(eventlet, attribs[i])
    end
  end

  def expect_eventlet(eventlet, attribs)
    attribs = {calendar_id: calendar.id}.merge(attribs)
    attribs[:event] = {kind: nil, sponsor_id: nil}.merge(attribs[:event] || {})
    attribs.each do |k, v|
      p k
      if k == :event
        v.each do |ek, ev|
          expect(eventlet.event.send(ek)).to eq(ev)
        end
      elsif v.is_a?(Time)
        expect(eventlet.send(k)).to eq_time(v)
      else
        expect(eventlet.send(k)).to eq(v)
      end
    end
  end
end
