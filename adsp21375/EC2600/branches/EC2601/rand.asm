.section/dm seg_dmda;
.var seeds = 1234;
.var a_value = 1664525;
.var c_value = 32767;

_rand:
	i4 = seeds;
	r0 = dm(i4, m6);					// Read seed
	r4 = ASHIFT r0 by -16, r2 = dm(i4, m6);	// Compute seed>>16
	r0 = r0 * r2 (UUI), r2 = dm(i4, m7);// Compute mod(a*x)
	rts(DB), r0 = r0 + r2;
	r0 = r0 + r4;						// Compute mod(a*x + c)
	r0 = BCLR r0 by 31, dm(m7, i4) = r0;// save new seed, alway return positive

_rand.end:
