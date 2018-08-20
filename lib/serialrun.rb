#
# SerialRun classes to represent and run a job.
#

require "pony"
require "socket"
require "tempfile"

require "serialrun/version"

module SerialRun
  HOSTNAME = Socket.gethostname().freeze
  LINE = ("-" * 80).freeze

  #
  # Represent a job consisting of numbered steps.
  #
  class Job
    def initialize(name, dir, exec, database, db_host, db_name)
      @job_id = nil
      @argv = ARGV.dup
      @name = name
      @dir = dir
      @exec = exec
      @config = nil
      @run = false
      @quiet = false
      @email = nil
      @email_error = nil
      @database = database
      @db_host = db_host
      @db_name = db_name
      prepare_queries(database)
    end

    def prepare_queries(database)
      @insert_job = database.prepare(
        "INSERT INTO job
         (name, hostname, username, started, duration, status)
         VALUES
         (?, ?, ?, ?, NULL, ?)"
      )
      @update_job = database.prepare(
        "UPDATE job
         SET status = ?, duration = ?
         WHERE job_id = ?"
      )
    end

    def set_emails(email, error_email)
      @email = email
      @error_email = error_email
      @quiet = true if !email.nil? || !error_email.nil?
    end

    def config=(config)
      raise "FLAGS missing from config" unless config.const_defined?(:FLAGS)
      @config = config
    end

    def set_quiet
      @quiet = true
    end

    #
    # Show the steps that will run if run_steps is called.
    #
    def show_plan
      @steps = read_steps()
      print_status()
      puts("Showing plan only; add flag --run to really run job:")
      puts("  #{$PROGRAM_NAME} --run #{@argv.join(' ')}")
    end

    #
    # Run the steps in the given directory.
    #
    def run_steps
      @steps = read_steps()
      print_status() unless @quiet
      really_run_steps()
      return if @status == :ok && !@email_error.nil?
      if !@email.nil? || !@email_error.nil?
        send_status_email()
      else
        print_status()
        if @status == :ok
          puts("Job #{@name} completed successfully")
        else
          @failed_steps.each do |failed_step|
            puts("Job #{@name} failed at step #{failed_step.name}")
            puts("\n#{LINE}")
            puts(failed_step.log)
            puts(LINE)
          end
        end
      end
    end

    #
    # Do a live run of the given steps.
    #
    # Updates @job_id, @status, @duration, @failed_steps.
    #
    def really_run_steps
      create_job_in_database()

      done = false
      unless @quiet
        Thread.new do
          until done
            sleep(5)
            print_status()
          end
        end
      end

      t0 = Time.now()
      @steps.each do |step_group|
        @status, @failed_steps = run_step_group(step_group)
        break if @status != :ok
      end
      done = true
      @duration = Time.now() - t0
      set_job_status()
    end

    #
    # Place the job and steps into the database.
    #
    def create_job_in_database
      @insert_job.execute(@name, HOSTNAME, ENV["USER"],
                          Time.now.utc.strftime("%Y%m%d%H%M%S"), "running")
      @job_id = @database.last_id
      @steps.each do |step_group|
        step_group.each do |step|
          step.write_to_database(@database, @job_id)
        end
      end
    end

    #
    # Run a parallel group of steps of the job.
    #
    def run_step_group(step_group)
      running = 0
      step_group.each do |step|
        step.run()
        running += 1
      end
      trap("CLD") do
        begin
          # In some cases, Linux sends one SIGCLD even when multiple children exited (for example
          # when they exit at exactly the same time). Collect all children that have terminated by
          # using Process.wait2 with WNOHANG.
          while (child_wait = Process.wait2(-1, Process::WNOHANG))
            pid, process_status = child_wait
            step = step_group.find { |s| s.pid == pid }
            step.done(process_status)
            running -= 1
          end
        rescue Errno::ECHILD
          # Normal operation - indicates that wait2 had no more children to wait for.
          running = running
        end
      end
      while running != 0
        sleep(0.005)
        step_group.each do |step|
          step.duration = Time.now - step.started if step.status == :running
        end
      end
      trap("CLD", "DEFAULT")

      failed_steps = step_group.find_all { |s| s.status == :error }
      return failed_steps.empty? ? :ok : :error, failed_steps
    end

    #
    # Determine the job steps from the tool flags.
    #
    def read_steps
      raise "Expected @dir or @exec" unless @dir.nil? ^ @exec.nil?
      if @dir
        steps = read_steps_from_dir()
        raise "No steps found in #{@dir}" if steps == []
      else
        file, *flags = @exec.split(" ")
        basename = File.basename(file, ".*")
        if !@config.nil? && @config::FLAGS.key?(basename)
          flags += @config::FLAGS[basename].map { |y, z| "--#{y}=#{z}" }
        end
        step = Step.new(1, basename[0..2].to_i, file, basename, flags)
        steps = [[step]]
      end
      return steps
    end

    #
    # Read the steps available in the directory given in the options.
    #
    def read_steps_from_dir
      Dir.chdir(@dir)
      files = Dir.glob("[0-9][0-9][0-9]_*")
      files.sort!
      steps = []
      step_id = 1
      last_step_number = nil
      files.each do |filename|
        basename = File.basename(filename, ".*")
        flags = []
        if !@config.nil? && @config::FLAGS.key?(basename)
          flags = @config::FLAGS[basename].map { |y, z| "--#{y}=#{z}" }
        end
        step_number = basename[0..2].to_i
        step = Step.new(step_id, step_number, filename, basename, flags)
        if step_number == last_step_number
          steps.last.push(step)
        else
          steps.push([step])
        end
        step_id += 1
        last_step_number = step_number
      end
      return steps
    end

    #
    # Show the current status of the job and all steps.
    #
    def print_status
      printf("%s Running job %s (from %s)\n\n", Time.now.strftime("%Y-%m-%d %H:%M:%S"), @name,
             @dir.nil? ? @exec : @dir)
      print(status_string())
      print("\n")
    end

    #
    # Make the current status as a string.
    #
    def status_string
      s = ""
      @steps.each do |step_group|
        step_group.each do |step|
          marker = task_marker_string(step == step_group.first, step == step_group.last)
          s += sprintf("  %1s %-40s %-10s %8.2fs  %s\n", marker,
                       step.name, step.status.to_s.upcase,
                       step.duration.nil? ? 0 : step.duration, step.flags.join(" "))
        end
      end
      return s
    end

    #
    # Return a marker string indicating if the task is part of a parallel group,
    #
    MARKER_UNICODE = {
      [true, true]   => "",   # only task in group
      [true, false]  => "╒",  # first
      [false, false] => "╞",  # middle
      [false, true]  => "╘",  # last
    }.freeze
    MARKER_ASCII = {
      [true, true]   => "",   # only
      [true, false]  => "",   # first
      [false, false] => "=",  # middle
      [false, true]  => "=",  # last
    }.freeze
    def task_marker_string(is_first, is_last)
      if ENV.values_at("LC_ALL", "LC_CTYPE", "LANG").compact.first.include?("utf8")
        return MARKER_UNICODE[[is_first, is_last]]
      end
      return MARKER_ASCII[[is_first, is_last]]
    end

    #
    # Send an email showing the final job status.
    #
    def send_status_email
      subject = status_email_subject()
      body = status_email_body()

      Pony.mail(from: "run_job_steps on #{HOSTNAME} <#{ENV['USER']}@#{HOSTNAME}>",
                to: @email || @email_error,
                subject: subject,
                body: body,
                charset: "UTF-8")
    end

    def status_email_subject
      return sprintf("Job %s: %s (%.2fs)",
                     @status.to_s.upcase, @name, @duration)
    end

    def status_email_body
      body = ""
      if @status == :ok
        body += "Job #{@name} completed successfully\n\n"
      else
        @failed_steps.each do |failed_step|
          body += "Job #{@name} failed at step #{failed_step.name}\n\n"
        end
      end
      body += <<~EMAIL
        Hostname: #{HOSTNAME}
        Username: #{ENV['USER']}
        Status: #{@status.to_s.upcase}
        Duration: #{sprintf('%.3fs', @duration)}

        #{status_string()}
        #{LINE}
        Job id: #{@job_id}
      EMAIL
      if @db_name == "job_status_production"
        body += "Full logs: http://job-status.internal/job/#{job_id}\n"
      end
      body += <<~EMAIL
        Command: #{$PROGRAM_NAME} #{@argv.join(' ')}
        PWD: #{Dir.pwd}
        Database: #{@db_name} at #{@db_host}

      EMAIL
      @failed_steps.each do |failed_step|
        body += "#{LINE}\n#{failed_step.log[0, 100_000]}\n#{LINE}\n"
      end
      return body
    end

    #
    # Write the job status to the database.
    #
    def set_job_status
      @update_job.execute(@status, @duration, @job_id)
    end
  end

  #
  # Represent a step of the job.
  #
  class Step
    attr_reader :name, :flags, :status, :duration, :log, :pid, :started
    attr_writer :duration

    def initialize(id, number, file, name, flags)
      @id = id
      @number = number
      @file = file
      @name = name
      @flags = flags
      @status = :pending
      @started = nil
      @duration = nil
      @exit_status = nil
      @log = nil
    end

    def write_to_database(database, job_id)
      @job_id = job_id
      prepare_queries(database)
      @insert_step.execute(@job_id, @id, @number, @name, @status.to_s, @flags.join(" "))
    end

    def prepare_queries(database)
      @insert_step = database.prepare(
        "INSERT INTO step
         (job_id, step_id, number, name, status, flags)
         VALUES
         (?, ?, ?, ?, ?, ?)"
      )
      @update_start = database.prepare(
        "UPDATE step
         SET status = ?, started = ?
         WHERE job_id = ? AND step_id = ?"
      )
      @update_done = database.prepare(
        "UPDATE step
         SET status = ?, duration = ?, log = ?
         WHERE job_id = ? AND step_id = ?"
      )
      @database = database
    end

    #
    # Run a step by fork and exec.
    #
    def run
      extension = File.extname(@file)[1..-1]
      @temp_log_file = Tempfile.new("step")
      @status = :running
      @started = Time.now
      write_start_to_database()
      @pid = fork do
        $stdout.reopen(@temp_log_file)
        $stderr.reopen($stdout)
        if extension == "rb"
          exec("ruby", @file, *@flags)
        else
          exec("./#{@file}", *@flags)
        end
      end
    end

    def write_start_to_database
      @update_start.execute(@status.to_s, @started.utc.strftime("%Y%m%d%H%M%S"), @job_id, @id)
    end

    def done(process_status)
      @status = :done
      @exit_status = process_status.exitstatus
      @status = @exit_status.zero? ? :ok : :error
      @duration = Time.now - @started
      @temp_log_file.open()
      @log = @temp_log_file.read()
      @temp_log_file.close()
      write_done_to_database()
    end

    def write_done_to_database
      @update_done.execute(@status.to_s, @duration, @log, @job_id, @id)
    end
  end
end
