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


Why not just use a well defined database?
Real data is messy, we often don't have control over how clean it is.  This is a framework for making assertions against the data the query results to make sure they pass the smell test.

## TODO
- Write break-out pages for "write tests"
- Write break-out pages for "run tests"
