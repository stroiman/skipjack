module Skipjack
  class FSharpCompiler
    attr_reader :target
    attr_accessor :output_folder, :output_file

    def initialize *args
      @args = *args
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

    def create_task
      task = Rake::Task::define_task *@args 

      output_file_name = output_folder ? "#{output_folder}/#{output_file}" : output_file
      dependencies = source_files
      file_task = Rake::FileTask::define_task output_file_name => dependencies do |t|
        if t.application.windows?
          compiler = "fsc"
        else
          compiler = "fsharpc"
        end

        out = "--out:#{output_file_name}"
        src = source_files.join(" ")
        cmd = "#{compiler} #{out} --target:#{target.to_s} #{src}"
        raise "Error executing command" unless Kernel.system cmd
      end

      task.enhance [file_task]
    end
  end
end

def fsc *args, &block
  c = Skipjack::FSharpCompiler.new *args, &block
  c.create_task
end
