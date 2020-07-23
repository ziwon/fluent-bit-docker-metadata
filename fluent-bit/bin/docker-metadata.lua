-- https://github.com/fluent/fluent-bit/issues/1499 (@konstantin-kornienko)
-- A few little tweak was made to parse Docker Swarm metadata with fluent-bit (@ziwon)
DOCKER_VAR_DIR = '/var/lib/docker/containers/'
DOCKER_CONTAINER_CONFIG_FILE = '/config.v2.json'
CACHE_TTL_SEC = 300

-- Key-value pairs to get metadata.
DOCKER_CONTAINER_METADATA = {
  ['docker.container_name'] = '\"Name\":\"/?(.-)\"',
  ['docker.container_image'] = '\"Image\":\"/?(.-)\"',
  ['docker.container_started'] = '\"StartedAt\":\"/?(.-)\"',
  ['docker.hostname'] = '\"Hostname\":\"/?(.-)\"',
  ['docker.environment'] = '\"Env\":%[/?(.-)%]',
  ['docker.labels'] = '\"Labels\":%{/?(.-)%}',
  ['docker.state'] = '\"State\":%{/?(.-)%}',
}

-- Additional metadata for Swarm
DOCKER_CONTAINER_CHILD_METADATA = {
  ['docker.environment'] = '\"/?(.-)=/?(.-)\",',
  ['docker.labels'] = '\"/?(.-)\":\"/?(.-)\",',
  ['docker.state'] = '\"/?(.-)\":\"?/?(.-)\"?,',
}

cache = {}

-- Print table in a recursive way
-- https://gist.github.com/hashmal/874792
function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent+1)
    else
      print(formatting .. v)
    end
  end
end

-- Apply regular expression map to the given string
function apply_regex_map(data_tbl, reg_tbl, func, str)
  if str then
    for key, regex in pairs(reg_tbl) do
        data_tbl[key] = func(str, regex)
    end
  else
    for key, regex in pairs(reg_tbl) do
      local tbl = {}
      for k, v in func(data_tbl[key], regex) do
        tbl[k] = v
      end
      data_tbl[key] = tbl
    end
  end
  return data_tbl
end

-- Get container id from tag
function get_container_id_from_tag(tag)
  return tag:match'^docker?.([a-z0-9]+)$'
end

-- Gets metadata from config.v2.json file for container
function get_container_metadata_from_disk(container_id)
  local docker_config_file = DOCKER_VAR_DIR .. container_id .. DOCKER_CONTAINER_CONFIG_FILE
  fl = io.open(docker_config_file, 'r')
  if fl == nil then
    return nil
  end

  -- parse json file and create record for cache
  local data = { time = os.time() }
  local reg_match = string.match
  local reg_gmatch = string.gmatch
  for line in fl:lines() do
    data = apply_regex_map(
      data,
      DOCKER_CONTAINER_METADATA,
      reg_match,
      line
    )
    data = apply_regex_map(
      data,
      DOCKER_CONTAINER_CHILD_METADATA,
      reg_gmatch
    )
  end
  fl:close()

  if next(data) == nil then
    return nil
  else
    return data
  end
end

function encrich_with_docker_metadata(tag, timestamp, record)
  -- Get container id from tag
  container_id = get_container_id_from_tag(tag)

  if not container_id then
    return 0, 0, 0
  end

  -- Add container_id to record
  new_record = record
  new_record['docker.container_id'] = container_id

  -- Check if we have fresh cache record for container
  local cached_data = cache[container_id]
  if cached_data == nil or ( os.time() - cached_data['time'] > CACHE_TTL_SEC) then
    cached_data = get_container_metadata_from_disk(container_id)
    cache[container_id] = cached_data
    new_record['source'] = 'disk'
  else
    new_record['source'] = 'cache'
  end

  -- Metadata found in cache or got from disk, enrich record
  if cached_data then
    for key, regex in pairs(DOCKER_CONTAINER_METADATA) do
      new_record[key] = cached_data[key]
    end

    for key, regex in pairs(DOCKER_CONTAINER_CHILD_METADATA) do
      new_record[key] = cached_data[key]
    end
  end

  return 1, timestamp, new_record
end
