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

