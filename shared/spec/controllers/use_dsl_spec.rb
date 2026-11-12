require "permittable/rspec"

# README: Reusing fields (Permittable.fields and use); Output reshaping (transform: and finalize); Declaring a contract
RSpec.describe "use, finalize and rule order on anonymous controllers", since: "0.12.0",
  covers: %w[use-only-except use-override-duplicate use-refuses-finalize finalize-bare-runner pp-last-rule-wins finalize-violate] do
  def anon(&block)
    Class.new(BaseController) { permit_params(&block) }
  end

  describe "use only: / except:" do
    it "only: splices just the named fields" do
      klass = anon { use OrderScheduleFields, only: %i[delivery_on priority] }
      expect(klass).to permit_param(:delivery_on).for_action(:create)
      expect(klass).to permit_param(:priority).for_action(:create)
      expect(klass).not_to permit_param(:pickup_at).for_action(:create)
    end

    it "except: splices all but the named fields" do
      klass = anon { use OrderScheduleFields, except: %i[priority] }
      expect(klass).not_to permit_param(:priority).for_action(:create)
      expect(klass).to permit_param(:delivery_on).for_action(:create).required
    end

    it "refuses an only: typo at class load, and loads with a real name" do
      expect { anon { use OrderScheduleFields, only: %i[colour] } }.to raise_error(/colour/)
      expect { anon { use OrderScheduleFields, only: %i[priority] } }.not_to raise_error
    end
  end

  describe "redeclaring a spliced field" do
    it "fails at class load" do
      expect do
        anon do
          use ShippingAddressFields
          required :city, :string
        end
      end.to raise_error(/city/)
    end

    it "loads when the group's field is excluded, and the override applies" do
      klass = anon do
        use ShippingAddressFields, except: %i[city]
        required :city, :string, length: 1..5
      end
      expect(klass).to accept_params("line1" => "1 Le Loi", "city" => "Hue", "postcode" => "700000").for_action(:create)
      expect(klass).to reject_params("line1" => "1 Le Loi", "city" => "Hanoi!", "postcode" => "700000")
        .for_action(:create).with_violation("city", :length)
    end
  end

  describe "use refuses a Contract that declares finalize" do
    with_finalize = Permittable::Contract.define do
      required :a
      finalize { |p| p }
    end
    without = Permittable::Contract.define { required :a }

    it "raises at top level" do
      expect { anon { use with_finalize } }.to raise_error(/finalize/)
    end

    it "raises inside a nested block" do
      expect { anon { optional(:b) { use with_finalize } } }.to raise_error(/finalize/)
    end

    it "raises with only:" do
      expect { anon { use with_finalize, only: %i[a] } }.to raise_error(/finalize/)
    end

    it "loads a Contract without finalize" do
      expect { anon { use without } }.not_to raise_error
    end
  end

  describe "finalize" do
    it "runs on a bare runner with no controller state" do
      klass = anon do
        required :a
        finalize { |p| p.merge("on_controller" => is_a?(ActionController::Base), "has_params" => respond_to?(:params, true)) }
      end
      expect(klass).to accept_params("a" => "x").for_action(:show)
        .returning("a" => "x", "on_controller" => false, "has_params" => false)
    end

    it "violate! halts the block" do
      klass = anon do
        required :a
        finalize { |_p| violate!("a", :boom); raise "ran after violate!" }
      end
      expect(klass).to reject_params("a" => "x").for_action(:show).with_violation("a", :boom)
    end
  end

  describe "last matching rule wins" do
    it "a catch-all declared after a rule replaces it" do
      klass = Class.new(BaseController) do
        permit_params(:create) { required :a }
        permit_params { required :b }
      end
      expect(klass).to accept_params("b" => "1").for_action(:create)
      expect(klass).to reject_params("a" => "1").for_action(:create).with_violation("b", :missing)
    end

    it "a rule declared after a catch-all wins for its action only" do
      klass = Class.new(BaseController) do
        permit_params { required :b }
        permit_params(:create) { required :a }
      end
      expect(klass).to accept_params("a" => "1").for_action(:create)
      expect(klass).to accept_params("b" => "1").for_action(:show)
    end
  end
end
