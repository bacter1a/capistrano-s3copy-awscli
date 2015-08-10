# Capistrano::S3copy::Awscli

This is a revised implementation of the ideas in Bill Richie McMahon [capistrano-s3-copy](http://github.com/richie/capistrano-s3-copy) gem.  

This gem provides Capistrano 2.x deployment strategy **Copy-via-S3** by [aws-cli](https://github.com/aws/aws-cli), with following features:

 * AWS environment variables support
 * aws-cli config file (local) / IAM Role (remote) support
 * auto-scale ready solution with deploy-like install script
 * transparent multistage support

**NB!** `aws-cli` must be install locally and remotely.

## Build

    gem build capistrano-s3copy-awscli.gemspec
    gem install --local capistrano-s3copy-awscli-[version].gem

## Usage

In your deploy.rb file, we need to tell Capistrano to adopt our new strategy:

    require 'capistrano-s3copy-awscli'

    set :deploy_via, :s3_copy

Finally, we need to indicate which bucket to store the packages in:

    set :aws_releases_bucket, 'mybucket-deployments'

The package will be stored in S3 prefixed with a multistage/rails_env that was set in capistrano:

    S3://mybucket-deployment/production/201307212007.tar.gz

If the deployment succeeds, another file is written to S3:

    S3://mybucket-deployment/production/aws_install.sh

Optionally, if you want to use Environment variables then it's required AWS account details to authorize the upload/download of our
package to S3:

    set :aws_access_key_id,     ENV['AWS_ACCESS_KEY_ID']
    set :aws_secret_access_key, ENV['AWS_SECRET_ACCESS_KEY']

The intention is that auto-scaled instances started after the deploy could download this well-known script
to an AMI, and executing it would bring down the latest tarball, and extract it in a manner similar to
someone running:

    cap deploy:setup
    cap deploy

or for multistage setup:

    cap {stage} deploy

Of course, everyone has tweaks that they make to the standard capistrano recipe. For this reason, the script
thats executed should be generated from an [aws_install.sh.erb](lib/capistrano/recipes/deploy/strategy/aws_install.sh.erb) template.

An alternative ERB script can be configured like this:

    set :aws_install_script, "deploy/templates/aws_install.sh.erb"

or reading file directly:

    set(:aws_install_script) { File.read("deploy/templates/aws_install.sh.erb") }

Callback triggers to add your own steps within deployments, eg. merge production configs:

    task :prepare do
        destination = fetch(:deploy_destination)
        raise Capistrano::Error, "Deploy destination is not defined" if destination.nil? || destination.empty?

        # do what ever you need 
    end

    on 'deploy:prepared', 'prepare'
