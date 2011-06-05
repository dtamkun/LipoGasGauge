//-----------------------------------------------------------------------
// $Id: LipoGasGauge.pde 61 2011-06-05 01:32:41Z davidtamkun $
//-----------------------------------------------------------------------
//         Program: Lipo Gas Gauge
//         $Author: davidtamkun $
//           $Date: 2011-06-04 18:32:41 -0700 (Sat, 04 Jun 2011) $
//            $Rev: 61 $
//
// Source/Based On: Sample App by J.C. Woltz
//
//         History: DMT 02/22/2011 Created Original Version
//                  DMT 02/23/2011 v1.1.0 LCD to use i2c
//                  DMT 02/26/2011 V1.1.1 LCD using SPI.  Unable to get Log Shield Working
//                  DMT ??/??/2011 V1.2.0 
//                  DMT 03/31/2011 V1.3.0 Attempting to get Log Shield Working
//                  DMT 05/15/2011 V1.4.0 Giving up on Logging Shield for now.
//                                        Renamed file to LipoGasGauge.pde and
//                                        will keep under SVN going forward.
//                                        Added SVN Header Info and code
//                                        to display SVN Info
//                  DMT 05/28/2011 V1.4.0 Rev 46, 50 - still trying to get to work with
//                                        Nokia LCD.  Still having problems.  Rev 50
//                                        Working again with BIG LCD.
//                  DMT 05/30/2011 V1.5.0 Got this code working with Nokia Display on the
//                                        Mega and added % of Battery Capacity on the 20x4 LCD
//                  DMT 05/30/2011 V1.5.1 Confirmed that the Nokia LCD display now works on the
//                                        Uno.
//                  DMT 05/31/2011 V1.5.2 Corrected Nokia LCD display if current flow was
//                                        more than 5 characters.
//                  DMT 06/04/2011 V1.5.3 Enabled Gas Gauge Sleep Mode and Power Switch On/Off
//                                        code works, but needs improvement.
//
//    Compiliation: Arduino IDE
//
//        Hardware: Arduino Uno - ATMEGA328P-PU - 16Mhz
//
//      Components: Gas Gauge on Proto Board with: 
//                       Maxim DS2764+025 Lipo Protector Chip
//                            i2C Slave Address 0x34
//
//                  HD44780 Character 20x4 LCD (White on Blue)
//                  LCD Backback from Adafruit
//                  -- OR --
//                  Nokia LCD Display using PCD8544 driver chip
//
//                  NOT WORKING YET!! Data Logging Shield from Adafruit
//
//                
//       Libraries: Wire/Liquid Crystal for LCD Display
//                  PCD8544 if using Nokia Display
//                  SdFat & RTClib for Data Logging Shield
//
//
//   Communication: Uses i2C for RTC and Gas Gauge
//                       SPI for LCD, Nokia LCD, & SD Card
//
//         Voltage: 5 Volts OK
//
//          Status: Experimental      <=========
//                  Work in Progress
//                  Stable
//                  Complete
//
//          Wiring: LCD Backback from Adafruit
//                  ---------------------------------------------------
//                  SPI LCDBpck    Arduino
//                  -----------    -------
//                  GRN LATCH      D4      SPI Latch
//                  YEL DATA       D3      SPI Data
//                  ORN CLK        D2      SPI Clock
//                  RED +5V        +5v
//                  BLK GND        GND
//
//
//                  Dave's LCD Backpack for Nokia LCD Display - PCD8544
//                  ---------------------------------------------------
//                  MyBkpk         Arduino         Device
//                  Color          Pin             Pin
//                  ------         -------         ------
//                  Brown          GND             GND
//                  Red            +5V             VCC & Bklight LED
//                  Orange         D3              RST*
//                  Yellow         D4              CS*
//                  Green          D5              D/C*
//                  Blue           D6              DIN*
//                  Purple         D7              SCLK*
//                                                 * Level shifted
//
//
//                  Gas Gauge Chip Proto Board - Maxim DS2764+025
//                  ---------------------------------------------------
//                  Shield         Arduino
//                  -----------    -------
//                  GND            GND     Ground
//                  DATA Yellow    A4      i2C Data    (pin 20 on Mega)
//                  CLK  Orange    A5      i2C Clock   (pin 21 on Mega)
//                  
//-----------------------------------------------------------------------
/////////////////////////////////////////////////////////////////////
// Example Test application for the Maxim DS2764 IC. 
// A LiPo protection IC
/////////////////////////////////////////////////////////////////////
// J.C. Woltz 2010.11.15
/////////////////////////////////////////////////////////////////////
// This work is licensed under the Creative Commons 
// Attribution-ShareAlike 3.0 Unported License. To view a copy of 
// this license, visit http://creativecommons.org/licenses/by-sa/3.0/
// or send a letter to 
// Creative Commons, 
// 171 Second Street, 
// Suite 300, 
// San Francisco, California, 94105, USA.
/////////////////////////////////////////////////////////////////////



//******************************************************************************
//** Define Options
//******************************************************************************
#define BAT_CAP        1200.0 // Be sure to put the .0 after this so floating point math will be used when calculating the battery percentage remaining.
#define SMALL_LCD      1      //Use 16x2 LCD
#define BIG_LCD        2      //Use 20x4 LCD
#define NOKIA_LCD      3      //Use 13x5 Nokia LCD Display - 84x48 pixels

#define DISPLAY_TYPE   NOKIA_LCD
//#define DISPLAY_TYPE   BIG_LCD
//#define DISPLAY_TYPE   0

#define USE_LOGGER     0     // Define to use the Data Logging Shield

#if DISPLAY_TYPE == SMALL_LCD
#define NUMCOLS        16    // number of LCD Columns
#define NUMROWS        2     // number of LCD Lines
#define LINEBUFSIZE    NUMCOLS + 1

#elif DISPLAY_TYPE == BIG_LCD
#define NUMCOLS        20    // number of LCD Columns
#define NUMROWS        4     // number of LCD Lines
#define LINEBUFSIZE    NUMCOLS + 1

#elif DISPLAY_TYPE == NOKIA_LCD
#define NUMCOLS        14    // number of LCD Columns
#define NUMROWS         6    // number of LCD Lines
#define LINEBUFSIZE    (NUMCOLS * NUMROWS) + 1    // 6 lines of 14 characters plus trailing NULL
//#define NOWIRE          1

#else
// Define these anyway so our buffers are defined
#define NUMCOLS 13
#define NUMROWS  5
#define LINEBUFSIZE    NUMCOLS + 1
#endif


//                                    1   2
//                     12345678901234567890
#define APP_NAME      "LipoGasGauge" 
#define APP_VER       "v 1.5.3"

