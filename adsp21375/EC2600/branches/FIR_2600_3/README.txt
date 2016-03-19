2015-06-02
	线性相位系统(LOW PASS & HIGH PASS)
	version 0.1
	使用说明

	信号通道：

          INPUT0 --+-->------ FIR0 ------> OUTPUT_A
                   |
                   +-->------ FIR2 ------> OUTPUT_C
	    		   |
                   +---------------------> OUTPUT_E

          INPUT1 --+-->------ FIR1 ------> OUTPUT_B
                   |
                   +-->------ FIR3 ------> OUTPUT_D
	    		   |
                   +---------------------> OUTPUT_F
	
		FIR 相位系统 Phase_system0 和 Phase_system1 513 阶。
		Delay0 和 Delay1 也是 401 阶FIR，200 点延迟，作为测试参考。

		上电后从 FLASH 读取 4 个通道有效相位数据，0 分区数据作为 FIR 0
		的幅度响应，1分区数据作为 FIR 1 的幅度响应...。如 FLASH 数据无效，
		则使用程序默认参数。程序默认参数定义在 initialamp.h 文件。

	串口控制命令：
		串口设置：19200bps，8bit，N-parity, 1 stop bit

        (01hello             8字节,用于测试
        (01bye               6字节,用于测试

        (01PCCA0A1A2......     6+256×2 字节
        功能：上传幅频响应数据。CC为通道号，00--0通道，01--1通道。
        A0、A1、A2...用于幅度设置，dB单位。0.5dB一格。
		level = -90 + 0.5*val(dB), val=181 为0dB
        A0、A1、A2...为 val 的 16进制形式，无符号，字母大写。
		(仿照 EC200 的增益参数)


		(01LFFCC            8字节, 从FLASH第 FF 分区读入数据作为 CC 通道的响应。
		(01SFF              6字节, 把最后一次改变的幅度响应存入FLASH FF 分区。

		FF 编号可以从 00 到 50，是指用于存放相位数据的分区编号，不是真正的
		FLASH 物理分区号。

		(01Wwd				6字节，窗函数设置。wd 窗函数编号：
		      00   rectangle,
			  01   bartlett,
			  02   hanning,
			  03   hamming,
			  04   blackman,
			  05   kaiser


	算法评估：

	    系统主频设置247.5MHz，采样率64453.125Hz，每两次采样间隔内时钟周期数
		    N= 247.5MHz/64453.125Hz = 3840
		滤波计算量：513阶，4通道，每个点处理 1 周期(循环缓冲)，
	        (513+10)x4=2100

