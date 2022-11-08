module CurrentAttributesTestHelper
  def with_context(attr, value)
    begin
      Myapp::Current.send("#{attr}=", value)
      yield
    ensure
      Myapp::Current.reset_all
    end
  end
end