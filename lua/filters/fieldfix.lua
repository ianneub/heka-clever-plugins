-- From: https://github.com/hynd/heka-tsutils-plugins

-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--[[
Performs some basic mutations on message Fields - add if not present, override,
remove, rename and parse.  New messages will be emitted with a new Type.

The Parse function can be used to extract field data embedded in another field,
ie; in a StatsD bucket name.  See Config for more information.

Config:

- msg_type (string, optional, default "fieldfix")
    String to set as the new message Type (which will also have
    'heka.sandbox.' automatically and unavoidably prefixed)

- payload_keep (bool, default false)
    If true, maintain the original Payloads in the new messages.

- fields_if_missing (string, optional)
    Space delimited string of Fields to supplement (ie; add if they're not
    already present).  Field name and value should be delimited with a '='.

- fields_override (string, optional)
    Space delimited string of Fields to always ensure exists, overriding
    existing values if necessary.  Field name and value should be delimited
    with a '='.

- fields_remove (string, optional)
    Space delimited string of Fields to remove.  Only the field name is
    required.

- fields_rename (string, optional)
    Space delimited string of Fields to rename.  Old and new name should be
    delimited with a '='.

- fields_interpolate (string, optional)
    Space delimited string of Fields to add, and perform string-interpolation
    on - i.e. replace chunks of the form %{foo} with the value of the field foo.
    The new field name and custom values should be delimited with a '='.
    For example, if fields[foo] is 'hello' and fields[bar] is 'world', then the
    interpolation msg=%{foo}_%{bar} will result in fields[msg] as 'hello_world'.
    Note that the interpolation will only be done with the original field
    values, and not any that have been configured to get renamed or inserted.


  Note: that it's possibly to make any Field value in the above configuration a
  compound value by wrapping it in double quotes, i.e.
  fields_override = 'msg="hello world" cluster=wibble'

*Example Heka Configuration*

.. code-block:: ini

    [FieldFixFilter]
    type = "SandboxFilter"
    filename = "lua/filters/fieldfix.lua"
    preserve_data = false

    [FieldFixFilter.config]
    fields_if_missing = "source=myhost target=remotehost"
    fields_override = "cluster=wibble"
    fields_remove = "product"

--]]

require "string"

local msg_type        = read_config("msg_type") or "fieldfix"
local payload_keep    = read_config("payload_keep")
local add_str         = read_config("fields_if_missing") or ""
local override_str    = read_config("fields_override") or ""
local remove_str      = read_config("fields_remove") or ""
local rename_str      = read_config("fields_rename") or ""
local interpolate_str = read_config("fields_interpolate") or ""

-- convert a space-delimited string into a table of kv's,
-- either splitting each token on '=', or setting the value
-- to 'true'
local function create_table(str)
  local t = {}
  if str:len() > 0 then
    local fields = {}
    -- Expressions with quoted strings
    for f in str:gmatch("[%S]+=\"[^\"]+\"") do
      fields[#fields+1] = f
    end
    -- Expressions without quoted strings
    for f in str:gmatch("[%S]+=[^\"][%S]*") do
      fields[#fields+1] = f
    end
    for i=1,#fields do
      -- Also need to remove the quotes from the final value
      local k, v = fields[i]:match("([%S]+)=\"?([^\"]+)\"?")
      if k ~= nil then
        t[k] = v
      else
        t[f] = true
      end
    end
  end
  return t
end

-- build tables
local add         = create_table(add_str)
local remove      = create_table(remove_str)
local override    = create_table(override_str)
local rename      = create_table(rename_str)
local interpolate = create_table(interpolate_str)

-- Used for interpolating message fields into series name.
local function interpolate_func(key)
    local val = read_message("Fields["..key.."]")
    if val then
        return val
    end
    return "%{"..key.."}"
end

function process_message ()
    local message = {
      Timestamp  = read_message("Timestamp"),
      Type       = msg_type,
      EnvVersion = read_message("EnvVersion"),
      Fields     = {}
    }
    if payload_keep then message.Payload = read_message("Payload") end

    while true do
        local typ, name, value, representation, count = read_next_field()
        if not typ then break end

        -- Fields to remove
        if remove[name] then
        -- Fields to rename
        elseif rename[name] then
          message.Fields[rename[name]] = value
        -- Add untouched
        else
          message.Fields[name] = value
        end
    end

    -- Fields to supplement
    for k,v in pairs(add) do
      if not message.Fields[k] then
        message.Fields[k] = v
      end
    end

    -- Fields to override
    for k,v in pairs(override) do
      message.Fields[k] = v
    end

    -- Fields to interpolate
    for k,v in pairs(interpolate) do
        if string.find(v, "%%{[%w%p]-}") then
            interpolated = string.gsub(v, "%%{([%w%p]-)}", interpolate_func)
        end
        message.Fields[k] = interpolated
    end

    inject_message(message)
    return 0
end

function timer_event(ns)
end
