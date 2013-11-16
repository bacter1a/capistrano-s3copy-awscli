require 'capistrano/recipes/deploy/strategy/copy'

module Capistrano
  module Deploy
    module Strategy
      class S3Copy < Copy

        def initialize(config={})
          super(config)

          aws_vars = []

          # add vars only if explicitly set, to avoid credentials exposure and allow IAM role
          ["aws_access_key_id", "aws_secret_access_key"].each do |var|
            value = fetch(var.to_sym, nil)
            aws_vars << "#{var.upcase.shellescape}=#{value.shellescape}" unless value.nil?
          end

          @awscli_env = aws_vars.join(" ") if aws_vars.length == 2

          @bucket_name = fetch(:aws_releases_bucket)
          raise Capistrano::Error, "Missing configuration[:aws_releases_bucket]" if @bucket_name.nil?
        end

        def check!
          super.check do |d|
            d.local.command("aws")
            d.remote.command("aws")
          end
        end

        # Distributes the file to the remote servers
        def distribute!
          s3_push_cmd = "#{awscli_env} aws s3 cp '#{filename}' '#{s3_filename}'".strip
          s3_pull_cmd = "#{awscli_env} aws s3 cp '#{s3_filename}' '#{remote_filename}'".strip
          s3_del_cmd  = "#{awscli_env} aws s3 rm '#{s3_filename}'".strip

          if dry_run
            logger.debug "DRY RUN: S3 push: #{s3_push_cmd}"
            logger.debug "DRY RUN: S3 pull: #{s3_pull_cmd}"
          else
            on_rollback { run_locally s3_del_cmd rescue nil }

            run_locally s3_push_cmd
            run s3_pull_cmd

            build_aws_install_script
            decompress_remote_file
          end
        end

        def build_aws_install_script
          require 'erb'

          template = fetch(:aws_install_script, File.join(File.dirname(__FILE__), "aws_install.sh.erb"))
          template = File.read(template) if File.file?(template)
          template = template.gsub("\r\n?", "\n")

          output = ERB.new(template).result(self.binding)

          install_script = File.join(copy_dir, "aws_install.sh")

          File.open(install_script, "w") do  |f|
            f.write(output)
            f.close()
          end

          set :s3_copy_aws_install_cmd, "#{awscli_env} aws s3 cp '#{install_script}' '#{s3_install_script}'".strip
        end

        def binding
          super
        end

        def deploy_env
          @deploy_env ||= fetch(:stage, :rails_env)
        end

        def awscli_env
          @awscli_env
        end

        def bucket_name
          @bucket_name
        end

        def s3_filename
          basename = File.basename(filename)
          @s3_filename ||= "s3://#{bucket_name}/#{deploy_env}/#{basename}"
        end

        def s3_install_script
          @s3_install_script ||= "s3://#{bucket_name}/#{deploy_env}/aws_install.sh"
        end

      end
    end
  end
end
