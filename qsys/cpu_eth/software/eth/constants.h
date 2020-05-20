/**
 * System signals and addresses.
 */

#ifndef CONSTANTS_H
#define CONSTANTS_H 1

//________System signals____________
#define SIGNAL_WRADDR 			0x01
#define SIGNAL_RDCNT			0x02
#define SIGNAL_WRDATA			0x08
#define SIGNAL_CNT				0x10
#define SIGNAL_WRDATA32			0x20
//______System addresses____________
/*    		  DAC			     */
#define DAC_CALIBDATA1_ADDR		0x02			/**< LSB DAC calib data.		*/
#define DAC_CALIBDATA2_ADDR		0x03			/**< MSB DAC calib data.		*/
#define DAC_CMD_ADDR			0x04			/**< Commands.					*/
#define DAC_DATA1_ADDR			0x05			/**< LSB DAC data.				*/
#define DAC_DATA2_ADDR			0x06			/**< MSB DAC data.				*/
#define DAC_DATA32_ADDR			0x07			/**< 12-bit DAC data (write).	*/
//__________________________________
/*  		COUNTER 			  */
#define CNT_CMD_ADDR			0x26			/**< Commands					*/
#define CNT_STATUS_ADDR			0x27			/**< Count time (in seconds)	*/
#define CNT_ENABLE_MASK			0x28
#define CNT_CH1_DATA_ADDR		0x2C
//__________________________________
/*         COMMANDS               */
#define CMD_INIT				0x10			/**< INIT command code. 		*/
#define CMD_HELP				0x20			/**< HELP command code. 		*/
#define CMD_INTR				0x30			/**< INTERRUPT command code. 	*/
#define CMD_ADDR				0x40			/**< ADDR command code. 		*/
#define CMD_RADDR				0x50			/**< RADDR command code. 		*/
#define CMD_DATA				0x60			/**< DATA command code. 		*/
#define CMD_RDATA				0x70			/**< RDATA command code.		*/
#define CMD_RST					0xC0			/**< RESET command code.		*/
#define CMD_DAC					0xD0			/**< DAC command code.			*/
//__________________________________
/*         CONSTANTS			  */
#define MARK_INP			  0xDEAF			/**< Input bits sequence mark	*/
#define MARK_OUT			  0xDEAD			/**< Output bits sequence mark	*/
#define MARK_OK				  	0x08			/**< OK response mark			*/
#define MARK_ERR				0x01			/**< Error response mark		*/
#define MARK_BUSY				0x02			/**< Counter busy mark			*/
#endif