// String Buffer Sizes
#define FLOATBUFSIZE        10    // size for buffer string to contain character equivalents of floating point numbers
#define LOGBUFSIZE          20    // number of characters for a line written to the log
#define DATEBUFSIZE         NUMCOLS + 1
#define REVISIONBUFSIZE     NUMCOLS + 1

#define TEMPBUFSIZE         FLOATBUFSIZE + 1
#define CURRENTBUFSIZE      FLOATBUFSIZE + 1
#define VOLTBUFSIZE         FLOATBUFSIZE + 1


//#define USE_SD_LEDS      1  // Define to use LEDs on DL Shield to indicate SD card activity
#define ECHO_TO_SERIAL   1    // echo data to serial port
#define WAIT_TO_START    0    // Wait for serial input in setup()
#define LOG_INTERVAL  1000    // mills between entries
#define SYNC_INTERVAL 1000    // mills between calls to sync()



#ifdef USE_SD_LEDS
// the digital pins that connect to the LEDs
#define redLEDpin     6
#define greenLEDpin   7
#endif


//Flags for Gas Gauge Settings
#define DS00PS        0x80      // status of Power Switch bit in the Special Features Register
#define DS00OV	      0x80
#define DS00UV	      0x40
#define DS00COC	      0x20
#define DS00DOC	      0x10
#define DS00CC	      0x08
#define DS00DC	      0x04
#define DS00CE	      0x02
#define DS00DE	      0x01

//******************************************************************************
//** Include Library Code
//******************************************************************************
//#include <SdFat.h>
//#include <SdFatUtil.h>
#include <PString.h>

#ifndef NOWIRE
#include <Wire.h>           // required for I2C communication with Gas Gauge
#endif

#if DISPLAY_TYPE == SMALL_LCD || DISPLAY_TYPE == BIG_LCD
#include <LiquidCrystal.h>
#elif DISPLAY_TYPE == NOKIA_LCD
#include "PCD8544.h"
#endif

#if USE_LOGGER
#include <RTClib.h>
#endif

//#include <string.h>












//******************************************************************************
//** Declare Global Variables
//******************************************************************************
//-- Declare Variables for Displaying Version Info
const char IDSTR[]                 = "$Id: LipoGasGauge.pde 61 2011-06-05 01:32:41Z davidtamkun $";
const char DATESTR[]               = "$Date: 2011-06-04 18:32:41 -0700 (Sat, 04 Jun 2011) $";
const char REVSTR[]                = "$Rev: 61 $";
      char gszLineBuf[LINEBUFSIZE];
      char gszDateStr[DATEBUFSIZE];
      char gszRevStr [REVISIONBUFSIZE];
      char gszTempBuf[TEMPBUFSIZE];
      char gszCurrBuf[CURRENTBUFSIZE];
      char gszPctBuf[TEMPBUFSIZE];
      char gszVoltBuf[VOLTBUFSIZE];
      
  PString  pstrLine   (gszLineBuf, LINEBUFSIZE);
  PString  pstrTemp   (gszTempBuf, TEMPBUFSIZE);
  PString  pstrCurrent(gszCurrBuf, CURRENTBUFSIZE);
  PString  pstrPercent(gszPctBuf,  TEMPBUFSIZE);
  PString  pstrVolts  (gszVoltBuf, VOLTBUFSIZE);
//  PString  pstrLog    (gszLogBuf,  LOGBUFSIZE);
      
// a bitmap of a degree symbol
static unsigned char __attribute__ ((progmem)) degree_bmp[]={0x06, 0x09, 0x09, 0x06, 0x00};

uint32_t syncTime     = 0; // time of last sync()
int    dsAddress    = 0x34;
int    reading      = 0; 
int    giProtect    = 0;
int    giStatus     = 0;
int    giVolts      = 0;
double gdCurrent    = 0.0;
int    giAccCurrent = 0;
float  gfTempC      = 0.0;
int    giDoIt       = 0;
int    giPowerOn    = 1;

//char   gszLineBuf[NUMCOLS     + 1];
//char   gszLogBuff[LOGBUFSIZE];
//int    giCardOk     = 1;


#if USE_LOGGER
RTC_DS1307 RTC;                                  // define the Real Time Clock object
DateTime dtNow;

// The objects to talk to the SD card
//Sd2Card   card;
//SdVolume  volume;
//SdFile    root;
//SdFile    file;
#endif



#if  DISPLAY_TYPE == SMALL_LCD || DISPLAY_TYPE == BIG_LCD
// initialize the library with the numbers of the interface pins
// for plain connection
//LiquidCrystal lcd(2, 3, 4, 5, 6, 7 );

// for i2C
//LiquidCrystal lcd(0);

// Connect via SPI. Data pin is #3, Clock is #2 and Latch is #4
LiquidCrystal lcd(3, 2, 4);
#elif DISPLAY_TYPE == NOKIA_LCD
//
//PCD8544(int8_t SCLK, int8_t DIN, int8_t DC, int8_t CS, int8_t RST)
PCD8544 nokia = PCD8544(7, 6, 5, 4, 3);
//PCD8544 nokia = PCD8544(2, 3, 5, 6, 7);
//PCD8544 nokia = PCD8544(9, 8, 7, 6, 5);
#endif



// make degree symbol for LCD
uint8_t degree[8]  = {140,146,146,140,128,128,128,128};





//******************************************************************************
//** Start Main Logic
//******************************************************************************

