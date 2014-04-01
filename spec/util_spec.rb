require 'spec_helper'

describe Raca::Util do

  describe "#url_encode" do
    it "escapes spaces" do
      Raca::Util.url_encode("is this my file.jpg").should == "is%20this%20my%20file.jpg"
    end
    it "escapes question marks" do
      Raca::Util.url_encode("file?.jpg").should == "file%3F.jpg"
    end
    it "escapes utf8 characters" do
      Raca::Util.url_encode("ćafe.jpg").should == "%C4%87afe.jpg"
    end
    it "leaves forward slash unescaped" do
      Raca::Util.url_encode("foo/bar.txt").should == "foo/bar.txt"
    end
  end
end
