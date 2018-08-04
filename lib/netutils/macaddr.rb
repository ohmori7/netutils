class MACAddr
	NBBY = 8
	Length = 6

	def initialize(s)
		s = s.delete('-.:')
		raise if s =~ /[^0-9a-z]/i	# XXX EINVAL
		v = s.hex
		raise if v > 0xffffffffffff	# XXX ERANGE
		@addr = v
	end

	def [](n, len)
		raise if len > Length
		raise if Length % len != 0
		n *= len
		v = 0
		off = 0
		while off < len do
			v <<= NBBY
			v |= (@addr >> (NBBY * ((Length - 1) - n - off))) & 0xff
			off += 1
		end
		return v
	end
	private :[]

	def to_a(len = 1)
		a = Array.new
		max = Length / len
		for n in 0 .. max - 1 do
			a.push(self[n, len])
		end
		return a
	end
	private :to_a

	def to_s(sep = '.', step = 2)
		to_a(step).map { |v| sprintf('%0*x', step * 2, v) }.join(sep)
	end
end

# XXX: test
#x = MACAddr.new('aabb.ccdd.eeff')
#x.to_s		== 'aa:bb:cc:dd:ee:ff'
#x.to_s('.')	== 'aa.bb.cc.dd.ee.ff'
#x.to_s('.', 2)	== 'aabb.ccdd.eeff'
#x.to_s('.', 3)	== 'aabbcc.ddeeff'
#x.to_s('.', 6)	== 'aabbccddeeff'
#x.to_s('.', 4)	!= 'aabbccddeeff'
#x.to_s('.', 7)	!= 'aabbccddeeff'