//------------------------------------------------------------------------------
// setup
//
// First function run by the microcontroller and is used to initialize and 
// set up variables and classes.
//
// Arguments:
//     None
//
// Return Value:
//     None
//------------------------------------------------------------------------------
void setup() { 
	Serial.begin(9600);          // start serial communication at 9600bps
        delay(500);
        
        Serial.println();
//        Serial.println("+-------------------------------------------------------+");
//        Serial.println("+-------------------------------------------------------+");
//        Serial.println("+-- Start of Program                                  --+");
//        Serial.println("+-------------------------------------------------------+");
//        Serial.println("+-------------------------------------------------------+");

        fillBuffer(gszDateStr, DATEBUFSIZE,     '\0');
        fillBuffer(gszRevStr,  REVISIONBUFSIZE, '\0');
        fillBuffer(gszLineBuf, LINEBUFSIZE,     '\0');
        fillBuffer(gszTempBuf, TEMPBUFSIZE,     '\0');
        fillBuffer(gszCurrBuf, CURRENTBUFSIZE,  '\0');
        fillBuffer(gszVoltBuf, VOLTBUFSIZE,     '\0');
        //fillBuffer(gszLogBuff, LOGBUFSIZE,      '\0');
        
#if  DISPLAY_TYPE == SMALL_LCD || DISPLAY_TYPE == BIG_LCD 
        Serial.println("LCD is selected");
#elif DISPLAY_TYPE == NOKIA_LCD
        Serial.println("Nokia LCD is selected");
#else
        Serial.println("Some other display or no display selected");
#endif
	
        Serial.println(IDSTR);
        format_svn_info();
        Serial.println(APP_NAME);
        Serial.println(gszRevStr);
        Serial.println(gszDateStr);

        // Set Pin Modes for LCD using 6 wire interface
        //**pinMode(2,           OUTPUT);
        //**pinMode(3,           OUTPUT);
//        pinMode(4,           OUTPUT);
//        pinMode(5,           OUTPUT);
//        pinMode(6,           OUTPUT);
//        pinMode(7,           OUTPUT);

#ifdef USE_SD_LEDS  
        //pinMode(redLEDpin,    OUTPUT);
        //pinMode(greenLEDpin,  OUTPUT);  
#endif      

#ifndef NOWIRE
        Wire.begin();                // join i2c bus (address optional for master) 
        //Serial.println("Wire started...");
#endif
        //RTC.begin(); 
        
        //if (! RTC.isrunning()) {
        //    Serial.println("RTC is NOT running!");
            // following line sets the RTC to the date & time this sketch was compiled
            //RTC.adjust(DateTime(__DATE__, __TIME__));
        //}
        //else {
        //  dtNow = RTC.now();
        //}
        
       
#if  DISPLAY_TYPE == SMALL_LCD || DISPLAY_TYPE == BIG_LCD        
        // set up the LCD's number of rows and columns:
        lcd.begin(NUMCOLS, NUMROWS);
        lcd.createChar(0, degree);
#elif DISPLAY_TYPE == NOKIA_LCD
        nokia.init();
        
        // turn all the pixels on (a handy test)
        nokia.command(PCD8544_DISPLAYCONTROL | PCD8544_DISPLAYALLON);
        delay(500);
        // back to normal
        nokia.command(PCD8544_DISPLAYCONTROL | PCD8544_DISPLAYNORMAL);
        delay(500);
        nokia.clear();

#endif
        
        // Print a message to the LCD and delay as needed
        display_app_version_info();
        

        //char name[13] = "BATGAS00.CSV";
        
        // initialize the SD card
        //if (!card.init()) {error("card.init");}      
  
        // initialize a FAT volume
        //if(!volume.init(card)) {error("volume.init");}

        // open root directory
        //if (!root.openRoot(volume)) {error("openRoot");}

        // create a new file
              
        //for (uint8_t i = 0; i < 100; i++) {
        //  name[6] = i/10 + '0';
        //  name[7] = i%10 + '0';
            
          //if (file.open(root, name, O_CREAT | O_EXCL | O_WRITE)) {break;}
        //} // end for
              
        //if (!file.isOpen()) {error ("file.create");} 
          
        //Serial.print("Logging to: ");
        //Serial.println(name);
         
        //#if ECHO_TO_SERIAL
        //  Serial.println("time,current_mA,voltage_mV,lipo_charge_mAh,temp,VoltsOK,ChargeCurrentOK,DischargeCurrentOK,ChargeEnabled,DischargeEnabled,SleepEnabled");
        //#endif //ECHO_TO_SERIAL

        // write header
        //file.writeError = 0;

        //file.println("time,current_mA,voltage_mV,lipo_charge_mAh,temp,VoltsOK,ChargeCurrentOK,DischargeCurrentOK,ChargeEnabled,DischargeEnabled,SleepEnabled");   
        //  
        // attempt to write out the header to the file
        //if (file.writeError || !file.sync()) {
        //  error("ERROR on write header");
        //}         
        
        // Turn on power flag so we can detect is someone uses the power Button to 
        // turn everything off
        setdsPowerSwitchOn();
        delay(500);
        
        // Reset any Protection Flags, so the Gas Gauge can re-evaluate them  
	resetdsProtection(1);

        //**********************************************************************
        //**********************************************************************
        //** Uncomment the line below and specify the number of mAh you would
        //** Like to reset the Accumulated current counter.
        //** 
        //** Recompile reload / and rerun the program to reset the counter.
        //** 
        //** Once run, be sure to comment the line back out and recompile
        //** and reload once more.  Otherwise, the counter will get reset
        //** to the specified value every time it starts.
        //**********************************************************************
        //**********************************************************************
        //setAccumCurrent(6600);
} 







//------------------------------------------------------------------------------
// loop
//
// Function called repeatedly after setup completes.  You must never "return"
// from this function.  Your main code execution goes here.
//
// Arguments:
//     None
//
// Return Value:
//     None
//------------------------------------------------------------------------------
void loop() 
{ 
        //Serial.println("Entering loop()");
        
        giProtect    = 0;
        giStatus     = 0;
        giVolts      = 0;
        gdCurrent    = 0.0;
        giAccCurrent = 0;
        gfTempC      = 0.0;
        
        if(giDoIt) {
          setSleepMode(1);
          giDoIt = 0;  
        }
        
	getdsProtection();
	getdsVoltage();  
	getdsTemp();
        if (getdsPowerSwitch() == 0 && giPowerOn == 1) {
          // power down
          giPowerOn = 0;
          resetdsProtection(0);
          setdsPowerSwitchOn();  // so we can detect when it's pushed again.
        }
        else if(getdsPowerSwitch() == 0 && giPowerOn == 0) {
          // power up
          giPowerOn = 1;
          resetdsProtection(1);
          setdsPowerSwitchOn(); 
        }

        //dtNow = RTC.now();

        //Serial.println("Loop calling DisplayData()");
        
        DisplayData(giProtect, giStatus, giVolts, gdCurrent, giAccCurrent, gfTempC);
        
	delay(1000);
	
	//Serial.println();
/*
#ifdef USE_LOGGER
        // clear print error
        file.writeError = 0;

        // delay for the amount of time we want between readings
        //delay((LOG_INTERVAL -1) - (millis() % LOG_INTERVAL));
#ifdef USE_SD_LEDS  
        digitalWrite(redLEDpin, HIGH);
#endif        

        // log milliseconds since starting
        uint32_t m = millis();

        // fetch the time
        //now = RTC.now();
        // log time
        if(giCardOk) {
          file.print(gszLogBuff);
          if (file.writeError) error("write data");
        }
        
        
#if ECHO_TO_SERIAL
        Serial.println(gszLogBuff);
#endif //ECHO_TO_SERIAL

        
#ifdef USE_SD_LEDS        
        digitalWrite(redLEDpin, LOW);
#endif        
  
        //don't sync too often - requires 2048 bytes of I/O to SD card
        if ((millis() - syncTime) <  SYNC_INTERVAL) return;
        syncTime = millis();
  
        // blink LED to show we are syncing data to the card & updating FAT!
#ifdef USE_SD_LEDS        
        digitalWrite(greenLEDpin, HIGH);
#endif        
        if (giCardOk) {
          if(!file.sync()) error("sync");
        }
        
#ifdef USE_SD_LEDS        
        digitalWrite(greenLEDpin, LOW);
#endif        
  
#endif
*/
       //Serial.println("Leaving loop...");
} 




