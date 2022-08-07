# SqlTestingFramework.com

### Setup

```
docker run -it --rm \
  --volume "$PWD/www":/www \
soodesune/node-18-vitejs
```

### Run the development server

```
docker run -it --rm \
  --publish 3000:5173 \
  --volume "$PWD/www":/www \
soodesune/node-18-vitejs dev
```

## Deploy

```
docker run --rm -i \
  --volume "$HOME"/Personal/.aws/sqltestingframework.com:/root/.aws \
  --volume "$PWD/www":/files \
  --workdir /files \
amazon/aws-cli s3 cp ./ s3://www.sqltestingframework.com --recursive \
  --exclude "*.DS_Store" \
  --exclude "package.json" \
  --exclude "yarn.lock" \
  --exclude "yarn-error.log" \
  --exclude "node_modules/*"
```

Make sure there's an AWS user with this policy attached:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*",
                "s3-object-lambda:*"
            ],
            "Resource": "arn:aws:s3:::www.sqltestingframekwork.com/*"
        }
    ]
}
```


Why not just use a well defined database?
Real data is messy, we often don't have control over how clean it is.  This is a framework for making assertions against the data the query results to make sure they pass the smell test.

## TODO
- [ ] Write break-out pages for "run tests"
