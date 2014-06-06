require 'spec_helper'

describe Raca::Util do

  describe "#url_encode" do
    it "escapes spaces" do
      expect(Raca::Util.url_encode("is this my file.jpg")).to eq("is%20this%20my%20file.jpg")
    end
    it "escapes question marks" do
      expect(Raca::Util.url_encode("file?.jpg")).to eq("file%3F.jpg")
    end
    it "escapes utf8 characters" do
      expect(Raca::Util.url_encode("ćafe.jpg")).to eq("%C4%87afe.jpg")
    end
    it "leaves forward slash unescaped" do
      expect(Raca::Util.url_encode("foo/bar.txt")).to eq("foo/bar.txt")
    end
  end
end