#ifdef USE_LOGGER
void error(char *str)
{
  Serial.print("ERROR: ");
  Serial.println(str);
  //Serial.println(card.errorCode(), HEX);
  //Serial.println(card.errorData(), HEX);  
  
  //giCardOk = 0;
  
  Serial.println("--------- Going into infinite loop now --------------");
  delay(5000);
  //while(1);
}
#endif




float getdsTemp() {
	// Read Voltage Register
#ifndef NOWIRE
	Wire.beginTransmission(dsAddress);
	Wire.send(0x18);
	Wire.endTransmission();

	Wire.requestFrom(dsAddress, 2);
	if(2 <= Wire.available())     // if two bytes were received 
	{ 
		reading = Wire.receive();   // receive high byte (overwrites previous reading) 
		reading = reading << 8;     // shift high byte to be high 8 bits 
		reading += Wire.receive();  // receive low byte as lower 8 bits 
		reading = reading >> 5;
         
                gfTempC = reading * 0.125;
		reading = reading * 0.125;
                
		//Serial.print(reading);    // print the reading 
		//Serial.println(" degree C");
	}
        else {
          //Serial.println("Nothing Received from Get Temp Request");
          gfTempC = 0.0;
        }
#else
          Serial.println("Nothing Received from Get Temp Request - Wire Bypassed");
          gfTempC = 0.0;
#endif

	return reading;
}




int getdsProtection(void) {
	int dsProtect  = 0;
	int dsStatus   = 0;

#ifndef NOWIRE
	// Read Protection Register
	Wire.beginTransmission(dsAddress);
	Wire.send(0x00);
	Wire.endTransmission();
	Wire.requestFrom(dsAddress, 2);
	if(2 <= Wire.available())     // if two bytes were received 
	{ 
		dsProtect = Wire.receive();
		dsStatus = Wire.receive();

		//Serial.println(dsProtect, HEX);
		//Serial.println(dsStatus,  HEX);

                giProtect = dsProtect;
                giStatus  = dsStatus;

                /*
                if (!dsProtect & (DS00OV + DS00UV)) {
                  Serial.println("          Voltage: OK");
                }
                else if (dsProtect & DS00OV) { 
                  Serial.println("          Voltage: *** OVER  ***"); 
                }
		else if (dsProtect & DS00UV) { 
                  Serial.println("          Voltage: *** UNDER ***"); 
                }
                
		if (dsProtect & DS00COC) { 
                  Serial.println("   Charge Current: *** OVER  ***"); 
                }
                else {
                  Serial.println("   Charge Current: OK");
                }
                
		if (dsProtect & DS00DOC) { 
                  Serial.println("Discharge Current: *** OVER  ***"); 
                }
                else {
                  Serial.println("Discharge Current: OK");
                }
                
                */
		if (dsProtect & DS00CC) { 
                  Serial.println("         Charging: *** OFF ***");
                }
                else {
                  Serial.println("         Charging: ON");
                }
                
                if (dsProtect & DS00CE) { 
                  Serial.println("         Charging: Enabled"); 
                }
                else {
                  Serial.println("         Charging: Disabled");
                }
		
		if (dsProtect & DS00DC) { 
                  Serial.println("      Discharging: *** OFF ***"); 
                }
                else {
                  Serial.println("      Discharging: ON");
                }
                
		if (dsProtect & DS00DE) { 
                  Serial.println("      Discharging: Enabled");
                }
                else {
                  Serial.println("      Discharging: Disabled");
                }
                
		if (dsStatus & 32) { 
                  Serial.println("       Sleep mode: Enabled");
                }
                else {
                  Serial.println("       Sleep mode: Disabled");
                }
                
                
	}
        else {
          //Serial.println("Nothing Received from Get Protection Settings Request");
          giProtect = 0;
          giStatus  = 0;

        }
#else
          Serial.println("Nothing Received from Get Protection Settings Request - WIRE BYPASSED");
          giProtect = 0;
          giStatus  = 0;
#endif
	return dsProtect;
}





float getdsVoltage(void) {
	int voltage   = 0;
	int current   = 0;
	int acurrent  = 0;

#ifndef NOWIRE
	// Read Voltage Register
	Wire.beginTransmission(dsAddress);
	Wire.send(0x0C);
	Wire.endTransmission();

	Wire.requestFrom(dsAddress, 6);
	delay(4);
	if(6 <= Wire.available())     // if six bytes were received 
	{ 
		voltage = Wire.receive();
		voltage = voltage << 8;
		voltage += Wire.receive();
		voltage = voltage >> 5;
		voltage = voltage * 4.88;
		
		current = Wire.receive();
		current = current << 8;
		current += Wire.receive();
		
		acurrent = Wire.receive();
		acurrent = acurrent << 8;
		acurrent += Wire.receive();
		
		if ((current & 0x80) == 0x80) {
			current = (current ^ 0xFFFFFFFF);
                        
                        current = current * -1;
		}
		current = current >> 3;

		double c = (current * 0.625);
		
		acurrent = acurrent * 0.25;

                giVolts      = voltage;
                gdCurrent    = c;
                giAccCurrent = acurrent;
        }
        else {
          //Serial.println("Nothing received from get Voltage Request");

          giVolts      = 0;
          gdCurrent    = 0.0;
          giAccCurrent = 0;

        }
#else
          Serial.println("Nothing received from get Voltage Request - Wire Bypassed");

          giVolts      = 0;
          gdCurrent    = 0.0;
          giAccCurrent = 0;


#endif
	return voltage;
}








//------------------------------------------------------------------------------
// getdsPowerSwitch
//
// Retrieves the value of the PowerSwitch bit, which is Bit 7 of the 
// special features register at address 0x08.  Only the Arduino can set 
// this bit to 1, but the bit will be set to 0 is the Power Button is pushed,
// which brings the voltage on the PS pin of the chip to LOW.
// 
//
// Arguments:
//     None
//
// Return Value:
//     1 if the bit value is 1, meaning that the power is "on"
//     0 if the bit value is 0, signaling a request to turn power off.
//    -1 if no value retrieved
//------------------------------------------------------------------------------
int getdsPowerSwitch(void) {
	int dsSpecial  = 0;
        int iReturn    = -1;
	//int dsStatus   = 0;

#ifndef NOWIRE
	// Read Protection Register
	Wire.beginTransmission(dsAddress);
	Wire.send(0x08);
	Wire.endTransmission();
	Wire.requestFrom(dsAddress, 1);
	if(1 <= Wire.available())     // if two bytes were received 
	{ 
		dsSpecial = Wire.receive();
		//dsStatus = Wire.receive();

		//Serial.println(dsSpecial,BIN);
                //Serial.println(DS00PS,   BIN);
		//Serial.println(dsStatus,BIN);

                //giProtect = dsProtect;
                //giStatus  = dsStatus;

		if (dsSpecial & DS00PS) { 
                  Serial.println("PsON");
                  iReturn = 1;
                }
                else {
                  Serial.println("PsOFF");
                  iReturn = 0;
                }
                
                
	}
        //else {
        //  Serial.println("Nothing Received from Get Power State");
        //}
#else
          Serial.println("Nothing Received from Get Power State - WIRE BYPASSED");
          iReturn = 0;
#endif
	return iReturn;
}









