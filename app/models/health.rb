class Health
  # things to check: delayed_job, background crons, database, ECHO, CMR, URS, Opensearch, browse-scaler

  def initialize
    @ok = true
  end

  def edsc_status
    { ok?: @ok }
  end

  def delayed_job_status
    # check if there are any jobs that hadn't been run after 10 minutes passed.
    queued_jobs = DelayedJob.where('created_at < ? AND run_at IS NULL', 10.minutes.ago)
    if queued_jobs.size > 0
      @ok = false
      return { ok?: false, error: "Last job (job id: #{job.id}) failed to start 10 minutes after retrieval is created." }
    end

    # Further check failed_at and last_error
    failed_jobs = DelayedJob.where('last_error IS NOT NULL AND created_at > ?', 1.hour.ago)
    if failed_jobs.size > 0
      total_jobs = DelayedJob.where('created_at > ?', 1.hour.ago)
      @ok = false
      return { ok?: false, error: "There are #{failed_jobs.size} out of #{total_jobs.size} failed jobs in the past hour." }
    end

    { ok?: true }
  end

  def data_load_tags_status
    check_cron_job('data:load:tags', 1.hour)
  end

  def data_load_echo10_status
    check_cron_job('data:load:echo10', 1.hour)
  end

  def data_load_granules_status
    check_cron_job('data:load:granules', 1.hour)
  end

  def colormap_load_status
    check_cron_job('colormaps:load', 1.day)
  end

  def echo_status(echo_client)
    # check ECHO-REST availability
    res = echo_client.get_echo_availability
    ok?(res, res.body.present? && res.body['availability'] && res.body['availability'].downcase == 'available')
  end

  def cmr_status(echo_client)
    # copied from eed_utility_scripts
    res = echo_client.get_cmr_availability
    json = res.body.to_json
    ok?(res, json.present? && json.include?('"ok?":true') && !json.include?('false'))
  end

  def cmr_search_status(echo_client)
    # copied from eed_utility_scripts
    res = echo_client.get_cmr_search_availability
    json = res.body
    ok?(res, json.present? && json['feed'] && json['feed']['entry'] && json['feed']['entry'].size > 1)
  end

  def opensearch_status(cmr_client)
    # check home page only
    ok? cmr_client.get_opensearch_availability
  end

  def browse_scaler_status(echo_client)
    # a 500 error will be returned if either hdf2jpeg or image_magick is DOWN
    res = echo_client.get_browse_scaler_availability
    ok?(res, res.body.present? && !res.body.downcase.include?('down'))
  end

  def urs_status(echo_client)
    res = echo_client.get_urs_availability
    (res.respond_to? :success?) ? (ok? res) : res
  end

  def ous_status(ous_client)
    res = ous_client.get_ous_availability
    (res.respond_to? :success?) ? ok?(res, res.body.present? && res.body.all? { |_k, v| v['ok?'] }) : res
  end

  private

  def check_cron_job(task_name, interval)
    tasks = CronJobHistory.where(task_name: task_name).where(last_run: (Time.now - 3 * interval)..Time.now)

    if tasks.size == 0
      @ok = false
      return {ok?: false, error: "Cron job '#{task_name}' hasn't been run in the past #{(3 * interval).to_i / 3600.0} hours."}
    end

    task_status(interval, tasks.last, task_name)
  end

  def task_status(interval, task, task_name)
    if task.status == 'succeeded'
      if task.last_run < Time.now - interval && task.last_run > Time.now - 3 * interval
        log_text = "Suspend cron job checks for #{interval.to_i / 3600.0} hours after a new deployment. Last task execution was #{task.status} at #{task.last_run}"
        Rails.logger.info "Health pending: #{log_text} on host #{task.host}."
        return { ok?: true, info: log_text }
      elsif task.last_run < Time.now - 3 * interval
        @ok = false
        log_text = "Cron job '#{task_name}' hasn't been run since #{task.last_run}"
        Rails.logger.info "Health failure: #{log_text} on host #{task.host}."
        return { ok?: false, error: log_text }
      else
        return { ok?: true }
      end
    elsif task.status == 'running'
      log_text = "Cron job #{task_name} is still running."
      Rails.logger.info "Health pending: #{log_text} on host #{task.host}"
      return { ok?: true, info: log_text }
    else
      @ok = false
      log_text = "Cron job '#{task_name}' failed in last run at #{task.last_run} with message '#{task.message}'"
      Rails.logger.info "Health failure: #{log_text} on host #{task.host}."
      { ok?: false, error: log_text }
    end
  end

  def ok?(response, condition = nil)
    if response.success?
      if condition.nil?
        { ok?: true }
      else
        condition ? { ok?: true } : (@ok = false; { ok?: false, error: response.body.to_json, status: response.status })
      end
    else
      @ok = false
      { ok?: false, status: response.status }
    end
  end
end
