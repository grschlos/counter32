/*******************************************************************************
* Copyright [2016] [Guido Socher (GPL V2), Shchablo Konstantin]
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing,
* software distributed under the License is distributed on an
* "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
* either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*******************************************************************************/

#include "simple_server.h"
#include "constants.h"
#include "math.h"
#include "stdbool.h"
#define PSTR(s) s
//#define STR_LEN 32
#define N_CHN 32

static unsigned char mymac[6] = { 0x54, 0x55, 0x58, 0x10, 0x00, 0x25 }; // mac
static unsigned char myip[4] = { 192, 168, 1, 3 };
static unsigned int myudpport = 0x4b0; // listen port for udp

#define BUFFER_SIZE 300
unsigned char buf[BUFFER_SIZE + 1];
unsigned char bufUDP[BUFFER_SIZE + 1];
static unsigned int delay = 50000;

static unsigned char Enc28j60Bank;
static alt_u16 NextPacketPtr;

void _Delay(unsigned int value)
{
	for (; value>0; value--);
}

void SPI2_Write(unsigned char writedat)
{
    alt_avalon_spi_command(LAN_BASE,0,1,&writedat,0,NULL,ALT_AVALON_SPI_COMMAND_MERGE);
}

unsigned char SPI2_Read()
{
    alt_u8 temp;
    alt_avalon_spi_command(LAN_BASE,0,0,NULL,1,&temp,ALT_AVALON_SPI_COMMAND_MERGE);

    return temp;
}

unsigned char enc28j60ReadOp(unsigned char op, unsigned char address)
{
    unsigned char dat = 0;

    ENC28J60_CSL();

    dat = op | (address & ADDR_MASK);
    SPInet_Write(dat);
    dat = SPInet_Read();
   // do dummy read if needed (for mac and mii, see datasheet page 29)
    if(address & 0x80) {
      dat = SPInet_Read(0xFF);
    }
    // release CS
    ENC28J60_CSH();

    return dat;
}

void enc28j60WriteOp(unsigned char op, unsigned char address, unsigned char data)
{
    unsigned char dat = 0;

    ENC28J60_CSL();
    // issue write command
    dat = op | (address & ADDR_MASK);
    SPInet_Write(dat);
    // write data
    dat = data;
    SPInet_Write(dat);
    ENC28J60_CSH();
}

void enc28j60ReadBuffer(alt_u16 len, unsigned char* data)
{
   ENC28J60_CSL();
    // issue read command
    SPInet_Write(ENC28J60_READ_BUF_MEM);
    while (len--) {
        *data++ = (unsigned char) SPInet_Read( );
    }
    *data = '\0';
    ENC28J60_CSH();
}

void enc28j60WriteBuffer(alt_u16 len, unsigned char* data)
{
    ENC28J60_CSL();
    // issue write command
    SPInet_Write(ENC28J60_WRITE_BUF_MEM);

    while (len--) {
        SPInet_Write(*data++);
    }
    ENC28J60_CSH();
}

void enc28j60SetBank(unsigned char address)
{
    // set the bank (if needed)
    if((address & BANK_MASK) != Enc28j60Bank) {
        // set the bank
        enc28j60WriteOp(ENC28J60_BIT_FIELD_CLR, ECON1, (ECON1_BSEL1 | ECON1_BSEL0));
        enc28j60WriteOp(ENC28J60_BIT_FIELD_SET, ECON1, (address & BANK_MASK) >> 5);
        Enc28j60Bank = (address & BANK_MASK);
    }
}

unsigned char enc28j60Read(unsigned char address)
{
    // set the bank
    enc28j60SetBank(address);
    // do the read
    return enc28j60ReadOp(ENC28J60_READ_CTRL_REG, address);
}

void enc28j60Write(unsigned char address, unsigned char data)
{
    // set the bank
    enc28j60SetBank(address);
    // do the write
    enc28j60WriteOp(ENC28J60_WRITE_CTRL_REG, address, data);
}

void enc28j60PhyWrite(unsigned char address, alt_u16 data)
{
    // set the PHY register address
    enc28j60Write(MIREGADR, address);
    // write the PHY data
    enc28j60Write(MIWRL, data);
    enc28j60Write(MIWRH, data >> 8);
    // wait until the PHY write completes
    while(enc28j60Read(MISTAT) & MISTAT_BUSY) {
    }
}