//------------------------------------------------------------------------------
// setdsPowerSwitchOn
//
// Sets the value of the PowerSwitch bit, which is Bit 7 of the 
// special features register at address 0x08, to 1.  Only the Arduino can set 
// this bit to 1, but the bit will be set to 0 if the Power Button is pushed,
// which brings the voltage on the PS pin of the chip to LOW.
// 
//
// Arguments:
//     None
//
// Return Value:
//     1 if the bit value was set to 1, meaning that the power is "on"
//     0 if the bit value was not set and is still 0
//    -1 if no value was returned when trying to confirm the setting was made.
//------------------------------------------------------------------------------
int setdsPowerSwitchOn(void) {
	int dsSpecial  = 0;
        int iReturn    = -1;

#ifndef NOWIRE
	// Read Protection Register
	Wire.beginTransmission(dsAddress);
	Wire.send(0x08);
        Wire.send(DS00PS);
	Wire.endTransmission();
        delay(10);
	Wire.requestFrom(dsAddress, 1);
	if(1 <= Wire.available())     // if one byte was received 
	{ 
		dsSpecial = Wire.receive();

		if (dsSpecial & DS00PS) { 
                  Serial.println("PsSetON");
                  iReturn = 1;
                }
                else {
                  Serial.println("PsSetOFF");
                  iReturn = 0;
                }      
	}
#else
          Serial.println("Nothing Received from Set Power State - WIRE BYPASSED");
          iReturn = 0;
#endif
	return iReturn;
}







//------------------------------------------------------------------------------
// setSleepMode
//
// Sets the default value for sleep mode on or off depending on the value
// passed in.
// 
//
// Arguments:
//     int aiValue - 1 if sleep mode should be enabled, 0 if it should be
//                   disabled.
//
// Return Value:
//     1 if the bit value was set to 1, meaning that the power is "on"
//     0 if the bit value was not set and is still 0
//    -1 if no value was returned when trying to confirm the setting was made.
//------------------------------------------------------------------------------
int setSleepMode(int aiValue) {
	int iReturn    = 0;
        int iJunk      = 0;
        int iShadow    = 0;
        

#ifndef NOWIRE

        // set in bit 5 in Address 31h
        
        // Recall EEPROM Block 1 Data to Shadow RAM
        Wire.beginTransmission(dsAddress);
	Wire.send(0xFE);          // Write value to Function Command Address
        Wire.send(0xB4);          // Request refresh of Block 1 Shadow RAM from EEPROM
	Wire.endTransmission();
        delay(500);
        
        /*
        Wire.requestFrom(dsAddress, 1);
	if(1 <= Wire.available()) { 
            iJunk = Wire.receive();
            Serial.println(iJunk, HEX);
        }
        else {
          Serial.println("NOD 1");
        }
        
        */
        
        // Read second byte of Block 1 Shadow RAM
        Wire.beginTransmission(dsAddress);
	Wire.send(0x31);
        Wire.endTransmission();
        delay(100);
	Wire.requestFrom(dsAddress, 1);

	if(1 <= Wire.available()) { 
		iShadow = Wire.receive();
                Serial.print("Block 1 Byte 1: ");
                Serial.println(iShadow, HEX);
        }
        else {
          Serial.println("NOD 2");
        }

        // set data
        iShadow = iShadow | 0x20;  // This ensures bit 5 is set and nothing else is changed.
        Serial.print("About to send: ");
        Serial.println(iShadow, HEX);
        
        Wire.beginTransmission(dsAddress);
        Wire.send(0x31);
        Wire.send(iShadow);
        Wire.endTransmission();
        delay(10);
        
        // ready back reply? 
        /*        
        Wire.requestFrom(dsAddress, 1);
	if(1 <= Wire.available()) { 
            iJunk = Wire.receive();
            Serial.println(iJunk, HEX);
        }
        else {
          Serial.println("NOD 3");
        }
        */
        
        // copy data back into EEPROM
        Wire.beginTransmission(dsAddress);
	Wire.send(0xFE);          // Write value to Function Command Address
        Wire.send(0x44);          // Request Write of Block 1 Shadow RAM back into EEPROM
	Wire.endTransmission();
        delay(10);
        
        /*
        Wire.requestFrom(dsAddress, 1);
	if(1 <= Wire.available()) { 
            iJunk = Wire.receive();
            Serial.println(iJunk, HEX);
        }
        else {
          Serial.println("NOD 4");
        }
        */
#else
          //Serial.println("Nothing Received from Set Power State - WIRE BYPASSED");
          iReturn = 0;
#endif
	return iReturn;
}













int resetdsProtection(int aiOn) {
	int dsProtect  = 0;
	int dsStatus   = 0;
#ifndef NOWIRE
	// Read Protection Register
	Wire.beginTransmission(dsAddress);
	Wire.send(0x00);

        if(aiOn == 1) {
	  Wire.send(0x03);    //Clear OV and UV, enable  charge and discharge
        }
        else {
	  Wire.send(0x00);  //Clear OV and UV, disable charge and discharge
        }
	Wire.endTransmission();

	delay(10);
	Wire.requestFrom(dsAddress, 2);
	if(2 <= Wire.available())     // if two bytes were received 
	{ 
		dsProtect = Wire.receive();
		dsStatus = Wire.receive();

	}
        else {
             //Serial.println("Nothing received from resetdsProtection Request");
             
             giProtect = 0;
             giStatus  = 0;
             
        }
#else
             Serial.println("Nothing received from resetdsProtection Request - Wire Bypassed");
             
             giProtect = 0;
             giStatus  = 0;

#endif
	return dsProtect;
}





