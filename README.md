# fluent-bit-docker-metadata

Got stolen from [here](https://github.com/fluent/fluent-bit/issues/1499). And a few little things were added to parse JSON arrays and objects from Docker Swarm metadata for fluent-bit.

## Usage
```
[FILTER]
  Name              lua
  Match             docker.*
  script            /fluent-bit/bin/docker-metadata.lua
  call              encrich_with_docker_metadata
```
