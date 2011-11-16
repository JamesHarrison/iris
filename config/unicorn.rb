worker_processes 4
preload_app true
timeout 180
stderr_path "log/unicorn.log"
stdout_path "log/unicorn.log"

after_fork do |server, worker|
  ActiveRecord::Base.establish_connection
  begin
    uid, gid = Process.euid, Process.egid
    user, group = 'www-data', 'www-data'
    target_uid = Etc.getpwnam(user).uid
    target_gid = Etc.getgrnam(group).gid
    worker.tmp.chown(target_uid, target_gid)
    if uid != target_uid || gid != target_gid
      Process.initgroups(user, target_gid)
      Process::GID.change_privilege(target_gid)
      Process::UID.change_privilege(target_uid)
    end
  rescue => e
    if RAILS_ENV == 'development'
      STDERR.puts "couldn't change user, oh well"
    else
      raise e
    end
  end
end

before_fork do |server, worker|
  ActiveRecord::Base.connection.disconnect!
  old_pid = Rails.root + '/tmp/pids/unicorn.pid.oldbin'
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end
end