void DisplayData(int iProtect, int iStatus, int iVolts, double dCurrent, int iAccCurrent, float fTempC) {
  
        //Serial.println("Entering DisplayData()");
        int   i           = 0;
        char  szHi[]      = "HI";
        char  szLo[]      = "LO";
        char  szOk[]      = "Ok";
        char  szOn[]      = "On";
        char  szOff[]     = "Off";
        char* szVoltStat  = NULL;
        char* szChrgStat  = NULL;
        char* szDChrgStat = NULL;
        char* szChrgOn    = NULL;
        char* szDChrgOn   = NULL;

        // Convert temperature to Fahrenheit        
        float fTempF  = (fTempC * 9.0 / 5.0) + 32.0;
        
        // Calculate % of Battery Capacity Remaining using
        // the Total Bat Cap specified in the #define at the top
        // of this code, and the Total Accumulated Current tracked
        // by the Gas Gauge Chip.
        float fPct    = (iAccCurrent / BAT_CAP) * 100.0;
        
        float fVolts  = iVolts / 1000.0;
        
        pstrTemp.begin();
        pstrCurrent.begin();
        pstrPercent.begin();
        pstrVolts.begin();
        
        pstrCurrent.print(dCurrent, 1);
        pstrTemp.print(fTempF, 1);        
        pstrPercent.print(fPct, 1);
        pstrVolts.print(fVolts, 2);
        
        // set Voltage Status
        if (iProtect & DS00OV) { 
          szVoltStat = szHi; 
        }
        else if (iProtect & DS00UV) { 
          szVoltStat = szLo; 
        }
        else {
          szVoltStat = szOk; 
        }

        // set Charge Current Status
        if (iProtect & DS00COC) {
          // charge current is over the threshold 
          szChrgStat = szHi;
        }
        else {
          szChrgStat = szOk;
        }     

        if (iProtect & DS00CC) { 
          szChrgOn = szOff;
        }
        else {
          szChrgOn = szOn;
        }


        // set Discharge Current Status
        if (iProtect & DS00DOC) {
          // discharge current is over the threshold 
          szDChrgStat = szHi; 
        }
        else {
          szDChrgStat = szOk; 
        } 
        
        
        if (iProtect & DS00DC) { 
          szDChrgOn = szOff;
        }
        else {
          szDChrgOn = szOn;
        }
        
        /*        
        if (iProtect & DS00CE) { 
          Serial.println("         Charging: Enabled"); 
        }
        else {
          Serial.println("         Charging: Disabled");
        }
		
        if (iProtect & DS00DE) { 
          Serial.println("      Discharging: Enabled");
        }
        else {
          Serial.println("      Discharging: Disabled");
        }
        */        

        
        // these are the global buffers
        //char   gszTempBuf[FLOATBUF    + 1];
        //char   gszCurrBuf[FLOATBUF    + 1];
        //char   gszLineBuf[NUMCOLS     + 1];
                
        // LCD Lines
        //         1  1  1   2
        //12345678901234567890
        //   -0.6mA     4191mV
        //Acc: 2110mAh  78.4oF
        //VOLT CHARGE  DCHARGE
        // OK  OK ON    HI OFF
        //
        
#if  DISPLAY_TYPE == SMALL_LCD || DISPLAY_TYPE == BIG_LCD
        
        // Line 1
        // 12345678901234567890
        //   150.0mA     4200mV
        pstrLine.begin();
        pstrLine.format("%7smA     %4dmV", gszCurrBuf, iVolts);
        lcd.setCursor(0, 0);
        lcd.print(pstrLine);

        // Line 2
        // 12345678901234567890
        // 6600mAh 99.1% 102.2o
        pstrLine.begin();
        pstrLine.format("%4dmAh%5s%% %5s", iAccCurrent, gszPctBuf, gszTempBuf);
                
        lcd.setCursor(0, 1);
        lcd.print(pstrLine);
        lcd.print(0, BYTE);

        // Line 3        
        lcd.setCursor(0, 2);
        //         12345678901234567890
        lcd.print("VOLT CHARGE  DCHARGE");
        
        
        pstrLine.begin();
        if (iProtect & DS00OV) { 
          pstrLine.print(" HI "); 
        }
        else if (iProtect & DS00UV) { 
          pstrLine.print(" LO "); 
        }
        else {
          pstrLine.print(" OK ");
        }
        
        pstrLine.print(" ");
                
        if (iProtect & DS00COC) { 
          pstrLine.print("HI "); 
        }
        else {
          pstrLine.print("OK "); 
        }     
        
        if (iProtect & DS00CC) { 
          pstrLine.print("OFF"); 
        }
        else {
          pstrLine.print("ON ");
        }
        
        pstrLine.print("   ");
        
        if (iProtect & DS00DOC) { 
          pstrLine.print("HI "); 
        }
        else {
          pstrLine.print("OK "); 
        }        
                
        if (iProtect & DS00DC) { 
          pstrLine.print("OFF"); 
        }
        else {
          pstrLine.print("ON ");
        }
        
        /*        
        if (iProtect & DS00CE) { 
          Serial.println("         Charging: Enabled"); 
        }
        else {
          Serial.println("         Charging: Disabled");
        }
		
        if (iProtect & DS00DE) { 
          Serial.println("      Discharging: Enabled");
        }
        else {
          Serial.println("      Discharging: Disabled");
        }
        */        

        lcd.setCursor(0, 3);
        lcd.print(pstrLine);
                
        // log time
        /*
        snprintf(gszLogBuff, LOGBUFFSIZE, "%02d/%02d/%04d %02d:%02d:%02d,%s,%4d,%5d,%s,%s,%s,%s,%s,%s,%s",
          dtNow.month(), dtNow.day(), dtNow.year(), dtNow.hour(), dtNow.minute(), dtNow.second(),
          szCurrBuf,
          iVolts,
          iAccCurrent,
          szTempBuf,
          szVFlag, szCFlag, szDFlag,
          szCEFlag, szDEFlag, szSEFlag);
          
        Serial.println(gszLogBuff);  
        */
/*        
#xx ifdef USE_LOGGER        
        DateTime now;
        
        // fetch the time
        now = RTC.now();
        
        //gszLogBuff[LOGBUFFSIZE]
        //file.println("time,current_mA,voltage_mV,lipo_charge_mAh,temp,VoltsOK,ChargeCurrentOK,DischargeCurrentOK,ChargeEnabled,DischargeEnabled,SleepEnabled");    
        
        // log time
        snprintf(gszLogBuff, LOGBUFFSIZE, "%02d/%02d/%04d %02d:%02d:%02d,%s,%4d,%5d,%s, %s,%s,%s,%s,%s,%s",
          now.month(), now.day(), now.year(), now.hour(), now.minute(), now.second(),
          szCurrBuf,
          iVolts,
          iAccCurrent,
          szTempBuf,
          szVFlag, szCFlag, szDFlag,
          szCEFlag, szDEFlag, szSEFlag);   
          
          //strcpy(gszLogBuff, "bogus");
#xx endif        
*/
#elif DISPLAY_TYPE == NOKIA_LCD

        //Serial.println("In Display Data for Nokia Screen");
        
        pstrLine.begin();
        nokia.clear();    // clear the screen

        //Serial.println("got past Nokia.clear");
        
        
        //01234567890123
        //999.9mA 110.5o
        //2180mAh  99.9%
        //Voltage     OK
        //Charging    OK
        //Discharge   OK
        
        //123456789012341234567890123412345678901234123456789012341234567890123412345678901234
        //--------------==============--------------==============--------------==============
        //-700.0mA 3.78V1000mAh ---.-%Voltage     OKCharge  Off OKDCharge Off OKTemp:  102.6oF


        pstrLine.format("%6smA%5sV%4dmAh %5s%%Voltage     %2sCharge  %3s %2sDcharge %3s %2sTemp:  %5s F", 
                        gszCurrBuf, gszVoltBuf, iAccCurrent, gszPctBuf, szVoltStat, szChrgOn, szChrgStat, szDChrgOn, szDChrgStat, gszTempBuf);
        nokia.drawstring(0, 0, gszLineBuf);
        Serial.println(gszLineBuf);
        
        if (!(iProtect & DS00CE)) {
          // Charging is disabled 
          nokia.drawline(0, 3*8 + 4, 7*6, 3*8 + 4, BLACK); 
        }
        
        //nokia.display();
  
        if (!(iProtect & DS00DE)) {
          //Discharging is disabled 
          nokia.drawline(0, 4*8 + 4, 7*6, 4*8 + 4, BLACK); 
        }
        
        nokia.drawbitmap(72, 40, degree_bmp, 5, 8, BLACK);
    
        nokia.display();
#else
        // Nokia LCD Lines
        //         1  1
        //1234567890123
        //-0.6mA  77.7o
        //2180mAh 99.9%
        //Voltage    OK
        //Charging   OK
        //Discharge  OK
        
        Serial.println("In Display Data with no Display Defined");
        delay(2000);
      
        
        // Line 0 - print current and temp
        //          1 1
        //0123456789012
        //-0.6mA  77.7o
        //222.1mA 100.2
        //Serial.println(":1234567890123:");
        
        //1234567890123
        //999.9mA101.7o
        //-999.9mA101.7
        pstrTemp.print(fTempF, 1);
        pstrCurrent.print(dCurrent, 1);
        Serial.print(pstrCurrent);
        Serial.print("mA ");
        Serial.print(pstrTemp);
        Serial.println(" degrees F");

                
        // Line 1 - print Accumulated current and eventually charge percent
        //          1 1
        //0123456789012
        //2180mAh 99.9%
        //**pstrLine.begin();
        //**pstrFloat.begin();
        //pstrLine.print(iAccCurrent);
        //pstrLine.print("mAh");
        //Serial.println(pstrLine);
        //**Serial.print(":");
        //**Serial.print(gszLineBuf);
        // TODO, calculate battery percent
        //nokia.drawstring(8, 1, "??.?%");
        //**Serial.println(":");
        
        
        // Line 2 - Print Battery Voltage and HI/LO/OK Status
        //          1 1
        //0123456789012
        //1234mV     OK
        //**pstrLine.begin();
        //**pstrFloat.begin();
        //**pstrLine.print(iVolts);
        //**pstrLine.print("mV");
        //**Serial.print(":");
        //**Serial.print(gszLineBuf);
        Serial.print(iVolts);
        Serial.print("mV ");
        
        if (iProtect & DS00OV) { 
          Serial.print("HI"); 
        }
        else if (iProtect & DS00UV) { 
           Serial.print("LO");  
        }
        else {
           Serial.print("Ok"); 
        }
        Serial.println();

    
        // Line 3 - Print Charging Current Status
        //          1 1
        //0123456789012
        //Charging   OK
    
        //**pstrLine.begin();
        //**pstrFloat.begin();
        //**Serial.print(":");
        Serial.print("Charging ");
        
        if (iProtect & DS00COC) {
          // charge current is over the threshold 
          Serial.print("HI"); 
        }
        else {
          Serial.print("Ok"); 
        }     
        
        if (iProtect & DS00CC) {
          // Charging is disabled 
          Serial.print(" DISABLED"); 
        }
        Serial.println();
 
 
        // Line 4 - Print Discarge Current Status
        //          1 1
        //0123456789012
        //Discharge  OK
        //**pstrLine.begin();
        //**pstrFloat.begin();
        //**Serial.print(":");
        Serial.print("Discharge ");
        
        if (iProtect & DS00DOC) {
          // discharge current is over the threshold 
          Serial.print("HI"); 
        }
        else {
          Serial.print("Ok"); 
        }     
        
        if (iProtect & DS00DC) {
          // Charging is disabled 
          Serial.print(" DISABLED"); 
        }
        Serial.println();
        
#endif

       //Serial.println("Leaving DisplayData()...");
}











