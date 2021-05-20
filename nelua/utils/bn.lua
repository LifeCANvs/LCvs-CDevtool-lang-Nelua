--[[
BN class

The BN (stands for Big Number) is used to represent either float or big integers.
It uses the lua-bint library to perform operations on large integers.
The compiler needs this class because Lua cannot work with integers large than 64 bits.
Large integers are required to work with `uint64`, `int128` and `uint128`,
to mix operation between different integers ranges at compile time,
and to do error checking on integer overflows.
]]

-- BN is actually a `bint` class created with 192bits and with some extensions.
local bn = require 'nelua.thirdparty.bint'(192)

-- Used to check if a table is a 'bn'.
bn._bn = true

-- Helper to convert a number composed of strings parts in any base to a big number.
local function from(base, expbase, int, frac, exp)
  local neg = false
  -- we need to read as positive, we can negate later
  if int:match('^%-') then
    neg = true
    int = int:sub(2)
  end
  -- handle inf and nan
  if int == 'inf' then
    return not neg and math.huge or -math.huge
  elseif int == 'nan' then
    return 0.0/0.0 -- always a nan in lua
  end
  -- parse the integral part
  local n = bn.zero()
  for i=1,#int do
    local d = tonumber(int:sub(i,i), base)
    n = (n * base) + d
  end
  -- parse the fractional part
  if frac then
    local fracnum = from(base, expbase, frac)
    local fracdiv = bn.ipow(base, #frac)
    n = n + fracnum / fracdiv
  end
  -- parse the exponential part
  if exp then
    n = n * bn.ipow(expbase, tonumber(exp))
  end
  -- negate if needed
  if neg then
    n = -n
  end
  return n
end

-- Converts a hexadecimal number composed of string parts to a big number.
function bn.fromhex(int, frac, exp)
  if frac and exp then -- hexadecimal float with fraction and exponent
    return tonumber('0x'..int..'.'..frac..'p'..exp)
  elseif frac then -- hexadecimal float with fraction
    return tonumber('0x'..int..'.'..frac)
  elseif exp then -- hexadecimal float  with exponent
    return tonumber('0x'..int..'p'..exp)
  elseif int == 'inf' then
    return math.huge
  elseif int == '-inf' then
    return -math.huge
  elseif int == 'nan' or int == '-nan' then
    return 0.0/0.0
  else -- hexadecimal integral
    return bn.frombase(int, 16)
  end
end

-- Converts a binary number composed of string parts to a big number.
function bn.frombin(int, frac, exp)
  return from(2, 2, int, frac, exp)
end

-- Converts a decimal number composed of string parts strings to a big number.
function bn.fromdec(int, frac, exp)
  if frac and exp then -- decimal float with fraction and exponent
    return tonumber(int..'.'..frac..'e'..exp)
  elseif frac then -- decimal float with fraction
    return tonumber(int..'.'..frac)
  elseif exp then -- decimal float with exponent
    return tonumber(int..'e'..exp)
  elseif int == 'inf' then
    return math.huge
  elseif int == '-inf' then
    return -math.huge
  elseif int == 'nan' or int == '-nan' then
    return 0.0/0.0
  else -- decimal integral
    return bn.frombase(int, 10)
  end
end

-- Split a number string into string parts.
function bn.splitdecsci(s)
  -- handle nans and infs
  if s == 'inf' or s == '-inf' or s == 'nan' or s == '-nan' then
    return s
  end
  -- split into string parts
  local int, frac, exp = s:match('^(-?%d+)[.]?(%d+)[eE]?([+-]?%d*)$')
  if not int then
    int, exp = s:match('^(-?%d+)[eE]?([+-]?%d*)$')
    assert(int)
  end
  if exp == '' then exp = nil end
  return int, frac, exp
end

-- Convert a number composed of string parts in a specific base to a big number.
function bn.from(base, int, frac, exp)
  if base == 'dec' then
    return bn.fromdec(int, frac, exp)
  elseif base == 'hex' then
    return bn.fromhex(int, frac, exp)
  elseif base == 'bin' then
    return bn.frombin(int, frac, exp)
  end
end

-- Convert an integral number to a string in hexadecimal base.
function bn.tohex(v, bits)
  if bits then -- wrap around
    v = v:bwrap(bits)
  end
  return bn.tobase(v, 16, true)
end

-- Convert an integral number to a string in binary base.
function bn.tobin(v, bits)
  if bits then -- wrap around
    v = v:bwrap(bits)
  end
  return bn.tobase(v, 2, true)
end

-- Convert an integral number to a string in decimal base.
function bn.todec(v)
  return bn.tobase(v, 10, false)
end

--[[
Convert to a string in decimal base considering fractional values,
possibly using scientific notation for float numbers, to have a shorter output.
]]
function bn.todecsci(v, maxdigits)
  if bn.isbint(v) then
    -- in case of bints we can just it as string
    return tostring(v)
  end
  -- force converting it to a number
  v = tonumber(v)
  local ty = math.type(v)
  if ty == 'integer' then
    -- in case of lua integers we can return it as string
    return tostring(v)
  elseif ty == 'float' then
    -- 64 bit floats can only be uniquely represented by 17 decimals digits
    maxdigits = maxdigits or 17
    -- try to use a small float representation if possible
    if maxdigits >= 16 then
      local s = string.format('%.15g', v)
      if tonumber(s) == v then
        return s
      end
      s = string.format('%.16g', v)
      if tonumber(s) == v then
        return s
      end
    end
    -- return the float represented in a string
    return string.format('%.'..maxdigits..'g', v)
  end
end

-- Check if the input is a NaN (not a number).
function bn.isnan(x)
  return x ~= x -- a nan is never equal to itself
end

-- Check if the input is infinite.
function bn.isinfinite(x)
  return math.type(x) == 'float' and math.abs(x) == math.huge
end

-- Convert a bn number to a lua integer/number without loss of precision.
function bn.compress(x)
  if bn.isbint(x) then
    if x <= math.maxinteger and x >= math.mininteger then
      return x:tointeger()
    end
    return x
  end
  return tonumber(x)
end

return bn
