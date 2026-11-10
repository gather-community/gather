# frozen_string_literal: true

require "rails_helper"

describe Gather::CommittedTransaction do
  # Stands in for a listener: when a record commits, runs the block the example gave it. Uses an existing
  # model because a model class defined here would stay in ApplicationRecord.descendants and trip the
  # specs that check every model.
  let(:listener) do
    Class.new do
      def after_commit(record)
        record.on_commit.call if record.respond_to?(:on_commit)
      end
    end.new
  end
  let(:runs) { [] }

  around do |example|
    Wisper.subscribe(listener, scope: "Work::Period") { example.run }
  end

  def save_record(&on_commit)
    period = build(:work_period)
    period.define_singleton_method(:on_commit) { on_commit }
    period.save!
  end

  def once(key)
    described_class.once(key) { runs << key }
  end

  it "runs a block once per key across the callbacks of one transaction" do
    ActiveRecord::Base.transaction do
      3.times { save_record { once(:a) } }
      save_record { once(:b) }
    end
    expect(runs).to eq(%i[a b])
  end

  it "runs the block again for a later transaction" do
    2.times { save_record { once(:a) } }
    expect(runs).to eq(%i[a a])
  end

  it "keeps the outer transaction's keys when a callback commits a transaction of its own" do
    ActiveRecord::Base.transaction do
      save_record do
        once(:a)
        # This commits its own transaction, whose callbacks get a fresh set of keys.
        save_record { once(:a) }
      end
      # Back in the outer transaction's callbacks, where :a already ran.
      save_record { once(:a) }
    end
    expect(runs).to eq(%i[a a])
  end

  it "runs the block every time outside after_commit callbacks, including after a rollback" do
    ActiveRecord::Base.transaction do
      save_record { once(:a) }
      raise ActiveRecord::Rollback
    end
    expect(runs).to be_empty

    2.times { once(:a) }
    expect(runs).to eq(%i[a a])
  end

  # The test transaction turns every transaction above into a savepoint. Production has real ones.
  context "without the test transaction", clean_with_transaction: false do
    it "runs a block once per key across the callbacks of one transaction" do
      ActiveRecord::Base.transaction do
        3.times { save_record { once(:a) } }
      end
      save_record { once(:a) }
      expect(runs).to eq(%i[a a])
    end
  end
end