void setAccumCurrent(int iNewVal) {
  
        // Convert our new value in mAh to units of .25mAh
	int acurrent = iNewVal / 0.25;

        byte loByte = 0;
        byte hiByte = 0;
        
        loByte = acurrent & 0x00FF;
        hiByte = acurrent >> 8;
        
#ifndef NOWIRE        
	// Send Data to Accumulated Current Variable
	Wire.beginTransmission(dsAddress);
	Wire.send(0x10);
        delay(5);
        
        Wire.send(hiByte);
        Wire.send(loByte);
        
	Wire.endTransmission();
#endif

}






//------------------------------------------------------------------------------
// fillBuffer
//
// Fills the specified character array with the specified character
//
// Arguments:
//     None
//
// Return Value:
//     None
//------------------------------------------------------------------------------
void fillBuffer(char* aszBuff, int aiSize, char acChar) {

  int i = 0;

  for(i = 0; i < aiSize; i++) {
    aszBuff[i] = acChar;
  }  
}





//------------------------------------------------------------------------------
// format_svn_info
//
// Formats the contents of the file revision information from SVN 
// into strings more friendly to display.
//
// Requires that these symbols have been #define'ed:
//   NUMROWS  - number of rows in display device
//   NUMCOLS  - number of columns in display device
//   APP_NAME - application name to display, the length must be <= NUMCOLS
//   APP_VER  - application version set to "Version x.y"
//
// Also, these global variables must be declared, with the constants being set to the 
// values of SVN property strings as shown.
//
// const char IDSTR[]                 = "$Id: LipoGasGauge.pde 61 2011-06-05 01:32:41Z davidtamkun $";
// const char DATESTR[]               = "$Date: 2011-06-04 18:32:41 -0700 (Sat, 04 Jun 2011) $";
// const char REVSTR[]                = "$Rev: 61 $";
//    char gszDateStr[NUMCOLS + 1];
//    char gszRevStr [NUMCOLS + 1];
//    char gszLineBuf[NUMCOLS + 1];
//
// This function takes the SVN Date information from DATESTR and formats it 
// into gszDateStr.
//   If NUMCOLS >= 19, the format is YYYY-MM-DD HH:MM:SS
//   If NUMCOLS >= 14, the format is YY-MM-DD HH:MM
//   otherwise gszDateStr is not changed
//
// gszRevStr will contain APP_VER with "." and the SVN Revision Number appended
// on.
//
// Arguments:
//     None
//
// Return Value:
//     None
//------------------------------------------------------------------------------
void format_svn_info() {
      
  int      i                 =  0;
  int      iSvnDateLen       = 19;    // length of YYYY-MM-DD HH:MM:SS
  int      iSvnShortDateLen  = 14;    // length of YY-MM-DD HH:MM  
  int      iSvnMinDateLen    = 10;    // length of YYYY-MM-DD
  int      iAppVerLen        = strlen(APP_VER);
  PString  VerString(gszRevStr, REVISIONBUFSIZE);
  
  // 1234567890123456
  // mm/dd/yy hh:mm
  // Load SVN Date into the Date String Buffer
  // NUMCOLS must be >= iSvnDateLen
  
  if(NUMCOLS >= iSvnDateLen) {
    while(i < iSvnDateLen) {
      gszDateStr[i]       = DATESTR[i + 7]; 
      gszDateStr[iSvnDateLen] = '\0';  // null character
      i++;
    }
  }
  else if(NUMCOLS >= iSvnShortDateLen) {
    while(i < iSvnShortDateLen) {
      gszDateStr[i] = DATESTR[i + 9];
      gszDateStr[iSvnShortDateLen] = '\0';
      i++;
    }
  }
  else if(NUMCOLS >= iSvnMinDateLen) {
    while(i < iSvnMinDateLen) {
      gszDateStr[i] = DATESTR[i + 7];
      gszDateStr[iSvnMinDateLen] = '\0';
      i++;
    }
  }
  else {
    gszDateStr[0] = '\0';
    Serial.println("No room for Date String in format_svn_info");
  }
  
  // Load the App Version into the Version Buffer
  VerString.print(APP_VER);
  VerString.print(".");
  
  i = 0;
  
  while(i < NUMCOLS && REVSTR[i + 6] >= '0' && REVSTR[i + 6] <= '9') {
    VerString.print(REVSTR[i + 6]);
    i++;
  }
    
} // end format_svn_info