void enc28j60clkout(unsigned char clk)
{
    // setup clkout: 2 is 12.5MHz:
    enc28j60Write(ECOCON, clk & 0x7);
}

void enc28j60Init(unsigned char * macaddr)
{
    unsigned long i;

    ENC28J60_RSTH();
    for(i = 0; i < 1000; i++);
    ENC28J60_RSTL();
    for(i = 0; i < 10000; i++);
    ENC28J60_RSTH();
    for (i = 0; i < 10000; i++);


    // initialize I/O
    ENC28J60_CSH();
    // perform system reset
    enc28j60WriteOp(ENC28J60_SOFT_RESET, 0, ENC28J60_SOFT_RESET);

    NextPacketPtr = RXSTART_INIT;
    // Rx start
    enc28j60Write(ERXSTL, RXSTART_INIT & 0xFF);
    enc28j60Write(ERXSTH, RXSTART_INIT >> 8);
    // set receive pointer address
    enc28j60Write(ERXRDPTL, RXSTART_INIT & 0xFF);
    enc28j60Write(ERXRDPTH, RXSTART_INIT >> 8);
    // RX end
    enc28j60Write(ERXNDL, RXSTOP_INIT & 0xFF);
    enc28j60Write(ERXNDH, RXSTOP_INIT >> 8);
    // TX start
    enc28j60Write(ETXSTL, TXSTART_INIT & 0xFF);
    enc28j60Write(ETXSTH, TXSTART_INIT >> 8);
    // TX end
    enc28j60Write(ETXNDL, TXSTOP_INIT & 0xFF);
    enc28j60Write(ETXNDH, TXSTOP_INIT >> 8);

    enc28j60Write(ERXFCON, ERXFCON_UCEN | ERXFCON_CRCEN | ERXFCON_PMEN);
    enc28j60Write(EPMM0, 0x3f);
    enc28j60Write(EPMM1, 0x30);
    enc28j60Write(EPMCSL, 0xf9);
    enc28j60Write(EPMCSH, 0xf7);
   //
   // do bank 2 stuff
   // enable MAC receive
   enc28j60Write(MACON1, MACON1_MARXEN | MACON1_TXPAUS | MACON1_RXPAUS);
   // bring MAC out of reset
   enc28j60Write(MACON2, 0x00);
   // enable automatic padding to 60bytes and CRC operations
   enc28j60WriteOp(ENC28J60_BIT_FIELD_SET, MACON3, MACON3_PADCFG0 | MACON3_TXCRCEN | MACON3_FRMLNEN | MACON3_FULDPX);
   // set inter-frame gap (non-back-to-back)
   enc28j60Write(MAIPGL, 0x12);
   enc28j60Write(MAIPGH, 0x0C);
   // set inter-frame gap (back-to-back)
   enc28j60Write(MABBIPG, 0x12);
   // Set the maximum packet size which the controller will accept
   // Do not send packets longer than MAX_FRAMELEN:
   enc28j60Write(MAMXFLL, MAX_FRAMELEN & 0xFF);
   enc28j60Write(MAMXFLH, MAX_FRAMELEN >> 8);
   // do bank 3 stuff
   // write MAC address
   // NOTE: MAC address in ENC28J60 is byte-backward
   enc28j60Write(MAADR5, macaddr[0]);
   enc28j60Write(MAADR4, macaddr[1]);
   enc28j60Write(MAADR3, macaddr[2]);
   enc28j60Write(MAADR2, macaddr[3]);
   enc28j60Write(MAADR1, macaddr[4]);
   enc28j60Write(MAADR0, macaddr[5]);

   enc28j60PhyWrite(PHCON1, PHCON1_PDPXMD);


   // no loopback of transmitted frames
   enc28j60PhyWrite(PHCON2, PHCON2_HDLDIS);
   // switch to bank 0
   enc28j60SetBank(ECON1);
   // enable interrutps
   enc28j60WriteOp(ENC28J60_BIT_FIELD_SET, EIE, EIE_INTIE | EIE_PKTIE);
   // enable packet reception
   enc28j60WriteOp(ENC28J60_BIT_FIELD_SET, ECON1, ECON1_RXEN);
}

