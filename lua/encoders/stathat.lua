-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--[=[
Extracts data from message fields in messages generated by a
and generates JSON suitable for use with the StatHat EZ 
API <https://www.stathat.com/manual/send>`_.

Config:

- metric_name (string, required)
    String to use as the `stat` name in StatHat. Supports
    interpolation of field values from the processed message, using
    `%{fieldname}`. Any `fieldname` values of "Type", "Payload", "Hostname",
    "Pid", "Logger", "Severity", or "EnvVersion" will be extracted from the
    the base message schema, any other values will be assumed to refer to a
    dynamic message field. Only the first value of the first instance of a
    dynamic message field can be used for series name interpolation. If the
    dynamic field doesn't exist, the uninterpolated value will be left in the
    series name. Note that it is not possible to interpolate either the
    "Timestamp" or the "Uuid" message fields into the series name, those
    values will be interpreted as referring to dynamic message fields.
    eg. "my-app %{source} %{title}" will use the metric name of %title% %source%.
- ezkey (string, required, defaults to "")
- value_field (string, optional, defaults to "value")
    The `fieldname` to use as the value for the metric in stathat. If the `value` 
    field is not present this encoder will set one as the value for counters: `1`.
    A value of `0` will be used for `gauges`.

*Example Heka Configuration*

.. code-block:: ini

    [stathat-encoder]
    type = "SandboxEncoder"
    filename = "lua_encoders/stathat.lua"
       [stathat-encoder.config]
       metric_name = "test-metric.%{title}.%{Hostname}"
       ezkey = "stathat-ez-api-key"
       value_field = "metric_value"

    [stathat]
    type = "HttpOutput"
    message_matcher = "Type == 'json'"
    address = "http://api.stathat.com/ez"
    encoder = "stathat-encoder"
      [stathat.headers]
      content-type = ["application/json"]

*Example Output*

.. code-block:: json
{"data":[{"t":1429932416,"stat":"test.counter","count":2}],"ezkey":"stathat-ez-api-key"}
--]=]

require "cjson"
require "string"
require "table"


local metric_name = read_config("metric_name")
local ezkey = read_config("ezkey")

local use_subs
if string.find(metric_name, "%%{[%w%p]-}") then
    use_subs = true
end

local base_fields_map = {
    Type = true,
    Payload = true,
    Hostname = true,
    Pid = true,
    Logger = true,
    Severity = true,
    EnvVersion = true
}

-- Used for interpolating message fields into series name.
local function sub_func(key)
    if base_fields_map[key] then
        return read_message(key)
    else
        local val = read_message("Fields["..key.."]")
        if val then
            return val end
        return "%{"..key.."}"
    end
end

function process_message()
    local ts = read_message("Timestamp") / 1e9
    if not ts then return -1 end
    local value = read_message("Fields[value]")

    local stat_type = read_message("Fields[type]")
    -- assume type is a counter unless gauge is specified
    -- if stat_type is null then just count the event
    if not stat_type or stat_type == "counter" then
        stat_type = "count"
        if not value then value = 1 end
    else
        stat_type = "value" -- aka "gauge"
        if not value then return -1 end
    end

    -- only process name if everything looks good
    local name = ""
    if use_subs then
        name = string.gsub(metric_name, "%%{([%w%p]-)}", sub_func)
    else
        name = metric_name
    end
    if not name or name == "" then return -1 end

    local output = {
        ezkey = ezkey,
        data = {{
            stat = name,
            [stat_type] = value,
            t = ts
        }}
    }

    inject_payload("json", "stathat", cjson.encode(output))
    return 0
end