//------------------------------------------------------------------------------
// center_line
//
// This function centers and copies the text in aszText to the buffer 
// aszBuff
//
// Arguments:
//     aszText    IN Pointer to a string containing the text to center
//     aszBuff    IN Pointer to a buffer to receive the centered string
//     aiBuffSize IN the size of the buffer pointed to by aszBuff.
//
// Return Value:
//     None - but the centered text is copied to aszBuff
//------------------------------------------------------------------------------
void center_line(char* aszText, char* aszBuff, int aiBuffSize) {

  int i        = 0;
  int iOffset  = 0;
  int iLen     = 0;

  for (i = 0; i < aiBuffSize - 1; i++) {
    aszBuff[i] = ' ';
  }
  aszBuff[aiBuffSize - 1] = '\0';
  
  iLen = strlen(aszText);
  
  iOffset = trunc((aiBuffSize - 1 - iLen) / 2);
    
  if(iOffset < 0) {iOffset = 0;}
  
  i = 0;
  while ((i < iLen) && ((i + iOffset) < (aiBuffSize - 1))) {
    
    aszBuff[i + iOffset] = aszText[i];
    i++;
  }
   
} // end center_line






#if DISPLAY_TYPE == NOKIA_LCD
//------------------------------------------------------------------------------
// drawstringCentered
//
// Centers and prints a text string on a line of a Nokia LCD Display
//
// Arguments:
//     aiRow      IN Row Number to print the text on, (0 - 5)
//     aszBuff    IN Pointer to the text to print
//
// Return Value:
//     None
//------------------------------------------------------------------------------
void drawstringCentered(int aiRow, char* aszBuff) {
  int i        = 0;
  int iOffset  = 0;
  int iLen     = 0;
  
  iLen = strlen(aszBuff);
  
  iOffset = trunc((NUMCOLS - iLen) / 2);
  
  if(iOffset < 0) {iOffset = 0;}
  
  nokia.drawstring(iOffset * 6, aiRow, aszBuff);
}
#endif




//------------------------------------------------------------------------------
// display_app_version_info
//
// This function displays application version information on the appropriate
// display device and pauses so the user has time to read it at startup.  This
// code must be customized as appropriate for the display device (i.e. LCD
// vs Nokia Display vs OLED display, etc).
//
// Arguments:
//     None
//
// Return Value:
//     None
//------------------------------------------------------------------------------
void display_app_version_info() {
	//
	//
	// Change as needed for appropriate display type
	//
	//
        //Serial.println("In display_app_version_info...");
        
#if  DISPLAY_TYPE == SMALL_LCD || DISPLAY_TYPE == BIG_LCD
        // Display Application and Version Info
        center_line(APP_NAME, gszLineBuf, LINEBUFSIZE);
        lcd.setCursor(0, 0);
        lcd.print(gszLineBuf);
        
        center_line(gszRevStr, gszLineBuf, LINEBUFSIZE);
        lcd.setCursor(0, 1);
        lcd.print(gszLineBuf);

        center_line(gszDateStr, gszLineBuf, LINEBUFSIZE);
        
        if(NUMROWS < 4) {
          delay(5000);
          lcd.setCursor(0, NUMROWS - 1);
          lcd.print(gszLineBuf);
          delay(5000);
        }
        else {
          lcd.setCursor(0, 2);
          lcd.print(gszLineBuf);
          
          lcd.setCursor(0, 3);
          pstrLine.begin();
          
          // 12345678901234567890
          // Batt Cap.    6600mAh
          pstrLine.print("Batt Cap.   ");
          pstrLine.print(BAT_CAP, 0);
          pstrLine.print(" mAh");
          lcd.print(gszLineBuf);

          delay(10000);
        }
        
#elif DISPLAY_TYPE == NOKIA_LCD
        //Serial.println("About to display app version info on Nokia Screen");
        nokia.clear();

        pstrLine.begin();
        
        drawstringCentered(0, APP_NAME);
        drawstringCentered(1, gszRevStr);
        drawstringCentered(2, gszDateStr);
        
        //                      12345678901234
        nokia.drawstring(0, 4, "Batt  Capacity");
        
        pstrLine.print(BAT_CAP, 0);
        pstrLine.print(" mAh");
        
        drawstringCentered(5, gszLineBuf);
        
        nokia.display();
        
        delay(5000);
#else
        //Serial.println("No Display, about to send App Version info to Serial Port");
        
        
        center_line(APP_NAME, gszLineBuf, LINEBUFSIZE);
        Serial.print(":");
        Serial.print(gszLineBuf);
        Serial.println(":");
        
        center_line(gszRevStr, gszLineBuf, LINEBUFSIZE);
        Serial.print(":");
        Serial.print(gszLineBuf);
        Serial.println(":");

        
        center_line(gszDateStr, gszLineBuf, LINEBUFSIZE);
        Serial.print(":");
        Serial.print(gszLineBuf);
        Serial.println(":");

#endif
        //Serial.println("Leaving display_app_version_info");
} // end display_app_version_info


