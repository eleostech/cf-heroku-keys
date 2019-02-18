# cf-heroku-keys

This [custom CloudFormation resource](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-custom-resources.html) allows AWS keys generated and managed by a CloudFormation stack to be automatically plugged into the config of an app running in Heroku. When the keys are created, updated, or deleted, this Lambda function calls the Heroku API to update or remove the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.

## Use by templates

To use this custom resource to update a particular Heroku app's keys, add the following to your stack's `Resources` section:

```yaml
Resources:
  SomeUser:
    Type: "AWS::IAM::User"
    Properties:
      Policies:
        # Define your inline IAM policies or roles

  SomeKeys:
    Type: "AWS::IAM::AccessKey"
    Properties:
      Serial: 1 # Increment to roll keys
      UserName: !Ref SomeUser

  HerokuKeys:
    Type: 'Custom::HerokuKeys'
    Properties:
      ServiceToken: arn:aws:lambda:us-east-1:571593187444:function:cf-heroku-keys-CFHerokuKeysFunction-1WXJ5DBEZYEY0
      AppName: your-heroku-app-name
      Key: !Ref SomeKeys
      Secret: !GetAtt SomeKeys.SecretAccessKey
```

## Hacking

### Requirements

* AWS CLI installed
* `pip install --user aws-sam-cli`
* On Debian: `sudo apt install python-backports.ssl-match-hostname python-backports.functools-lru-cache`
* [Ruby 2.5 installed](https://www.ruby-lang.org/en/documentation/installation/)
* [Docker installed](https://www.docker.com/community-edition)
* `cp sample.env.json env.json` and plug in your Heroku API key (which you can generate as in `Deployment` below, or steal from `~/.netrc` if you're in a rush.)

**Invoking function locally using a local sample payload**

```bash
sam local invoke --env-vars env.json --event event.json
```

## Packaging and deployment


## Deployment

Create an OAuth token over on Heroku. I recommend doing this as a programmatic account so it isn't interrupted if you lock or otherwise disable your own Heroku account.

```
heroku authorizations:create \
  --description "AWS CloudFormation cf-heroku-keys app" \
  --scope write-protected
```

Package the app:

```
sam package --template-file template.yaml \
  --s3-bucket eleos-build-archives \
  --output-template-file packaged.yaml
```

Use the CloudFormation web UI to deploy `packaged.yaml`, setting the `HerokuApiKey` parameter to be the UUID-like token (NOT the ID) issued by the `authorizations:create` step above.

The CloudFormation stack produces an Output that you should use as the `ServiceToken` when defining the custom resource in other stack templates.
