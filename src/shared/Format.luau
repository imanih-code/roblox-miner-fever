local Format = {}

function Format.money(n: number): string
	n = math.floor(n)
	if n >= 1e12 then
		return string.format("$%.2fT", n / 1e12)
	elseif n >= 1e9 then
		return string.format("$%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("$%.2fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("$%.1fK", n / 1e3)
	end
	return "$" .. tostring(n)
end

return Format