// read the revision of the chip:
unsigned char enc28j60getrev(void)
{
    return(enc28j60Read(EREVID));
}

void enc28j60PacketSend(unsigned int len, unsigned char* packet)
{
    // Set the write pointer to start of transmit buffer area
    enc28j60Write(EWRPTL, TXSTART_INIT & 0xFF);
    enc28j60Write(EWRPTH, TXSTART_INIT >> 8);

    // Set the TXND pointer to correspond to the packet size given
    enc28j60Write(ETXNDL, (TXSTART_INIT + len) & 0xFF);
    enc28j60Write(ETXNDH, (TXSTART_INIT + len) >> 8);

    // write per-packet control byte (0x00 means use macon3 settings)
    enc28j60WriteOp(ENC28J60_WRITE_BUF_MEM, 0, 0x00);

    // copy the packet into the transmit buffer
    enc28j60WriteBuffer(len, packet);

    // send the contents of the transmit buffer onto the network
    enc28j60WriteOp(ENC28J60_BIT_FIELD_SET, ECON1, ECON1_TXRTS);

    // Reset the transmit logic problem. See Rev. B4 Silicon Errata point 12.
    if((enc28j60Read(EIR) & EIR_TXERIF)) {
        enc28j60WriteOp(ENC28J60_BIT_FIELD_CLR, ECON1, ECON1_TXRTS);
    }
}

/*-----------------------------------------------------------------
 Gets a packet from the network receive buffer, if one is available.
 The packet will by headed by an ethernet header.
      maxlen  The maximum acceptable length of a retrieved packet.
      packet  Pointer where packet data should be stored.
 Returns: Packet length in bytes if a packet was retrieved, zero otherwise.
-------------------------------------------------------------------*/
alt_u16 enc28j60PacketReceive(alt_u16 maxlen, unsigned char* packet)
{
    unsigned int rxstat;
    unsigned int len;

    if(enc28j60Read(EPKTCNT) == 0) {
        return(0);
    }

    // Set the read pointer to the start of the received packet
    enc28j60Write(ERDPTL, (NextPacketPtr));
    enc28j60Write(ERDPTH, (NextPacketPtr) >> 8);

    // read the next packet pointer
    NextPacketPtr = enc28j60ReadOp(ENC28J60_READ_BUF_MEM, 0);
    NextPacketPtr |= enc28j60ReadOp(ENC28J60_READ_BUF_MEM, 0) << 8;

    // read the packet length (see datasheet page 43)
    len = enc28j60ReadOp(ENC28J60_READ_BUF_MEM, 0);
    len |= enc28j60ReadOp(ENC28J60_READ_BUF_MEM, 0) << 8;

    len -= 4; //remove the CRC count
    // read the receive status (see datasheet page 43)
    rxstat = enc28j60ReadOp(ENC28J60_READ_BUF_MEM, 0);
    rxstat |= enc28j60ReadOp(ENC28J60_READ_BUF_MEM, 0) << 8;
    // limit retrieve length
    if(len > maxlen - 1) {
        len = maxlen - 1;
    }

    // check CRC and symbol errors (see datasheet page 44, table 7-3):
    // The ERXFCON.CRCEN is set by default. Normally we should not
    // need to check this.
    if((rxstat & 0x80) == 0) {
        // invalid
        len = 0;
    }
    else {
        // copy the packet from the receive buffer
        enc28j60ReadBuffer(len, packet);
    }
    // Move the RX read pointer to the start of the next received packet
    // This frees the memory we just read out
    enc28j60Write(ERXRDPTL, (NextPacketPtr));
    enc28j60Write(ERXRDPTH, (NextPacketPtr) >> 8);

    // decrement the packet counter indicate we are done with this packet
    enc28j60WriteOp(ENC28J60_BIT_FIELD_SET, ECON2, ECON2_PKTDEC);
    return(len);
}

//______________________________________________________________________________
/**
 * Read the address of the selected memory cell.
 */
unsigned char readAddr()
{
	return IORD_ALTERA_AVALON_PIO_DATA(PIO_ADDR_BASE);
}

//______________________________________________________________________________
/**
 * Read the 8-bit data from the read register.
 */
unsigned char readData()
{
	return IORD_ALTERA_AVALON_PIO_DATA(PIO_RDATA_BASE);
}

