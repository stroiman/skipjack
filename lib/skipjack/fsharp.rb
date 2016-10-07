module Skipjack
  class FSharpCompiler
    attr_reader :target
    attr_writer :references
    attr_accessor :copy_references
    attr_accessor :resident

    def initialize *args
      @args = *args
      self.resident = true #default value
      yield self if block_given?
    end

    def target=(val)
      raise "Invalid target: #{val}" unless %w(exe winexe library module).include? val.to_s
      @target = val
    end

    def source_files=(val)
      @source_files = val
    end

    def source_files
      @source_files ||= []
    end

    def references
      @references ||= []
    end

    def create_file_task *args
      dependencies = source_files
      file_task = Rake::FileTask::define_task *args do |t|
        if t.application.windows?
          compiler = "fsc"
        else
          compiler = "fsharpc"
        end

        opts = []
        opts << "--out:#{t.name}"
        opts << "--target:#{target.to_s}"
        references.each { |r| opts << "--reference:#{r}" }
        if resident
          opts << "--resident"
        end

        dir = File.dirname(t.name)

        cmd = "#{compiler} #{opts.join(" ")} #{source_files.join(" ")}"
        raise "Error executing command" unless Kernel.system cmd
      end
      file_task.enhance dependencies
    end

    def add_reference_dependencies(task)
      if copy_references
        references.each do |r|
          dest = File.join(File.dirname(task.name), File.basename(r))
          reference_task = Rake::FileTask::define_task dest => [r] do |t|
            FileUtils.cp(t.prerequisites[0], t.name)
          end
          task.enhance [reference_task] unless dest == r
        end
      end
    end

    def create_task
      task = create_file_task *@args
      add_reference_dependencies(task)
      task
    end
  end
end

def fsc *args, &block
  c = Skipjack::FSharpCompiler.new *args, &block
  c.create_task
end
