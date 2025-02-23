# frozen_string_literal: true

require "rails_helper"

describe Lens::Storage do
  let(:ver) { Lens::Storage::LENS_VERSION }
  let(:session) { {otherkey: 1} }

  describe "initial state" do
    it "is correct" do
      storage = Lens::Storage.new(session: session, community_id: 3, controller_path: "a/b",
                                  action_name: "c", persist: true)

      expect(session[:lenses]["V"]).to eq(ver)
      expect(session[:lenses]["T"]).to be > 10_000_000
      expect(session[:otherkey]).to eq(1)

      # These are lazy-built
      storage.global_store
      storage.action_store

      expect(session[:lenses]["V"]).to eq(ver)
      expect(session[:lenses]["T"]).to be > 10_000_000
      expect(session[:lenses]["3"]["G"]).to eq({})
      expect(session[:lenses]["3"]["a/b__c"]).to eq({})
      expect(session[:otherkey]).to eq(1)
    end
  end

  describe "reset param" do
    let(:session) { {lenses: {"V" => ver, "T" => 12_345_678, "3" => {"a/b__c" => {}}}, otherkey: 1} }

    it "clears old values" do
      Lens::Storage.new(session: session, community_id: 3, controller_path: "a/b", action_name: "c",
                        persist: true, reset: true)

      expect(session[:lenses].keys.sort).to eq(%w[3 T V])
      expect(session[:lenses]["V"]).to eq(ver)
      expect(session[:lenses]["T"]).to be > 10_000_000
      expect(session[:lenses]["3"]).to be_empty
      expect(session[:otherkey]).to eq(1)
    end
  end

  describe "reset on old version" do
    let(:session) { {lenses: {"V" => 2, "T" => 12_345_678, "3" => {"a/b__c" => {}}}, otherkey: 1} }

    it "clears old values" do
      Lens::Storage.new(session: session, community_id: 3, controller_path: "a/b", action_name: "c",
                        persist: true, reset: true)

      expect(session[:lenses].keys.sort).to eq(%w[3 T V])
      expect(session[:lenses]["V"]).to eq(ver)
      expect(session[:lenses]["T"]).to be > 10_000_000
      expect(session[:lenses]["3"]).to be_empty
      expect(session[:otherkey]).to eq(1)
    end
  end

  describe "expiry" do
    it "clears lenses on init if expiry time has elapsed" do
      _ = nil
      t2 = nil
      t3 = nil

      storage = Lens::Storage.new(session: session, community_id: 3, controller_path: "a/b",
                                  action_name: "c", persist: true)
      storage.global_store["z"] = "w"
      storage.action_store["x"] = "y"

      t1 = session[:lenses]["T"]
      expect(t1).to be > 10_000_000

      # Not cleared after one minute
      Timecop.freeze(Time.current + 1.minute) do
        Lens::Storage.new(session: session, community_id: 3, controller_path: "a/b", action_name: "c",
                          persist: true)
        expect(session[:lenses]["3"]["a/b__c"]["x"]).to eq("y")
        t2 = session[:lenses]["T"]
        expect(t2).to be > t1
      end

      # Cleared after expiry time
      Timecop.freeze(Time.current + Lens::Storage::EXPIRY_TIME + 2.minutes) do
        Lens::Storage.new(session: session, community_id: 3, controller_path: "a/b", action_name: "c",
                          persist: true)
        expect(session[:lenses].keys.sort).to eq(%w[3 T V])
        expect(session[:lenses]["3"]).to be_empty
        t3 = session[:lenses]["T"]
        expect(t3).to be > t2
      end
    end
  end
end