//______________________________________________________________________________
/**
 * Clear signal.
 */
void clearSignal()
{
	IOWR_ALTERA_AVALON_PIO_DATA(PIO_SIGNALS_BASE, 0x00);
}

//______________________________________________________________________________
/**
 * Set memory cell address to zero.
 */
void clearAddr()
{
	IOWR_ALTERA_AVALON_PIO_DATA(PIO_ADDR_BASE, 0x00);
}

//______________________________________________________________________________
/**
 * Erase the data in the write register.
 */
void clearData()
{
	IOWR_ALTERA_AVALON_PIO_DATA(PIO_WDATA_BASE, 0x00);
}

//______________________________________________________________________________
/**
 * Send generic signal. Possible signal codes are
 * specified in file constants.h
 */
void sendSignal(unsigned char value)
{
	IOWR_ALTERA_AVALON_PIO_DATA(PIO_SIGNALS_BASE, value);
	clearSignal();
	_Delay(delay);
}

//______________________________________________________________________________
/**
 * Send 8-bit data.
 */
void sendData(unsigned char value)
{
    IOWR_ALTERA_AVALON_PIO_DATA(PIO_WDATA_BASE, value);
    sendSignal(SIGNAL_WRDATA);
}

//______________________________________________________________________________
/**
 * Send 32-bit data.
 */
void sendData32(unsigned int value)
{
    IOWR_ALTERA_AVALON_PIO_DATA(DATA32_BASE, value);
    sendSignal(SIGNAL_WRDATA32);
}

//______________________________________________________________________________
/**
 * Set the memory cell address to be accessed.
 */
void sendAddr(unsigned char value)
{
    IOWR_ALTERA_AVALON_PIO_DATA(PIO_ADDR_BASE, value);
    sendSignal(SIGNAL_WRADDR);
}

//______________________________________________________________________________
/**
 * Read particular counter channel. Returns the number of counted pulses.
 */
unsigned int readCounter(unsigned char channel)
{
	switch(channel){
	case 1:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT_BASE);
		break;
	case 2:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT2_BASE);
		break;
	case 3:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT3_BASE);
		break;
	case 4:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT4_BASE);
		break;
	case 5:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT5_BASE);
		break;
	case 6:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT6_BASE);
		break;
	case 7:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT7_BASE);
		break;
	case 8:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT8_BASE);
		break;
	case 9:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT9_BASE);
		break;
	case 10:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT10_BASE);
		break;
	case 11:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT11_BASE);
		break;
	case 12:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT12_BASE);
		break;
	case 13:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT13_BASE);
		break;
	case 14:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT14_BASE);
		break;
	case 15:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT15_BASE);
		break;
	case 16:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT16_BASE);
		break;
	case 17:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT17_BASE);
		break;
	case 18:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT18_BASE);
		break;
	case 19:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT19_BASE);
		break;
	case 20:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT20_BASE);
		break;
	case 21:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT21_BASE);
		break;
	case 22:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT22_BASE);
		break;
	case 23:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT23_BASE);
		break;
	case 24:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT24_BASE);
		break;
	case 25:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT25_BASE);
		break;
	case 26:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT26_BASE);
		break;
	case 27:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT27_BASE);
		break;
	case 28:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT28_BASE);
		break;
	case 29:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT29_BASE);
		break;
	case 30:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT30_BASE);
		break;
	case 31:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT31_BASE);
		break;
	case 32:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT32_BASE);
		break;
	default:
		return IORD_ALTERA_AVALON_PIO_DATA(PIO_COUNT_BASE);
	}
}

//______________________________________________________________________________
/**
 * 		Read DAC code from memory.
 */
void readDAC(unsigned short *dac, unsigned char *cAddr)
{
    *dac ^= *dac;

    sendAddr(DAC_DATA1_ADDR);
    *dac |= readData();
    sendAddr(DAC_DATA2_ADDR);
    *dac |= (readData()<<8);

    sendAddr(*cAddr);
}

//______________________________________________________________________________
/**
 * 		Reset all DAC channels to initial state.
 */
void resetDAC()
{
	sendAddr(DAC_CMD_ADDR);
	sendData(0x01);
}

//______________________________________________________________________________
/**
 * 		Initialize specified DAC channel with value code.
 */
