local Json = {}

local function decode_error(input, index, message)
    local context_start = math.max(1, index - 20)
    local context_end = math.min(#input, index + 20)
    local context = input:sub(context_start, context_end)
    error(string.format("JSON decode error at %d: %s near '%s'", index, message, context))
end

local function skip_whitespace(input, index)
    local length = #input
    while index <= length do
        local c = input:sub(index, index)
        if c ~= " " and c ~= "\n" and c ~= "\r" and c ~= "\t" then
            break
        end
        index = index + 1
    end
    return index
end

local function parse_string(input, index)
    index = index + 1
    local chunks = {}
    local length = #input

    while index <= length do
        local c = input:sub(index, index)
        if c == "\"" then
            return table.concat(chunks), index + 1
        end
        if c == "\\" then
            local esc = input:sub(index + 1, index + 1)
            if esc == "" then
                decode_error(input, index, "unterminated escape sequence")
            end
            if esc == "\"" or esc == "\\" or esc == "/" then
                chunks[#chunks + 1] = esc
                index = index + 2
            elseif esc == "b" then
                chunks[#chunks + 1] = "\b"
                index = index + 2
            elseif esc == "f" then
                chunks[#chunks + 1] = "\f"
                index = index + 2
            elseif esc == "n" then
                chunks[#chunks + 1] = "\n"
                index = index + 2
            elseif esc == "r" then
                chunks[#chunks + 1] = "\r"
                index = index + 2
            elseif esc == "t" then
                chunks[#chunks + 1] = "\t"
                index = index + 2
            elseif esc == "u" then
                local hex = input:sub(index + 2, index + 5)
                if #hex ~= 4 or not hex:match("^[0-9a-fA-F]+$") then
                    decode_error(input, index, "invalid unicode escape")
                end
                local codepoint = tonumber(hex, 16)
                if codepoint <= 0x7F then
                    chunks[#chunks + 1] = string.char(codepoint)
                elseif codepoint <= 0x7FF then
                    local b1 = 0xC0 + math.floor(codepoint / 0x40)
                    local b2 = 0x80 + (codepoint % 0x40)
                    chunks[#chunks + 1] = string.char(b1, b2)
                else
                    local b1 = 0xE0 + math.floor(codepoint / 0x1000)
                    local b2 = 0x80 + (math.floor(codepoint / 0x40) % 0x40)
                    local b3 = 0x80 + (codepoint % 0x40)
                    chunks[#chunks + 1] = string.char(b1, b2, b3)
                end
                index = index + 6
            else
                decode_error(input, index, "unsupported escape '\\" .. esc .. "'")
            end
        else
            chunks[#chunks + 1] = c
            index = index + 1
        end
    end

    decode_error(input, index, "unterminated string")
end

local function parse_number(input, index)
    local number = input:match("^-?%d+%.?%d*[eE]?[+-]?%d*", index)
    if not number or #number == 0 then
        decode_error(input, index, "invalid number")
    end

    local last = number:sub(-1)
    if last == "e" or last == "E" or last == "+" or last == "-" or last == "." then
        decode_error(input, index, "invalid number format")
    end

    local parsed = tonumber(number)
    if parsed == nil then
        decode_error(input, index, "cannot convert number")
    end

    return parsed, index + #number
end

local parse_value

local function parse_array(input, index)
    local result = {}
    index = index + 1
    index = skip_whitespace(input, index)
    if input:sub(index, index) == "]" then
        return result, index + 1
    end

    while true do
        local value
        value, index = parse_value(input, index)
        result[#result + 1] = value
        index = skip_whitespace(input, index)
        local c = input:sub(index, index)
        if c == "]" then
            return result, index + 1
        end
        if c ~= "," then
            decode_error(input, index, "expected ',' or ']' in array")
        end
        index = skip_whitespace(input, index + 1)
    end
end

local function parse_object(input, index)
    local result = {}
    index = index + 1
    index = skip_whitespace(input, index)
    if input:sub(index, index) == "}" then
        return result, index + 1
    end

    while true do
        if input:sub(index, index) ~= "\"" then
            decode_error(input, index, "expected string key")
        end
        local key
        key, index = parse_string(input, index)
        index = skip_whitespace(input, index)
        if input:sub(index, index) ~= ":" then
            decode_error(input, index, "expected ':' after key")
        end
        index = skip_whitespace(input, index + 1)
        local value
        value, index = parse_value(input, index)
        result[key] = value
        index = skip_whitespace(input, index)
        local c = input:sub(index, index)
        if c == "}" then
            return result, index + 1
        end
        if c ~= "," then
            decode_error(input, index, "expected ',' or '}' in object")
        end
        index = skip_whitespace(input, index + 1)
    end
end

parse_value = function(input, index)
    index = skip_whitespace(input, index)
    local c = input:sub(index, index)
    if c == "\"" then
        return parse_string(input, index)
    end
    if c == "{" then
        return parse_object(input, index)
    end
    if c == "[" then
        return parse_array(input, index)
    end
    if c == "-" or c:match("%d") then
        return parse_number(input, index)
    end
    if input:sub(index, index + 3) == "true" then
        return true, index + 4
    end
    if input:sub(index, index + 4) == "false" then
        return false, index + 5
    end
    if input:sub(index, index + 3) == "null" then
        return nil, index + 4
    end

    decode_error(input, index, "unexpected token")
end

function Json.decode(input)
    if type(input) ~= "string" then
        error("Json.decode expects a string")
    end
    local value, index = parse_value(input, 1)
    index = skip_whitespace(input, index)
    if index <= #input then
        decode_error(input, index, "trailing characters")
    end
    return value
end

return Json
