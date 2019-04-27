#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Function lap(timerRefNum, prefix)
	Variable &timerRefNum
	String prefix

	Variable elapsed

	if(timerRefNum == -1)
		resetTimer()
	endif
	elapsed = StopMSTimer(timerRefNum)
	Printf "%s: \t%9.3f ms\r", prefix, elapsed / 1e3
	timerRefNum = StartMSTimer
End

static Function resetTimer()
	Variable i, null

	for(i = 0; i < 10; i += 1)
		null = StopMSTimer(i)
	endfor
End

static Function diameter(n, m)
	Variable n, m

	return 0.144 / 3.1415 * (3 * (n^2 + n*m + m^2))^(0.5)
End

// for external calls
Function cnt_diameter(n, m)
	Variable n, m

	return diameter(n, m)
End

Function example()
	Variable mi, ma, avg, size
	Variable timerRefNum

	timerRefNum = StartMSTimer
	lap(timerRefNum, "offset")

	printf "The (6,5) SWNT has a diameter of %0.2f nm\r", diameter(6,5)
	lap(timerRefNum, "printf")

	Make/FREE/D/N=(500,500) matrix = diameter(p, q)
	lap(timerRefNum, "matrix")

	MatrixTranspose matrix
	lap(timerRefNum, "transp1")
	MatrixOP/FREE transposed = matrix^t
	lap(timerRefNum, "transp2")

	mi = WaveMin(matrix)
	ma = WaveMax(matrix)
	avg = mean(matrix)
	lap(timerRefNum, "stats1")

	WaveStats/Z/Q/M=1 matrix
	mi = V_min
	ma = V_max
	avg = V_avg
	lap(timerRefNum, "stats2")

	Duplicate/FREE matrix myFreeMatrix
	lap(timerRefNum, "dummy")
	Redimension/N=(1000, -1) myFreeMatrix
	lap(timerRefNum, "resize rows")

	Duplicate/FREE matrix myFreeMatrix
	lap(timerRefNum, "dummy")
	Redimension/N=(-1, 1000) myFreeMatrix
	lap(timerRefNum, "resize cols")

	MatrixMultiply matrix, myFreeMatrix
	lap(timerRefNum, "matrix mult1")
	MatrixOP/FREE result = matrix x myFreeMatrix
	lap(timerRefNum, "matrix mult2")

	MatrixFilter/N=9 gauss matrix
	lap(timerRefNum, "2D-Gauss")
	MatrixFilter/N=9 median matrix
	lap(timerRefNum, "2D-Median")
End