void initDAC(unsigned short value)
{
	sendAddr(DAC_DATA32_ADDR);
	sendData32(value);
	/*sendAddr(DAC_DATA2_ADDR);
	sendData(value >> 8);
	sendAddr(DAC_DATA1_ADDR);
	sendData(value);*/
}

//______________________________________________________________________________
/**
 * 		Write DAC calibration code.
 */
void sendCalibDAC(unsigned short dac, unsigned char *cAddr)
{
	sendAddr(DAC_CALIBDATA1_ADDR);
	sendData(dac);
	sendAddr(DAC_CALIBDATA2_ADDR);
	sendData(dac>>8);
	sendAddr(*cAddr);
}

//______________________________________________________________________________
/**
 * 		Reset counter to initial state.
 */
void resetCounter()
{
	sendAddr(CNT_CMD_ADDR);
	sendData(0x01);
}

//______________________________________________________________________________
/**
 * 		Initialize counter.
 */
void initCounter(unsigned int channels, unsigned char *time)
{
	resetCounter();
	sendAddr(CNT_STATUS_ADDR);
	sendData(*time);
	unsigned char i;
	// Writing counter active channels 32-bit mask
	for (i=0; i<4; i++){
		sendAddr(CNT_ENABLE_MASK+i);
		sendData( channels>>(8*i) );
	}
}

//______________________________________________________________________________
/**
 *		Start counting
 */
void sendRun(unsigned int channels, unsigned char cTime,
		unsigned char *cAddr, unsigned short value)
{
    // write DAC code
	initDAC(value);

    // write counting time
	initCounter(channels, &cTime);

	sendAddr(*cAddr);
    sendSignal(SIGNAL_CNT);
}

//______________________________________________________________________________
/**
 * 		Make a generic response. Write received command code.
 */
void writeResponse(unsigned char code, unsigned char **dataPtr)
{
	// Write output mark
	*(*dataPtr)++ = MARK_OUT >> 8;
	*(*dataPtr)++ = MARK_OUT & 0xff;

	// Write command code
	*(*dataPtr)++ = code;
}

//______________________________________________________________________________
/**
 * 		Write int into the buffer.
 */
void writeInt(unsigned int value, unsigned char *buf)
{
	unsigned char i;
	unsigned char *dataPtr=buf;
	for  (i=0; i<4; i++){
		*dataPtr++ = value >> ((3-i)*8);
	}
}

//______________________________________________________________________________
/**
 * Make a response for a command with or without argument and with output value.
 */
int makeCharResponse(unsigned char code, unsigned char value,
		unsigned char *resp)
{
	unsigned char *dataPtr;
	dataPtr = resp;
	writeResponse(code, &dataPtr);
	*dataPtr++ = value;
	return dataPtr-resp;
}

//______________________________________________________________________________
/**
 * Make a response for a command with or without argument and with output value.
 */
int makeIntResponse(unsigned char code, unsigned char mark, unsigned int value,
		unsigned char *resp)
{
	unsigned char *dataPtr;
	dataPtr = resp;
	writeResponse(code, &dataPtr);
	*dataPtr++ = mark;
	writeInt(value, dataPtr);
	dataPtr+=4;
	return dataPtr-resp;
}

//______________________________________________________________________________
/**
 * 		Write DAC code into buffer.
 */
void writeDACValue(unsigned short dac, unsigned char **dataPtr)
{
	**dataPtr	  = 0;
	*(*dataPtr)++ |= dac >> 8;
	**dataPtr	  = 0;
	*(*dataPtr)++ |= dac & 0xff;
}

//______________________________________________________________________________
/**
 * Write DAC code, active counter channels mask  and counter values for
 * active channels into the buffer.
 */
int makeCountResponse( unsigned int channels, unsigned short dac,
		unsigned int *count, bool calib, unsigned char *resp )
{
	unsigned char *dataPtr;
	unsigned char i;
	dataPtr = resp;
	writeResponse(CMD_DAC, &dataPtr);
	dataPtr++;
	writeInt(channels, dataPtr);
	dataPtr+=4;
	writeDACValue(dac, &dataPtr);
	*dataPtr++ = calib<<7;
	if (calib)	return dataPtr-resp;
	for (i=0; i<N_CHN; i++){
		if( ! (channels<<i & (0x01<<(N_CHN-1))) ) continue;
		writeInt(*(count+i), dataPtr);
		dataPtr+=4;
	}
	return dataPtr-resp;
}

