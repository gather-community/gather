# frozen_string_literal: true

require "rails_helper"

describe SearchDocumentRemoval, search: Calendars::Calendar do
  let!(:calendar) { create(:calendar, name: "Guest Room") }

  def indexed?(record)
    Calendars::Calendar.__elasticsearch__.client
      .exists(index: Calendars::Calendar.index_name, id: record.id)
  end

  it "removes the document when the record is destroyed" do
    expect(indexed?(calendar)).to be(true)
    calendar.destroy
    expect(indexed?(calendar)).to be(false)
  end

  # Deactivating removes the document, so destroying afterwards finds nothing to delete.
  # This used to raise and roll back the destroy, which stopped a community from being deleted.
  it "destroys a deactivated record whose document is already gone" do
    calendar.deactivate
    expect(indexed?(calendar)).to be(false)
    expect { calendar.destroy! }.not_to raise_error
    expect(Calendars::Calendar.exists?(calendar.id)).to be(false)
  end

  it "doesn't raise when a deactivated record is saved again" do
    calendar.deactivate
    expect { calendar.update!(name: "Guest Suite") }.not_to raise_error
    expect(indexed?(calendar)).to be(false)
  end
end
