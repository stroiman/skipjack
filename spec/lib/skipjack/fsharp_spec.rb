require 'fakefs/spec_helpers'

describe 'fsharp' do
  include FakeFS::SpecHelpers

  before :each do |example|
    @app = Rake.application = Rake::Application.new

    # mock if we are running windows or not
    windows = example.metadata[:windows]
    windows = true if windows.nil?
    allow(@app).to receive("windows?").and_return windows

    allow(Kernel).to receive(:system).and_return true
  end

  context "when a task is not invoked" do
    it "does not call the system" do
      expect_no_system_call
      @task = fsc "dummy.exe"
    end
  end

  describe "command line args" do
    before :each do 
      expect_compiler_call do |opts|
        @opts = opts 
      end
    end

    let :options do
      task = fsc "dummy.exe" do |t|
        @setup.call(t) if @setup
      end
      task.invoke
      @opts
    end

    describe "called executable" do
      subject { options.executable }

      context "when running on windows", windows: true do
        it { should eq "fsc" }
      end

      context "when running on non-windows", windows: false do
        it { should eq "fsharpc" }
      end
    end

    describe "--reference: argument" do
      before do |ex|
        @setup = lambda do |t|
          t.references = ["ref1.dll", "ref2.dll"]
        end
      end

      subject { options.references }

      it { should eq ["ref1.dll", "ref2.dll"] }
    end

    describe "--resident" do
      before do |ex|
        @setup = lambda do |t|
          t.resident = ex.metadata[:resident] unless ex.metadata[:resident].nil?
        end
      end

      subject { options.resident }

      context "resident is not set" do
        it "defaults to true" do
          expect(subject).to eq true
        end
      end

      context "resident set to true", resident: true do
        it { should eq true }
      end

      context "resident set to false", resident: false do
        it { should eq false }
      end
    end

    describe "--target: argument" do
      before do |ex|
        @setup = lambda do |t|
          t.target = ex.metadata[:target]
        end
      end

      subject { options.target }

      context "when target = :library", target: :library do
        it { should eq "library" }
      end

      context "when target = :exe", target: :exe do
        it { should eq "exe" }
      end
    end

    describe "source files" do
      it "contains the passed sources" do
        sources = ["source1.fs", "source2.fs"]
        FileUtils.touch "source1.fs"
        FileUtils.touch "source2.fs"
        @setup = lambda do |t|
          t.source_files = sources
        end
        expect(options.source_files).to eq(sources)
      end
    end

    describe "output" do
      it "sets the output file" do
        task = fsc "f/p.exe" do |t|
          @setup.call(t) if @setup
        end
        task.invoke
        expect(@opts.out).to eq("f/p.exe")
      end
    end

    describe "build optimization" do
      context "build output is older than source files" do
        it "calls the compiler" do
          FileUtils.touch('./p.exe')
          FileUtils.touch('s.fs')
          task = fsc "p.exe" do |t|
            t.target = :exe
            t.source_files = ["s.fs"]
          end
          task.invoke
          expect(@opts).to_not be_nil
        end
      end

      context "build output is newer than source files" do
        it "does not call the compiler" do
          FileUtils.touch('s.fs')
          FileUtils.touch('./p.exe')
          task = fsc "p.exe" do |t|
            t.target = :exe
            t.source_files = ["s.fs"]
          end
          task.invoke
          expect(@opts).to be_nil
        end
      end

      it "does not copy the source file to the destination folder by default" do
          FileUtils.mkdir('input', 'output')
          FileUtils.touch('input/x.dll')
          task = fsc "output/p.exe" do |t|
            t.target = :exe
            t.add_reference 'input/x.dll'
          end
          task.invoke
          expect(File.file?('output/x.dll')).to be false
      end

      it "copies the source file to the destination folder" do
          FileUtils.mkdir('input', 'output')
          FileUtils.touch('input/x.dll')
          task = fsc "output/p.exe" do |t|
            t.target = :exe
            t.add_reference 'input/x.dll', copy_local: true
          end
          task.invoke
          expect(File.file?('output/x.dll')).to be true
      end

      it "doesnt copy if copy_local is false" do
          FileUtils.mkdir('output')
          FileUtils.touch('output/x.dll')
          task = fsc "output/p.exe" do |t|
            t.target = :exe
            t.add_reference 'input/x.dll', copy_local: false
          end
          task.invoke
          op = lambda { task.invoke }
          expect(op).to_not raise_error
      end
    end
  end

  describe "target type" do
    it "fails when using invalid target option" do
      op = lambda do
        task = fsc "p.exe" do |t|
          t.target = :invalid_option
        end
      end
      expect(op).to raise_error(/^Invalid target/)
    end
  end
end