//______________________________________________________________________________
/**
 * 		Parse DAC value
 */
void readDACValue( unsigned int *channels, unsigned short *dac,
        unsigned char **dataPtr )
{
    unsigned char i;
    // Enabled channels
    *channels = 0;
    for (i=0; i<4; i++){
    	*channels |= *(*dataPtr)++ << (8*(3-i));
    }

    // Parse DAC value
    *dac = 0;
    *dac |= *(*dataPtr)++ << 8;
    *dac |= *(*dataPtr)++;
}

//______________________________________________________________________________
/**
 *      Parse query.
 */
void parseRun(unsigned short *dac, unsigned int *channels,
		unsigned char *cTime, unsigned short *step,
		unsigned short *nSteps, bool *calibration)
{
	unsigned char *dataPtr;								// pointer to the beginning of the data to be processed
	dataPtr = buf + UDP_DATA_P + 3;

	// Parse channels and DAC value
	readDACValue(channels, dac, &dataPtr);

	// Parse count time
	*cTime = *dataPtr++;

	// Parse DAC step for counter
	*step |= *dataPtr++ << 8;
	*step |= *dataPtr++;

	// Parse number of steps for counter
	*nSteps |= *dataPtr++ << 8;
	*nSteps |= *dataPtr++;

	// Parse calibration tag for counter
	*calibration = *dataPtr >> 7;
}

