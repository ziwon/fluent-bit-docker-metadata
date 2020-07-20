# fluent-bit-docker-metadata

Got stolen from [here](https://github.com/fluent/fluent-bit/issues/1499). And a few little things were added to parse JSON arrays and objects from Docker Swarm metadata with fluent-bit.

## Dockerfile
```
FROM fluent/fluent-bit:1.5-debug
COPY conf/* /fluent-bit/etc/
COPY scripts/* /fluent-bit/bin/
USER root
```

## Usage
```

[FILTER]
  Name              lua
  Match             docker.*
  script            /fluent-bit/bin/docker-metadata.lua
  call              encrich_with_docker_metadata
```
