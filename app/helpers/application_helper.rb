module ApplicationHelper
  def state(st)
    st.gsub("_", " ").capitalize
  end
  def dj_status(job_id, jobname=true)
    job = Delayed::Job.find(job_id) rescue nil
    return "finished" if !job
    s = ""
    s << job.handler.to_s.match(/:(\w+) /)[1] if jobname
    s << "- " if jobname
    if job.run_at == nil and job.failed_at == nil and job.last_error == nil
      s << "pending"
    elsif job.failed_at == nil and job.last_error == nil
      if job.locked_by == nil
        s << "awaiting node"
      else
        s << "running"
      end
    elsif job.last_error
      if job.failed_at
        s << "failed, gave up"
      else
        s << "failed, retrying"
      end
    end
    return s
  end
end