//______________________________________________________________________________
int simple_server()
{
    // common
    unsigned int plen;
    unsigned int i, j;
    unsigned char str[500] = {0};

    bool isRun = false;
    unsigned short nSteps = 0;
    unsigned short step = 0;

    // time
    unsigned char cTime = 0x01;

    // dac
    unsigned short dac = 0x0;
    bool calib = false;
    unsigned short calibDAC = 0x0;

    // addr
    unsigned char cAddr = 0; clearAddr();

    // data
    unsigned char cWdata = 0x00; clearData();

    unsigned char cRdata = 0x00; cRdata = readData();
    clearSignal();

    unsigned int count[N_CHN];
    for (i=0; i<N_CHN; i++) *(count+i) = 0;
    unsigned int iChannels = 0x0;
    unsigned char cmd = 0x0;
    int respLen = 0x0;

    //unsigned int time;   time   = IORD_ALTERA_AVALON_PIO_DATA(PIO_TIME_BASE);

    /*initialize enc28j60*/
    enc28j60Init(mymac);

    str[0] = (char)enc28j60getrev();

    init_ip_arp_udp_tcp(mymac, myip, myudpport);
    enc28j60PhyWrite(PHLCON, 0x476);
    enc28j60clkout(2); // change clkout from 6.25MHz to 12.5MHz

    // init the ethernet/ip layer:
    while (1) {
        // RUN READ AND WAIT
        if(isRun &	(IORD_ALTERA_AVALON_PIO_DATA(PIO_SIGNALS_0_BASE)\
        		== SIGNAL_CNT)) {
    	    sendSignal(SIGNAL_RDCNT);

            // read count
            for (i=0; i<N_CHN; i++)	*(count+i) = readCounter(i+1);

            unsigned char cnt_flag = 0x0;
            for (i=0; i<4; i++) cnt_flag |= (*(count+i) > 0)<<(7-i);
            if( cnt_flag>0 && calib ) {
            	if (cnt_flag>>(7-i)){
            		calibDAC = dac;
            	}

                // write dac code
                sendCalibDAC(calibDAC, &cAddr);

                nSteps = 0;
                isRun = false;
                calib = false;

                respLen = makeCountResponse(iChannels, dac,
                		count, calib, str);
                for(i = 0; i < BUFFER_SIZE; i++) buf[i] = bufUDP[i];
                make_udp_reply_from_request(buf,
                		(char*)str, respLen, myudpport);
            }
            else {
            	respLen = makeCountResponse(iChannels, dac,
            			count, calib, str);
            	for(i = 0; i < BUFFER_SIZE; i++) buf[i] = bufUDP[i];
            	make_udp_reply_from_request(buf,
            			(char*)str, respLen, myudpport);

                if(nSteps > 0) {
                    nSteps = nSteps - 1;
                    isRun = true;
                    dac += step;

                    sendRun(iChannels, cTime,  &cAddr, dac);
                }
                else {
                    isRun = false;
                }
            }
        }

        plen = enc28j60PacketReceive(BUFFER_SIZE, buf);
        if(plen == 0) {
            continue;
        }

        if(eth_type_is_arp_and_my_ip(buf, plen)) {
            make_arp_answer_from_request(buf);
            continue;
        }

        if(eth_type_is_ip_and_my_ip(buf, plen) == 0) {
            continue;
        }

        if(buf[IP_PROTO_P] == IP_PROTO_ICMP_V &&
            buf[ICMP_TYPE_P] == ICMP_TYPE_ECHOREQUEST_V) {
            make_echo_reply_from_request(buf, plen);
            continue;
        }

        // udp start, we listen on udp port 1200=0x4B0
        if( buf[IP_PROTO_P] == IP_PROTO_UDP_V
        		&& buf[UDP_DST_PORT_H_P] == (myudpport>>8)
        		&& buf[UDP_DST_PORT_L_P] == (myudpport&0xff) ) {
            for(i = UDP_DATA_P; i < UDP_DATA_P+10; i++) {
            	if(!(*(buf+i)==(MARK_INP>>8) && *(buf+i+1)==(MARK_INP&0xff))){
            		continue;
            	}
            	cmd = *(buf+i+2) & 0xf0;
            	switch(cmd){
            	case CMD_INIT:
            		for(j = 0; j < BUFFER_SIZE; j++) bufUDP[j] = buf[j];
            		respLen = makeCharResponse(cmd, MARK_OK, str);
            		goto ANSWER;
            	case CMD_HELP:
            		respLen = makeCharResponse(cmd, MARK_OK, str);
            		goto ANSWER;
            	case CMD_INTR:
            		nSteps = 0;
            		respLen = makeCharResponse(cmd, MARK_OK, str);
            		goto ANSWER;
            	case CMD_ADDR:
            		// parsing addr
            		cAddr = *(buf+i+3);
            		sendAddr(cAddr);
            		respLen = makeCharResponse(cmd, cAddr, str);
            		goto ANSWER;
            	case CMD_RADDR:
            		// parsing raddr
            		cAddr = readAddr();
            		respLen = makeCharResponse(cmd, cAddr, str);
            		goto ANSWER;
            	case CMD_DATA:
            		// parsing data
            		cWdata = *(buf+i+3);
            		sendData(cWdata);
            		respLen = makeCharResponse(cmd, cWdata, str);
            		goto ANSWER;
            	case CMD_RDATA:
            		// parsing rdata
            		cRdata = readData();
            		respLen = makeCharResponse(cmd, cRdata, str);
            		goto ANSWER;
            	case CMD_RST:
            		// reset
            		cAddr=0x01;
            		cWdata=0x02;
            		sendAddr(cAddr);
            		sendData(cWdata);
            		isRun = false;
            		nSteps = 0;
            		step = 0;
            		cTime = 0x01;
            		iChannels = 0xffffffff;
            		dac = 0x0;
            		calib = false;
            		calibDAC = 0x0;
            		respLen = makeCharResponse(cmd, MARK_OK, str);
            		goto ANSWER;
            	case CMD_DAC:
                	// parsing dac data
                    if(!isRun) {
                    	iChannels = 0;
                        parseRun(&dac, &iChannels,
                        		&cTime, &step, &nSteps,
                        		&calib);
                        isRun = true;
                        sendRun(iChannels, cTime,  &cAddr, dac);
                    }
                    else {
                    	respLen = makeIntResponse(cmd, MARK_BUSY,
                    			cTime*nSteps, str); // specify the run length in seconds here
                        goto ANSWER;
                    }
                    respLen = makeCharResponse(cmd, MARK_OK, str);
                    goto ANSWER;
            	default:
            		respLen = makeCharResponse(cmd, MARK_ERR, str);
            		goto ANSWER;
                }
            }
            respLen = makeCharResponse(cmd, MARK_ERR, str);
            ANSWER: make_udp_reply_from_request(buf,
            		(char*)str, respLen, myudpport);
        }
        // UDP end
    }
    // while(1) end
    return (0);
}
