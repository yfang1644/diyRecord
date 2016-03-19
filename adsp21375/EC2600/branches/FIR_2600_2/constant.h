//constant definition

#define FS			64453.125	// sampling frequency
#define PI 			3.1415926535897932384626

#define	INS			2			// input channels
#define	OUTS		6			// output channels

#define	N_OCTAVE	256			// Num. of frequencies in F octave
#define	F_OCTAVE	(1.0305567101753188)	// f0 = 10Hzm fn+1 = fn*F_OCTAVE
#define	_1MS		247500		// cycles per ms(@247.5MHz)

#define	CUTLINE		177			// border between low/high frequency in octave

#define	CROSSN		181			// crossover low/high frequency, FIR
#define	FIR_L		120			// TAPs of low frequency phase FIR, tap=N*2+1
#define	FIR_H		30			// TAPs of high frequency phase FIR, tap=N*2+1

#define	HF_DELAY	(FIR_L*16-FIR_H-(CROSSN-1)/2)
