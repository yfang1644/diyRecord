2011-05-24
	���ڸı�CHSource�� frequency rangesʱ���ָʾͬ����ʾ
	��initSPORT������ǰ���ƺ������һ��(��ȷ�������������)
2011-05-23
	���⣺
	1. ������Limitָʾ��ż��������(��ο��ػ����Ż����)��
	ͬ��һ̨��������ǰ�ĳ��򲻻���ִ�������.(EC2600-55 -> EC2600-56?)
	2.ͨ����λ���������������壬���¿��ػ�����ʧЧ.
	����2��uart1.asm uart_C ��֧���� writeFlash 

	����Ƿ����»���(machine ID <= 50?)
	������»���д�������Ϣ
	����1�����Ե��� sport ������˳��panel֮��(�������ݸ�ʽ��������ֵNaN)

2011-05-22
	�ֹ����� inComp,outComp�ϲ���inpParam��outpParam ��һЩ����,δ��֤
2011-03-07
	�������limiter����˸����
	inComp,outComp�ϲ���inpParam��outpParam(6��)
2011-03-04
	����������

	��Ƶ������(16.5MHz*12/2=99MHz)
	����Ĭ��ȥ������ʽ

-------------------------------
	�°崮�ڿ�����bug. ��uart1.asm�ĺ���_setNewParameters�м�� "("
	�ϰ���Ƶ�ϲ�ȥ���°�����������û���ˡ�

2011-03-01
	���ڽ�������"("�жϣ�������·δ֪����λӰ��
	v.54�� ����һ���������� (IDVxxx, ����16���Ʋ���
	(IDM ������㽫����ĳɶ���

********************************
2011-05-20   SUBVERSION CONTROL
********************************
2010-12-19
	�ϵ����ʱ������panel1.asm
	uart_J���� (IDJ0002+21byte ��  (IDJ0003+256byte
2010-12-12
	PUSH STS(stack status), IRQ2-0��Timer�ж��Զ�������
	�����ж���Ҫ�ֹ�ִ�У���������ȷ��(��־λ����ʧ��)
2010-12-8
	��uart_S:000-050,����050����e10, С��001 ����e11,�ܱ�������ɾ������e12
2010-12-3
	����Ƭ��SRAM��Ƭ��SDRAM��DMA��ʽ
	ȥ��initdma.asm,����ʼ�����÷���sport.asm���(����)

	����_inpParam,_outpParam�ṹ˳��Ϊ��
		delay, mute, gain, threshold, ratio(��processingָ��)
	�޸���˶�����Ĳ���˳��
		(initParameters.asm,processing.asm,uart.asm,panel.asm)
2010-12-2
	Attack Time: 0--60 vs. 0.01ms--1s, t=0.01*10^(x/12)
	Release Time: 0--48 vs. 1ms--10s,  t=1*10^(x/12)

2010-11-30
	��BIT_29����status���ܣ���λʱ������ƽָʾ����
2010-11-26
	BIT_12, ��֪ADC�ж�ȡ���ָʾ�Ƶ�ַ
	ȥ��BIT_24,ָʾ��ʼ�չ���
	ADC�ж��п�����壬��BIT_30��Ч(�а���)ʱֹͣ������

2010-11-20
	�������LINK����
	ȥ��crossLink������ֱ��ʹ�� outputChannel->Source
2010-11-18
	uart���������ͬ��(��_ledtable��ֻ������_panelCommandƫ��ֵ)
	������ʾ�����,����ʾ"EC"(_panelCommand����ֵ)
	������ƽָʾ������ʼ����
	���뾲����1��ʾ�����������0��ʾ
	�ߡ���ͨƵ�ʲ����ң�122��ʾ��ͨ��Ч
	
2010-11-10
	�����ļ�����
		processing.asm ���� biquadIIR, compressor, filtering...
		initParameters.asm ���� ϵͳ��������

2010-11-02
	�ϵ�ʱUp/Down ����/������壺
	������(һ�ζ�ȡ������)
		bit clr/set IMASK IRQ1I(�жϽ�ֹ/����)
		bit set ustat4 BIT_28(�ı��ǽ�ֹ/����)
	���»ָ�Ƶ�ʲ��
	BIT_30��BIT_29ͬ����ȥ��BIT_29����

2010-10-30
	BIT_10/ustat4: �źŷ�����(sine/pinknoise)
	�����źŷ�����Դѡ��

2010-10-28
	BIT_14/ustat4: UART ���ݸ�ʽ������
	BIT_10/ustat4: �ź�Դ��־(ģ�����룯���Ҳ�����)

2010-10-09
	BIT_20/ustat4: 8���������˸
	BIT_21/ustat4: ����/���л����
	BIT_24/ustat4: ��ƽָʾ������
	BIT_28/ustat4: �����ӳ�
	BIT_29/ustat4: ���ݰ�����Ϣ���õı�־�����������ѯ
	BIT_30/ustat4: ������Ϣ
	BIT_31/ustat4: ADC��DACת������������
2010-10-07
	R15 ר���ڲ�������ָ��
	M0  ר����ͨ��ָ�������M0=MAXBUFFER
	����������⣬���ڷ�������ܵ�ƽָʾ

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
exit:(��ȷ)
......

���� call abc;ʱ,ѭ������ǰ���һ��ָ�
	lcntr = 5, do (pc, 5) until lce;
		r1 = r1 - 1;
		call abc;
		nop;
		nop;
		nop;
exit:(��ȷ)


	lcntr = 5, do (pc, 5) until lce;
		r1 = r1 - 1;
		if ge jump (pc, -1);	// ����ָ��
		r4 = r4+1;
		nop;
		nop;
exit:(��ȷ)

The IDLE and EMUIDLE instructions should not be used in: 
1.Counter based loops of one, two or three instructions 
2.The fourth instruction of a counter based loop with four instructions 
3.The fifth from last (e-4) instruction of a loop with more than four instructions 
4.The last three instructions of any arithmetic loop 

2010-09-30
	��Ƶ��264MHz�ᵼ���ܷɡ�����16.5Mx30/2=247.5MHz
	IRQ1�ж�ʱ�ر�IRQ1��TGL FLG8|FLG9������ʱ�ж��ӳ�����BIT_30/ustat4
	��ʱ�ж���BIT_30��λʱ��BIT_29/ustat4�����ض�ʱ�ж�
	���������������BIT_30|BIT_29����IRQ1|TMZLI���ָ���ʱ����ֵ
	�������ж�BIT_29/ustat4

	BIT_20/ustat4������˸����ʱ���ж��еݼ� blink88��
	��˸��ʾ�� TGL ustat4 BIT_21������ BIT_21������ʾ

2010-09-27
	�ڶ�ʱ���ж���FLG8��FLG9�����ߵͣ�
	���������жϺ�رն�ʱ���Ͱ����жϣ���BIT_30/ustat4��
	����������FLAG8/9��״̬ȷ������λ�ã�����ǰ�����жϡ�
	��ʱ��ʹ�õ����ȼ��жϡ�
	panel.asm������

2010-09-20
	���Ӽ���˲ʱ���ʣ����ڵ�ƽ��ʾ

2010-09-19
	����ϰ���һ��FLG8��FLG9��ƽ���Ͳ����ϸı�MAX7301����״̬��
	��Ϊ�е���(Ӳ��������)����������ζ���������ȡʱ�����ɶ�ʱ���жϿ��ơ�

	BIT_30/ustat4Ϊ�����жϷ����¼�����ʱ���жϸ��ݸ�λ��������
	ÿ��һ�ν�FLG8ȡ��������FLG8״̬�� BIT_29/ustat4��־��
	��������� BIT_29 ִ�а�������

2010-09-17
	��������bug:
	calculatePEQ.asm��
	Peaking/Shelving ���� Ϊ���� 0.5dB(2.302/40->203.2->80)
	PEQ ������ֵ 0xd0��Ϊ0���򻯳���(������ֻ��������12dB��Χ)
	��ֵ����Ӧ������֮�仯
	uart.asm�У�compRatio �� 0.5dB Ϊ��λ�����ø����ʽ
	setOutputPEQ����� dm(i4,m4)=r4ӦΪdm(m4,i4)=r4
	���� call _expf()ǰ��i4����i3����expf()��ʹ��i4
	uartISR�� ��r11����r9,�Ժ�r11ר���ڳ�������ֵ=2.0
	PEQ��ֵȫ��ͨ����ͬ��
	crossover.asm _iirFirstOrder ���� a1 ���Ŵ�


2010-09-10
	��ʱ��10ms�жϳ���
	������blink88=50������BIT_20/ustat4 �ݼ�
	blink������� BIT_21/ustat4 ����������

Rn = FDEP Rx by a:b --> Rx�ӵ�λ���룬ȡbλ����aλ -> Rn
Rn = FEXT Rx by a:b --> Rx��aλ��ȡbλ�����Ƶ���λ -> Rn

2010-09-04
AD�������ݹ�һ����DA���ǰ��ԭ24bit(Float shift,fix shift)
ustat4 ��Ϊλ���
	BIT_31=1 ����������BIT_31=0 ������������������ж�
	BIT_30=1 �����жϣ�����ʱ����������������ʱ���
	BIT_21, uart �ṹ������
	BIT_20=1 LED flash


2010-09-01
С�� _updateAllGain���淶ѭ��������
ָ��i12��i13����i14��i15���Ա�panel����
��Ӧ���ô������޸�

2010-08-13
��EC2600�壬��дADC��DAC��UART0��SPIA(SPIflash)��SPIB(���MAX7301)
SDRAM��ʼ��

2010-08-02
����ASCII

2010-08-01
_inpParam �� _outpParam �ṹ����mute�ֶ�, 
�޸�_copyInputToOutput��_autoGainControl������һ�������� mute
�޸�uart.asm��֧��mute����
�Ż� _inputPEQsInit ,_outputPEQsInit

2010-07-20
����seg_dm16�Σ���Ϊ�ֽڵ�λ�洢(16λ��һ���ֽ�)

2010-07-18
����DMA���ܣ�DMAC0����Ƭ�ڴ洢����SDRAMд����
ADת����_inp_buf(2 ͨ��), ��һ���˲����俽��SDRAM ���뻺�����(DMAC0)
�ڶ����˲��ٽ�_inp_buf(8 ͨ�����)����SDRAM ����������(DMAC0)

�᲻��SDRAM ������ DMA ����bug?

���� _copyInputToOutput ѭ���ṹ�����Ӳ���Ч��ȥ���ظ���SDRAM�ĸ���
�Ż� _outputPEQsInit ѭ��

2010-07-15

�����
96kHz���������ٶȸ����ϣ�������SDRAM�ٶ�����
��������Ƭ�ڻ��壺AD������SRAM�������������Ҳ��SRAM

FLAG�����ӱ�ǣ���������λ�������긴λ��������ָ�����
FLAG��ӦλҪ���� FLG15O(output)

tanf.asm BUG fixed(1.0����ʡ, f12 = dm(i4, 1) load)
crossover.asm BUG: _iirSecondOrder�� a1���� fixed
crossover.asm, calculatePEQ.asm, FrequencyTable��Ϊ���㣬��ʡ���ݿռ�
���빤���е�1/12��Ƶ��Ƶ���г��룬�ɸ���Ҫ���ٸĻأ�

�Ż���sinf.asm sqrtf.asm
sqrtf.asmҪ�� f0=0.5x ���룬ǡ�ú͵��ô��Ǻ�

biquadIIR.asm �޸ģ����� m2=2��ָ�������ʡȥi0=i1��ͬһ����˫ָ��
(������)


���⣺�ж��ټ�����ʱû����
���ڴ���������ʱ�ᵼ����������

//#define SRD1H BIT_3   // DAG1 alt. register select (7-4) I,M,B and L
//#define SRD1L BIT_4   // DAG1 alt. register select (3-0)
//#define SRD2H BIT_5   // DAG2 alt. register select (15-12)
//#define SRD2L BIT_6   // DAG2 alt. register select (11-8)
//#define SRRFH BIT_7   // Register file alt. select for R(15-8)
//#define SRRFL BIT_10  // Register file alt. select for R(7-0)

