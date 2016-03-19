2015-05-09
	r52 修正 crossover butterworth5 参数设置错误
	恢复整数延迟，确定滤波器直通参数
2014-05-07
	MLS序列 32bit不好，用31bit，初值有意义
2014-04-29
	随机序列使用MLS,不使用饱和计算(clr MODE1 ALUSAT)待测试
	expf()增加2行，简化 pow(10, x)计算功能
2014-04-27
	静音标记 0/非0 导致gain 计算错误
	明确为 0/1 (initParameters.asm)
	循环跳出 jump() (LA) 增加 nop 指令，保证可靠性
	主程序 bit set MODE1 ALUSAT, Random 函数需要 bit clr MODE1 ALUSAT
	化简 outputProcessing 和 inputProcessing CLIPing
	优化 CCALL，将前一条指令 ";"改成 ","(并行)
2014-04-26
	根据talkthru修改 main.asm 中 MODE1、MASK设置，白噪声输出正常
2014-04-23
	增加信号源(noise & sine)
	随机函数
	uart1.asm 增加 (ID$001--006
	信号源选择：0--模拟输入，1--pinknoise, 2--sine wave
2014-04-19
	线性内插在高频时幅度抖动, 改用二次内插
	设二次抛物线关系式：y = f(x)，要计算在x = x0点的函数。

	已知f(x1)、f(x2）和f(x3)，其中x1 < x2 < x3, x1 < x0 < x3
	则在x0点的函数值：
    f(x0)=   f(x1)*(x2-x0)*(x3-x0)/((x3-x1)*(x2-x1)) +
             f(x2)*(x1-x0)*(x3-x0)/((x3-x2)*(x1-x2)) +
             f(x3)*(x2-x0)*(x1-x0)/((x1-x3)*(x2-x3))


2014-04-09
	将延迟单位用浮点表示，内插法提高延迟精度到1us(非客户要求)

2014-01-17
	客户反映连续改变HPF,LPF会有噪音。
	增加一组参数 _inp_coeffs0, _outp_coeffs0, 作为原有参数的备份。
	更新后一次copy, 并保持滤波器缓冲数据不变。
	crossOver参数计算中HPF截止频率index为0时设为18.65Hz.

2013-12-20
	增加 _inDelay, _outDelay 调整参数，人工修正延迟错误
	相关文件：buffers1.asm, initParameters.asm

2013-12-05
	修改 processing1.asm 定点<->浮点转换定标指数 23->31
	原代码会导致溢出错误，输出增益过大，因符号错误导致波形错误
	改变 MODE1/MMASK 预置值 ALUSAT (ALU saturation), 此项可能不会有大作用

2013-02-01
	bessel crossover 滤波器频率计算错误。按 bessel 多项式归一化得到的
	特征频率点不是-3dB。频率参数需要有一个 scale factor
	 order     factot
		2   1.36165412871613
		3   1.75567236868121
		4   2.11391767490422
		5   2.42741070215263
		6   2.70339506120292
		7   2.95172214703872
		8   3.17961723751065
		9   3.39169313891166
		10  3.59098059456916
	用 s*factor 替代 s，再变换到数字域。简单地说就是将极点除以factor作为新
	的极点。
2012-12-22
	用户反映，21065的配置在21375上无输出。原因:_compGain参数为0(-90dB)。
	上位机没有压限接口。
	处理结果：暂时将压限功能中的增益设为1.0。initParameters.asm 301行
	r0 = r0 - r3 改成 r0 = r0 - r0
2012-08-20
	只允许UP/DOWN两个键重复作用，其他按键重复作用禁止，增加一个变量
	_Up_Down_Key，在UP_DOWM_PROCESS中置1，EndKeyPortJudge中检测。
	去掉EndKeyPortJudge1。
	缩短按键等待时间(_keyProcessing初始处的循环)

2011-12-09
	修正按键错位bug。键盘处理时先延迟(空循环0x100000次,一百万)再读两次。
	_KeyProcessing:
	按键延迟时间140ms，数字闪烁时间25ms。

	禁止MUTE_x按键连续作用，增加一个按键返回子程序

2011-12-07
	BIT_30用于按键作用标记，由IRQ1中断置位，按键处理结束后复位
	BIT_28用于面板锁标记，仅在上电和串口访问(IDhello时改变
	定时周期10ms，检查BIT_28和BIT_30

2011-12-02
	修改按键节奏,将SWITCH_DELAY从30改成18
	改变初始化参数输出通道连接，1->ABC, 2->DEF(buffers1.asm)
	面板调参数时，如果程序号未做改变则参数不变
2011-10-21
	确定sdram问题，将DQM引脚通过硬件接地，改善开机亮灯问题
	改变面板刷新方式，变量levelIndicator在主程序_main中控制
	64次采样更新一次面板电平指示灯
2011-08-22
	constant.h 中 dB 表以 0.8 为0dB，预留限幅空间(0.8功率相当于幅度0.9)
	手动控制实现对程序保存和载入。Program指示灯表示载入，同机控方式；
	Lock指示灯将当前参数写入Flash,程序号连续变化。
	(下次增加识别保护标记)
	优化 _getLevelInformation@uart1.asm

2011-08-08
	修改上位机联机锁定面板控制方式：上位机脱机时实施面板锁定/解锁状态
	联机时只记录修改状态。
	分离PEQLevel和_inpParam.gain. PEQLevel作用于输入浮点数之后再计算幅度和
	缓存进SDRAM。
	initFlash初始参数中 PeakLimiterThreshold 生效会导致输出Over指示灯不达标
	初始化参数将 PeakLimiterThreshold 设为 0

2011-08-03
来自杨洪广邮件：
---------------------------------------
另外我所用到的SDRAM初化代码如下:

section("seg_pmco") void InitSDRAM(void)  //不能放到SDRAM中
{
  int  i,temp;
  temp=*pSYSCTL;
 temp|=MSEN;
 temp^=MSEN;
 temp|=IRQ0EN;
 temp^=IRQ0EN;
 
 *pSYSCTL=temp;
   
 sysreg_bit_clr(sysreg_FLAGS, (FLG0) );        //Clearing flag pins 
 
 for (i=0; i<15000; i++)
          asm("nop;");          
    
  /* temp = 2050; // CCLK=  264MHz */
  temp = 1540; // CCLK = 198MHz

   temp =temp | SDROPT | BIT_17;  // Enabling SDRAM read optimization   
 
    *pSDRRC=temp;
         for (i=0; i<2250; i++)
          asm("nop;");    
    
      temp= 0
   |SDNOBSTOP
   |SDRAW12           //Row Address : RA0 ~ RA11, Column Address : CA0 ~ CA8    Auto-precharge flag : A10 由IC参数指定
   |SDTRCD3
   |SDTWR1
   |X16DE
//   |SDSRF
   |SDPSS
   |SDCAW9
//   |SDPM
   |SDTRP2
   |SDTRAS4
   |DSDCLK1
   |SDCL2;
  
   *pSDCTL=temp;
   
  temp=WS2|HC1|BW16|AMIEN;  
  *pAMICTL0=temp;
  
  temp=*pEPCTL;
  temp|=B0SD;  //使用第几片芯片
  
    temp|=(B1SD|B2SD|B3SD);
  temp^=(B1SD|B2SD|B3SD);
  
  temp|=(DATEN0|DATEN1);
  temp^=(DATEN0|DATEN1);
  
  temp|=(DATEN2|DATEN3); 
  *pEPCTL=temp;  
  
  temp=AMIEN|BW8|WS23|PKDIS;
  *pAMICTL1=temp;
  
   for (i=0; i<250; i++)
          asm("nop;"); 
--------------------------------

2011-07-29
	修改ADC时钟模式,由Master改为Slave,时钟由DSP的PCG
	(PRECISION CLOCK GENERATORS)产生。为此增加一个文件 initpcg.asm
	同时须修改 initsru.asm 关于ADC、DAC route 相关部分
2011-06-29
	连续按键作用小改(EndKeyPortJudge 加延迟)

	修正_programOutputStatus 初值和参数不一致，导致首次写入flash的状态显示
	灯不正确。

2011-06-28
	uart (IDK 命令面板锁状态读自flash
	脱机后从flash中读面板锁状态并送指示灯显示
	增加 uart_Z 命令，读ADC转换数据_samples, _inp_buf, _outp_buf等
	(IDZVVV, VVV 为从 _samples 地址开始的偏移值，返回8个字的16进制ASCII码
	增加 uart_D 命令，在线刷FLASH
	(01DSSSPPP.....
	SSS为sector No. 16进制
	PPP为扇区内区号, 0--7,
	后接128x32位的HEX ASCII(大写), 计1024字节。本命令共8+1024字节。
	每次发送512字节的二进制数据，一个扇区需要8次。

	_lastSwitch、 _switchPosition 初值全部为0，避免首次按键错误(手工方式)。

	_UP_DOWN_KEY_PROCESS后面加延迟，允许按键连续作用(改变ID)

2011-06-23 
---来自杨洪广邮件
	1.上位联机，将所有通道链接到A通道，再将A通道的HLPF参数调节成
	（HPF:200Hz, LPF:15000Hz),断开联接再查看面板的状态指示灯，
	发现只有A通道的灯指示正确而其它的指示灯都没有更新. 
	2.我记得Limit功能要求做成自动增益控制模式，但实际测得还是限幅
	（信号大了只是削波）。
 	3.通过上位机不能锁定面板.
	4.DSP上电运行时，对没有保存过任何参数的Flash要做特殊处理,需要对
	Flash中的1号程序空间赋值.

	后续改的程序不用考虑66MHz的情况，就用198MHz的吧.2011-05-24
----
	电平显示计算来自当前采样点，不用平滑

	串口改变CHSource和 frequency ranges时面板指示同步显示,在P007_L0后增加
	call _statusUpdate,确保显示更新。

	检测到新机器时写1号、51号程序
2011-05-23
	增加面板手动调节参数功能(上电时按住DISPLAY键)
	面板功能见文件 PanelDoc.txt 说明
	uart1.asm 增加  uart_C 烧flash

2011-03-07
	面板消除limiter灯闪烁问题
	inComp,outComp合并进inpParam和outpParam(6列)
2011-03-04
	完善面板操作

	降频测试用(16.5MHz*12/2=99MHz)
	启动默认去保护方式

-------------------------------
	新板串口可能有bug. 在uart1.asm的函数_setNewParameters中检查 "("
	老板主频上不去，新板好像这个问题没有了。

2011-03-01
	串口接收增加"("判断，消除电路未知启动位影响
	v.54版 增加一个串口命令 (IDVxxx, 返回16进制参数
	(IDM 命令计算将浮点改成定点

********************************
2011-05-20   SUBVERSION CONTROL
********************************
2010-12-19
	上电后延时读按键panel1.asm
	uart_J命令 (IDJ0002+21byte 和  (IDJ0003+256byte
2010-12-12
	PUSH STS(stack status), IRQ2-0、Timer中断自动保护。
	其他中断需要手工执行，否则结果不确切(标志位控制失灵)
2010-12-8
	简化uart_S:000-050,大于050返回e10, 小于001 返回e11,受保护程序删除返回e12
2010-12-3
	增加片内SRAM到片外SDRAM的DMA方式
	去掉initdma.asm,将初始化设置放在sport.asm最后(两行)

	调整_inpParam,_outpParam结构顺序为：
		delay, mute, gain, threshold, ratio(简化processing指令)
	修改因此而变更的参数顺序
		(initParameters.asm,processing.asm,uart.asm,panel.asm)
2010-12-2
	Attack Time: 0--60 vs. 0.01ms--1s, t=0.01*10^(x/12)
	Release Time: 0--48 vs. 1ms--10s,  t=1*10^(x/12)

2010-11-30
	将BIT_29用于status功能，置位时跳过电平指示设置
2010-11-26
	BIT_12, 告知ADC中断取面板指示灯地址
	去掉BIT_24,指示灯始终工作
	ADC中断中控制面板，当BIT_30有效(有按键)时停止面板操作

2010-11-20
	增加输出LINK功能
	去掉crossLink变量，直接使用 outputChannel->Source
2010-11-18
	uart静音与面板同步(简化_ledtable表，只保留在_panelCommand偏移值)
	开机显示程序号,不显示"EC"(_panelCommand表数值)
	开机电平指示器即开始工作
	输入静音用1表示，输出静音用0表示
	高、低通频率参数乱，122表示低通无效
	
2010-11-10
	调整文件内容
		processing.asm 包含 biquadIIR, compressor, filtering...
		initParameters.asm 包含 系统参数设置

2010-11-02
	上电时Up/Down 禁用/启用面板：
	读两次(一次读取有问题)
		bit clr/set IMASK IRQ1I(中断禁止/允许)
		bit set ustat4 BIT_28(改变标记禁止/允许)
	重新恢复频率查表
	BIT_30与BIT_29同步，去掉BIT_29功能

2010-10-30
	BIT_10/ustat4: 信号发生器(sine/pinknoise)
	增加信号发生器源选择

2010-10-28
	BIT_14/ustat4: UART 数据格式错误标记
	BIT_10/ustat4: 信号源标志(模拟输入／正弦波输入)

2010-10-09
	BIT_20/ustat4: 8段数码管闪烁
	BIT_21/ustat4: 数字/黑切换标记
	BIT_24/ustat4: 电平指示器工作
	BIT_28/ustat4: 按键延迟
	BIT_29/ustat4: 根据按键消息设置的标志，供主程序查询
	BIT_30/ustat4: 按键消息
	BIT_31/ustat4: ADC、DAC转换结束处理标记
2010-10-07
	R15 专用于采样处理指针
	M0  专用于通道指针调整，M0=MAXBUFFER
	增加能量检测，用于发光二极管电平指示

The parallel operation performs a multiply or multiply/accumulate
	and one of the following ALU operations:
		add, subtract, average, fixed-point to floating-point conversion
		or floating-point to fixed-point conversion,
		and/or floating-point abs, min, or max. 

	r1 = 3; r4 = 0;
	lcntr = 5, do (pc, 4) until lce;
		r1 = r1 - 1;
		call abc(DB);
		nop;
		nop;
exit:(正确)
......

当用 call abc;时,循环结束前须多一条指令。
	lcntr = 5, do (pc, 5) until lce;
		r1 = r1 - 1;
		call abc;
		nop;
		nop;
		nop;
exit:(正确)


	lcntr = 5, do (pc, 5) until lce;
		r1 = r1 - 1;
		if ge jump (pc, -1);	// 条件指令
		r4 = r4+1;
		nop;
		nop;
exit:(正确)

The IDLE and EMUIDLE instructions should not be used in: 
1.Counter based loops of one, two or three instructions 
2.The fourth instruction of a counter based loop with four instructions 
3.The fifth from last (e-4) instruction of a loop with more than four instructions 
4.The last three instructions of any arithmetic loop 

2010-09-30
	降频！264MHz会导致跑飞。降到16.5Mx30/2=247.5MHz
	IRQ1中断时关闭IRQ1，TGL FLG8|FLG9，将定时中断延长，置BIT_30/ustat4
	定时中断在BIT_30置位时置BIT_29/ustat4，并关定时中断
	按键处理结束后清BIT_30|BIT_29，置IRQ1|TMZLI，恢复定时器初值
	主程序判断BIT_29/ustat4

	BIT_20/ustat4用于闪烁，定时器中断中递减 blink88，
	闪烁显示中 TGL ustat4 BIT_21并根据 BIT_21开关显示

2010-09-27
	在定时器中断中FLG8、FLG9交替变高低，
	发生按键中断后关闭定时器和按键中断，置BIT_30/ustat4。
	按键处理结合FLAG8/9的状态确定按键位置，结束前开放中断。
	定时器使用低优先级中断。
	panel.asm完善中

2010-09-20
	增加计算瞬时功率，用于电平显示

2010-09-19
	面板上按键一端FLG8、FLG9电平拉低不马上改变MAX7301输入状态，
	因为有电容(硬件防抖动)。故设计两次读按键，读取时间间隔由定时器中断控制。

	BIT_30/ustat4为按键中断发生事件，定时器中断根据该位读按键，
	每读一次将FLG8取反，根据FLG8状态置 BIT_29/ustat4标志。
	主程序根据 BIT_29 执行按键处理。

2010-09-17
	修正如下bug:
	calculatePEQ.asm中
	Peaking/Shelving 增益 为步进 0.5dB(2.302/40->203.2->80)
	PEQ 增益中值 0xd0改为0，简化程序(因增益只在正、负12dB范围)
	初值表相应参数随之变化
	uart.asm中，compRatio 以 0.5dB 为单位，不用浮点格式
	setOutputPEQ标号下 dm(i4,m4)=r4应为dm(m4,i4)=r4
	两处 call _expf()前的i4换成i3，因expf()中使用i4
	uartISR中 将r11改用r9,以后r11专用于除法，初值=2.0
	PEQ初值全部通道相同。
	crossover.asm _iirFirstOrder 计算 a1 符号错


2010-09-10
	定时器10ms中断常开
	计数器blink88=50，根据BIT_20/ustat4 递减
	blink程序根据 BIT_21/ustat4 决定亮或灭

Rn = FDEP Rx by a:b --> Rx从低位对齐，取b位左移a位 -> Rn
Rn = FEXT Rx by a:b --> Rx从a位起，取b位，右移到低位 -> Rn

2010-09-04
AD采样数据归一化，DA输出前还原24bit(Float shift,fix shift)
ustat4 作为位标记
	BIT_31=1 采样结束，BIT_31=0 处理结束，供主程序判断
	BIT_30=1 按键中断，供定时器计数，按键处理时清除
	BIT_21, uart 结构错误标记
	BIT_20=1 LED flash


2010-09-01
小改 _updateAllGain，规范循环计数器
指针i12、i13换成i14、i15，以便panel调用
相应调用处皆作修改

2010-08-13
改EC2600板，重写ADC、DAC、UART0、SPIA(SPIflash)、SPIB(面板MAX7301)
SDRAM初始化

2010-08-02
串口ASCII

2010-08-01
_inpParam 和 _outpParam 结构增加mute字段, 
修改_copyInputToOutput，_autoGainControl，增加一个乘因子 mute
修改uart.asm，支持mute参数
优化 _inputPEQsInit ,_outputPEQsInit

2010-07-20
增加seg_dm16段，作为字节单位存储(16位存一个字节)

2010-07-18
增加DMA功能，DMAC0用于片内存储器向SDRAM写数据
AD转换进_inp_buf(2 通道), 第一轮滤波后将其拷入SDRAM 输入缓冲队列(DMAC0)
第二轮滤波再将_inp_buf(8 通道输出)拷入SDRAM 输出缓冲队列(DMAC0)

会不会SDRAM 跟不上 DMA 产生bug?

调整 _copyInputToOutput 循环结构，增加并行效率去掉重复向SDRAM的复制
优化 _outputPEQsInit 循环

2010-07-15

纯汇编
96kHz采样处理速度跟不上，怀疑是SDRAM速度问题
增加两个片内缓冲：AD采样进SRAM，处理完的数据也进SRAM

FLAG中增加标记，采样后置位，处理完复位。不再用指针跟踪
FLAG相应位要求置 FLG15O(output)

tanf.asm BUG fixed(1.0不能省, f12 = dm(i4, 1) load)
crossover.asm BUG: _iirSecondOrder中 a1符号 fixed
crossover.asm, calculatePEQ.asm, FrequencyTable改为计算，节省数据空间
（与工程中的1/12倍频程频率有出入，可根据要求再改回）

优化了sinf.asm sqrtf.asm
sqrtf.asm要求 f0=0.5x 输入，恰好和调用处吻合

biquadIIR.asm 修改，增加 m2=2的指针调整，省去i0=i1的同一序列双指针
(待调试)


问题：中断再继续有时没声音
串口传输数据有时会导致永久无声

//#define SRD1H BIT_3   // DAG1 alt. register select (7-4) I,M,B and L
//#define SRD1L BIT_4   // DAG1 alt. register select (3-0)
//#define SRD2H BIT_5   // DAG2 alt. register select (15-12)
//#define SRD2L BIT_6   // DAG2 alt. register select (11-8)
//#define SRRFH BIT_7   // Register file alt. select for R(15-8)
//#define SRRFL BIT_10  // Register file alt. select for R(7-0)

