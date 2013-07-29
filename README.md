# Capistrano::S3copy::Awscli

This is a revised implementation of the ideas in Bill Richie McMahon capistrano-s3-copy gem.
capistrano-s3-copy is a revised implementation of the ideas in Bill Kirtleys capistrano-s3 gem.

Part of my revising've simply to use the aws-cli.

aws-cli supports 

* Environment variables
* Config file
* IAM Role

*But this gem don't support Config file.*

This gem use Capistrano's own code to package the tarball, but instead of deploying it to each
machine, we deploy it to a configured S3 bucket (using aws-cli provided by the https://github.com/aws/aws-cli),
then deploy it from there to the known nodes from the capistrano script.

## Installation
    
    gem build capistrano-s3copy-awscli.gemspec
    gem install --local capistrano-s3copy-awscli-[version].gem

## Usage

In your deploy.rb file, we need to tell Capistrano to adopt our new strategy:

    set :deploy_via, :s3_copy

If you want to use Environment variables then we need to provide AWS account details to authorize the upload/download of our 
package to S3

    set :aws_access_key_id,     ENV['AWS_ACCESS_KEY_ID']
    set :aws_secret_access_key, ENV['AWS_SECRET_ACCESS_KEY']

Finally, we need to indicate which region and bucket to store the packages in:

    set :aws_region, 'mybucket-region'
    set :aws_releases_bucket, 'mybucket-deployments'

The package will be stored in S3 prefixed with a rails_env that was set in capistrano:

e.g.

    S3://mybucket-deployment/production/201307212007.tar.gz

If the deployment succeeds, another file is written to S3:

    S3://mybucket-deployment/production/aws_install.sh

The intention is that auto-scaled instances started after the deploy could download this well-known script
to an AMI, and executing it would bring down the latest tarball, and extract it in a manner similar to
someone running:

  cap deploy:setup
  cap deploy

Of course, everyone has tweaks that they make to the standard capistrano recipe. For this reason, the script
thats executed is generated from an ERB template.


    #!/bin/sh

    # Auto-scaling capistrano like deployment script Rails3 specific.

    set -x
    set -e

    echo "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}"
    echo "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}"

    if [ "${AWS_ACCESS_KEY_ID}" == "" ]; then
      echo "Expecting the environment variable AWS_ACCESS_KEY_ID to be set"
      exit 1
    fi
    
    if [ "${AWS_SECRET_ACCESS_KEY}" == "" ]; then
      echo "Expecting the environment variable AWS_SECRET_ACCESS_KEY to be set"
      exit 2
    fi

    AWS_RELEASES_BUCKET=<%= configuration[:aws_releases_bucket] %>
    AWS_REGION=<%= configuration[:aws_region] %>
    RAILS_ENV=<%= configuration[:rails_env] %>              # e.g. production
    DEPLOY_TO=<%= configuration[:deploy_to] %>              # e.g. /u/apps/myapp
    RELEASES_PATH=<%= configuration[:releases_path] %>      # e.g. /u/apps/myapp/releases
    RELEASE_PATH=<%= configuration[:release_path] %>        # e.g. /u/apps/myapp/releases/20130720210958
    SHARED_PATH=<%= configuration[:shared_path] %>          # e.g. /u/apps/myapp/shared
    CURRENT_PATH=<%= configuration[:current_path] %>        # e.g. /u/apps/myapp/current

    PACKAGE_NAME=<%= File.basename(filename) %>             # e.g. 20130720210958.tar.gz
    S3_PACKAGE_PATH=${RAILS_ENV}/${PACKAGE_NAME}            # e.g. production/20130720210958.tar.gz
    DOWNLOADED_PACKAGE_PATH=<%= remote_filename %>          # e.g. /tmp/20130720210958.tar.gz
    DECOMPRESS_CMD="<%= decompress(remote_filename).join(" ") %>" # e.g. tar xfz /tmp/20130720210958.tar.gz

    mkdir -p $DEPLOY_TO
    mkdir -p $RELEASES_PATH
    mkdir -p ${SHARED_PATH}
    mkdir -p ${SHARED_PATH}/system
    mkdir -p ${SHARED_PATH}/log
    mkdir -p ${SHARED_PATH}/pids

    touch ${SHARED_PATH}/log/${RAILS_ENV}.log
    chmod 0666 ${SHARED_PATH}/log/${RAILS_ENV}.log
    chmod -R g+w ${DEPLOY_TO}

    # AFTER: cap deploy:setup
    # Project specific shared directories
    # mkdir -p ${SHARED_PATH}/content
    # mkdir -p ${SHARED_PATH}/uploads

    # cap deploy:update_code
    s3cmd get ${AWS_RELEASES_BUCKET}:${S3_PACKAGE_PATH} ${DOWNLOADED_PACKAGE_PATH} 2>&1
    cd ${RELEASES_PATH} && ${DECOMPRESS_CMD} && rm ${DOWNLOADED_PACKAGE_PATH}

    # cap deploy:assets_symlink   (Rails 3.x specific)
    rm -rf ${RELEASE_PATH}/public/assets
    mkdir -p ${RELEASE_PATH}/public
    mkdir -p ${DEPLOY_TO}/shared/assets
    ln -s ${SHARED_PATH}/assets ${RELEASE_PATH}/public/assets

    # cap deploy:finalize_update
    chmod -R g+w ${RELEASE_PATH}
    rm -rf ${RELEASE_PATH}/log
    rm -rf ${RELEASE_PATH}/public/system
    rm -rf ${RELEASE_PATH}/tmp/pids
    mkdir -p ${RELEASE_PATH}/public
    mkdir -p ${RELEASE_PATH}/tmp
    ln -s ${SHARED_PATH}/system ${RELEASE_PATH}/public/system
    ln -s ${SHARED_PATH}/log ${RELEASE_PATH}/log
    ln -s ${SHARED_PATH}/pids ${RELEASE_PATH}/tmp/pids

    # AFTER: cap deploy:finalize_update
    cd ${RELEASE_PATH}
    bundle install --gemfile ${RELEASE_PATH}/Gemfile --path ${SHARED_PATH}/bundle --deployment --quiet --without development test

    # AFTER: cap deploy:update_code
    # cap deploy:assets:precompile
    cd ${RELEASE_PATH}
    bundle exec rake RAILS_ENV=${RAILS_ENV} RAILS_GROUPS=assets assets:precompile

    # Project specific shared symlinking
    #ln -nfs ${SHARED_PATH}/content ${RELEASE_PATH}/public/content
    #ln -nfs ${SHARED_PATH}/uploads ${RELEASE_PATH}/public/uploads

    # cap deploy:create_symlink
    rm -f ${CURRENT_PATH}
    ln -s ${RELEASE_PATH} ${CURRENT_PATH}

    # cap deploy:restart
    # touch ${CURRENT_PATH}/tmp/restart.txt

    # AFTER: cap deploy:restart
    # cd ${CURRENT_PATH};RAILS_ENV=${RAILS_ENV} script/delayed_job restart

An alternative ERB script can be configured via something like this:

    set :aws_install_script, File.read(File.join(File.dirname(__FILE__), "custom_aws_install.sh.erb")
