class FactoryGirlCreateWithoutTenantStrategy < FactoryGirl::Strategy::Create
  def result(evaluation)
    ActsAsTenant.without_tenant do
      super
    end
  end
end
