Capistrano::Configuration.instance(false).load do

  after 'deploy', 's3_copy:store_aws_install_script_on_success'

  namespace :s3_copy do

    desc "Internal hook that updates the aws_install.sh script to latest if the deploy completed"
    task :store_aws_install_script_on_success do
      s3_push_cmd = fetch(:s3_copy_aws_install_cmd, nil)

      raise Capistrano::Error, "Task [s3_copy:store_aws_install_script_on_success] may not be called directly" if s3_push_cmd.nil?

      if dry_run
        logger.debug "S3 script upload #{s3_push_cmd}"
      else
        run_locally s3_push_cmd
      end
    end

  end

end
